import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import PDF_LIB from '@salesforce/resourceUrl/pdfLib';
import ADR_PDF from '@salesforce/resourceUrl/AdverseDrugReaction';

const FIELD_COLUMNS = [
    { label: 'Field Name', fieldName: 'name', type: 'text', wrapText: true },
    { label: 'Type', fieldName: 'type', type: 'text' },
    { label: 'Current Value', fieldName: 'value', type: 'text', wrapText: true },
    { label: 'Font', fieldName: 'font', type: 'text' },
    { label: 'Font Size', fieldName: 'fontSize', type: 'text' },
    { label: 'Max Length', fieldName: 'maxLength', type: 'text' },
    { label: 'Required', fieldName: 'required', type: 'boolean' },
    { label: 'Read Only', fieldName: 'readOnly', type: 'boolean' },
    { label: 'Options', fieldName: 'options', type: 'text', wrapText: true }
];

export default class PdfFieldInspector extends LightningElement {
    @track fields = [];
    columns = FIELD_COLUMNS;

    pdfLibLoaded = false;
    pdfLib = null;
    pdfDoc = null;
    pdfForm = null;
    isLoading = false;
    errorMessage = '';

    fieldNameOptions = [];
    selectedFieldName = '';
    selectedFieldValue = '';

    get hasFields() {
        return this.fields.length > 0;
    }

    get disableActions() {
        return !this.pdfDoc || this.isLoading;
    }

    async connectedCallback() {
        try {
            await loadScript(this, PDF_LIB);
            // eslint-disable-next-line no-undef
            this.pdfLib = PDFLib;
            this.pdfLibLoaded = true;
        } catch (error) {
            this.errorMessage = 'Failed to load pdf-lib: ' + this.reduceError(error);
        }
    }

    async handleLoadPdf() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            if (!this.pdfLibLoaded) {
                await loadScript(this, PDF_LIB);
                // eslint-disable-next-line no-undef
                this.pdfLib = PDFLib;
                this.pdfLibLoaded = true;
            }
            const response = await fetch(ADR_PDF);
            if (!response.ok) {
                throw new Error('Could not fetch AdverseDrugReaction static resource (' + response.status + ')');
            }
            const bytes = await response.arrayBuffer();

            const { PDFDocument } = this.pdfLib;
            this.pdfDoc = await PDFDocument.load(bytes, { ignoreEncryption: true });
            this.pdfForm = this.pdfDoc.getForm();

            this.fields = this.pdfForm.getFields().map((field) => this.describeField(field));
            this.fieldNameOptions = this.fields.map((f) => ({ label: f.name, value: f.name }));
        } catch (error) {
            this.errorMessage = 'Failed to load/parse PDF: ' + this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    getFieldTypeLabel(field) {
        const { PDFTextField, PDFCheckBox, PDFDropdown, PDFOptionList, PDFRadioGroup, PDFButton, PDFSignature } = this.pdfLib;
        if (field instanceof PDFTextField) return 'TextField';
        if (field instanceof PDFCheckBox) return 'CheckBox';
        if (field instanceof PDFDropdown) return 'Dropdown';
        if (field instanceof PDFOptionList) return 'OptionList';
        if (field instanceof PDFRadioGroup) return 'RadioGroup';
        if (field instanceof PDFButton) return 'Button';
        if (field instanceof PDFSignature) return 'Signature';
        return 'Unknown';
    }

    describeField(field) {
        const type = this.getFieldTypeLabel(field);
        let value = '';
        let options = '';
        let maxLength = '';

        try {
            if (typeof field.getText === 'function') {
                value = field.getText() || '';
            }
            if (typeof field.isChecked === 'function') {
                value = field.isChecked() ? 'checked' : 'unchecked';
            }
            if (typeof field.getSelected === 'function') {
                const sel = field.getSelected();
                value = Array.isArray(sel) ? sel.join(', ') : (sel || '');
            }
            if (typeof field.getOptions === 'function') {
                options = (field.getOptions() || []).join(', ');
            }
            if (typeof field.setMaxLength === 'function' && typeof field.acroField?.getMaxLen === 'function') {
                const ml = field.acroField.getMaxLen();
                maxLength = ml === undefined ? '' : String(ml);
            }
        } catch (e) {
            // best-effort extraction, ignore fields that don't support these getters
        }

        const { font, fontSize } = this.getFontInfo(field);

        let required = false;
        let readOnly = false;
        try {
            required = typeof field.isRequired === 'function' ? field.isRequired() : false;
            readOnly = typeof field.isReadOnly === 'function' ? field.isReadOnly() : false;
        } catch (e) {
            // flags unavailable for this field type
        }

        return {
            name: field.getName(),
            type,
            value,
            font,
            fontSize,
            maxLength,
            required,
            readOnly,
            options
        };
    }

    getFontInfo(field) {
        let font = '';
        let fontSize = '';
        try {
            const acro = field.acroField;
            const da = acro && typeof acro.getDefaultAppearance === 'function' ? acro.getDefaultAppearance() : '';
            if (da) {
                const match = da.match(/\/(\S+)\s+([\d.]+)\s+Tf/);
                if (match) {
                    font = match[1];
                    fontSize = match[2];
                }
            }
        } catch (e) {
            // DA string not present/parseable for this field
        }
        return { font, fontSize };
    }

    handleFieldSelect(event) {
        this.selectedFieldName = event.detail.value;
        const match = this.fields.find((f) => f.name === this.selectedFieldName);
        this.selectedFieldValue = match ? match.value : '';
    }

    handleValueChange(event) {
        this.selectedFieldValue = event.target.value;
    }

    async handleApplyValue() {
        this.errorMessage = '';
        if (!this.pdfForm || !this.selectedFieldName) {
            return;
        }
        try {
            const field = this.pdfForm.getField(this.selectedFieldName);
            const { PDFTextField, PDFCheckBox, PDFDropdown, PDFOptionList, PDFRadioGroup, StandardFonts } = this.pdfLib;

            if (field instanceof PDFTextField) {
                const helvetica = await this.pdfDoc.embedFont(StandardFonts.Helvetica);
                field.setText(this.selectedFieldValue);
                field.updateAppearances(helvetica);
            } else if (field instanceof PDFCheckBox) {
                if (['true', 'checked', 'yes', '1'].includes((this.selectedFieldValue || '').toLowerCase())) {
                    field.check();
                } else {
                    field.uncheck();
                }
            } else if (field instanceof PDFDropdown || field instanceof PDFOptionList) {
                field.select(this.selectedFieldValue);
            } else if (field instanceof PDFRadioGroup) {
                field.select(this.selectedFieldValue);
            } else {
                throw new Error('Editing field type ' + this.getFieldTypeLabel(field) + ' is not supported yet');
            }

            this.fields = this.pdfForm.getFields().map((f) => this.describeField(f));
        } catch (error) {
            this.errorMessage = 'Failed to set value: ' + this.reduceError(error);
        }
    }

    async handleFillSampleValues() {
        this.errorMessage = '';
        if (!this.pdfForm) {
            return;
        }
        try {
            const { PDFTextField, StandardFonts } = this.pdfLib;
            const helvetica = await this.pdfDoc.embedFont(StandardFonts.Helvetica);
            const skipped = [];

            this.pdfForm.getFields().forEach((field) => {
                if (field instanceof PDFTextField) {
                    try {
                        const maxLen = field.acroField?.getMaxLen?.();
                        const sample = maxLen ? field.getName().slice(0, maxLen) : field.getName();
                        field.setText(sample);
                        field.updateAppearances(helvetica);
                    } catch (fieldError) {
                        skipped.push(field.getName());
                    }
                }
            });

            if (skipped.length) {
                this.errorMessage = 'Skipped fields (could not set sample value): ' + skipped.join(', ');
            }

            // Force regeneration of every field's appearance stream so the
            // value is actually visible, not just stored in /V.
            this.pdfForm.updateFieldAppearances(helvetica);

            this.fields = this.pdfForm.getFields().map((f) => this.describeField(f));
        } catch (error) {
            this.errorMessage = 'Failed to fill sample values: ' + this.reduceError(error);
        }
    }

    async handleSaveAndDownload() {
        this.errorMessage = '';
        if (!this.pdfDoc) {
            return;
        }
        this.isLoading = true;
        try {
            const bytes = await this.pdfDoc.save();
            const blob = new Blob([bytes], { type: 'application/pdf' });
            const url = URL.createObjectURL(blob);
            const anchor = document.createElement('a');
            anchor.href = url;
            anchor.download = 'AdverseDrugReaction_edited.pdf';
            document.body.appendChild(anchor);
            anchor.click();
            document.body.removeChild(anchor);
            URL.revokeObjectURL(url);
        } catch (error) {
            this.errorMessage = 'Failed to save PDF: ' + this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || String(error);
    }
}