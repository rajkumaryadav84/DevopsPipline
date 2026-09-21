import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import RENDERER_RESOURCE from '@salesforce/resourceUrl/consentPdfRenderer';
import getAuthorizationFormText from '@salesforce/apex/SendConsentFormController.getAuthorizationFormText';
import getAdditionalLeadFieldValues from '@salesforce/apex/SendConsentFormController.getAdditionalLeadFieldValues';
import sendConsentFormEmail from '@salesforce/apex/SendConsentFormController.sendConsentFormEmail';

import LEAD_FIRST_NAME from '@salesforce/schema/Lead.FirstName';
import LEAD_LAST_NAME from '@salesforce/schema/Lead.LastName';
import LEAD_DOB from '@salesforce/schema/Lead.Patient_DOB__c';
import LEAD_EMAIL from '@salesforce/schema/Lead.Email';
import LEAD_PHONE from '@salesforce/schema/Lead.Phone';
import LEAD_COMPANY from '@salesforce/schema/Lead.Company';
import LEAD_INSURANCE_PLAN_NAME from '@salesforce/schema/Lead.Insurance_Plan_Name__c';

const LEAD_FIELDS = [
    LEAD_FIRST_NAME,
    LEAD_LAST_NAME,
    LEAD_DOB,
    LEAD_EMAIL,
    LEAD_PHONE,
    LEAD_COMPANY,
    LEAD_INSURANCE_PLAN_NAME
];

const TOKEN_LABELS = {
    FirstName: 'First Name',
    LastName: 'Last Name',
    DOB: 'Date of Birth',
    Company: 'Company',
    Email: 'Email',
    Phone: 'Phone',
    InsurancePlanName: 'Insurance Plan Name'
};

export default class SendConsentFormQuickAction extends LightningElement {
    @api recordId;

    toAddress = '';
    authorizationFormTextId;
    formName;
    formBody;
    error;
    isPreparing = false;
    missingFields = [];

    additionalFieldValues = {};

    lead;
    rendererUrl = RENDERER_RESOURCE + '/index.html';
    rendererReady = false;
    pendingRenderResolve;
    pendingRenderReject;

    // Dynamically filter AuthorizationFormText based on target record object (Account vs Lead)
    get formTextFilter() {
        const targetObject = (this.recordId && this.recordId.startsWith('001')) 
            ? 'Account' 
            : 'Lead';

        return {
            criteria: [
                {
                    fieldPath: 'Available_For_Patient_Send__c',
                    operator: 'eq',
                    value: true
                },
                {
                    fieldPath: 'Object__c',
                    operator: 'eq',
                    value: targetObject
                }
            ]
        };
    }

    connectedCallback() {
        this.handleWindowMessage = this.handleWindowMessage.bind(this);
        window.addEventListener('message', this.handleWindowMessage);
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleWindowMessage);
    }

    @wire(getRecord, { recordId: '$recordId', fields: LEAD_FIELDS })
    wiredLead({ data }) {
        if (data) {
            this.lead = data;
            if (!this.toAddress) {
                this.toAddress = data.fields.Email.value || '';
            }
            if (this.formBody) {
                this.missingFields = this.findMissingFields(this.formBody);
            }
        }
    }

    get isSendDisabled() {
        return (
            this.isPreparing ||
            !this.authorizationFormTextId ||
            !this.toAddress ||
            !this.formBody ||
            this.missingFields.length > 0
        );
    }

    get missingFieldsLabel() {
        return this.missingFields.join(', ');
    }

    handleToAddressChange(event) {
        this.toAddress = event.detail.value;
    }

    handleRendererLoad() {
        this.rendererReady = true;
    }

    handleWindowMessage(event) {
        const data = event.data || {};
        if (data.type === 'RENDER_PDF_RESULT') {
            if (data.success) {
                this.pendingRenderResolve && this.pendingRenderResolve(data.dataUri);
            } else {
                this.pendingRenderReject && this.pendingRenderReject(new Error(data.error || 'PDF rendering failed'));
            }
            this.pendingRenderResolve = undefined;
            this.pendingRenderReject = undefined;
        }
    }

    async handleAuthFormTextChange(event) {
        this.error = undefined;
        this.missingFields = [];
        const formTextId = event.detail.recordId;
        this.authorizationFormTextId = formTextId;
        this.formBody = undefined;
        this.formName = undefined;
        this.additionalFieldValues = {};

        if (!formTextId) {
            return;
        }

        try {
            const result = await getAuthorizationFormText({ formTextId });
            this.formName = result.name;

            this.formBody = this.sanitizeTokenMarkup(result.detailAuthorizationFormText);

            console.log('SendConsentFormQuickAction: raw form body:\n' + result.detailAuthorizationFormText);
            console.log('SendConsentFormQuickAction: sanitized form body:\n' + this.formBody);

            await this.loadAdditionalFieldValues(this.formBody);

            this.missingFields = this.findMissingFields(this.formBody);
        } catch (error) {
            this.error = this.extractErrorMessage(error);
            this.missingFields = this.formBody ? this.getExtraTokens(this.formBody) : [];
        }
    }

    getExtraTokens(html) {
        const tokens = this.tokensUsedIn(html);

        if (this.recordId && this.recordId.startsWith('001')) {
            console.log('SendConsentFormQuickAction: Account record detected. Sending all tokens to Apex:', tokens);
            return tokens;
        }

        const extraTokens = tokens.filter(
            (token) => !Object.prototype.hasOwnProperty.call(TOKEN_LABELS, token)
        );

        console.log('SendConsentFormQuickAction: Lead or other record detected. Sending only unmapped tokens to Apex:', extraTokens);
        return extraTokens;
    }

    sanitizeTokenMarkup(html) {
        if (!html) {
            return html;
        }

        return html.replace(
            /{{([\s\S]*?)}}(<\/([a-zA-Z][a-zA-Z0-9]*)>)?/g,
            (match, inner, trailingCloseTag, closedTagName) => {
                const openTagsInsideToken = [];

                inner.replace(
                    /<([a-zA-Z][a-zA-Z0-9]*)[^>]*>/g,
                    (tagMatch, tagName) => {
                        openTagsInsideToken.push(tagName.toLowerCase());
                        return tagMatch;
                    }
                );

                const cleaned = inner.replace(/<[^>]*>/g, '').trim();

                const isOrphanedPartner =
                    trailingCloseTag &&
                    openTagsInsideToken.includes(
                        closedTagName.toLowerCase()
                    );

                return `{{${cleaned}}}${
                    isOrphanedPartner ? '' : trailingCloseTag || ''
                }`;
            }
        );
    }

    loadAdditionalFieldValues(html) {
        const extraFieldApiNames = this.getExtraTokens(html);

        if (extraFieldApiNames.length === 0) {
            this.additionalFieldValues = {};
            return Promise.resolve();
        }

        console.log('SendConsentFormQuickAction: field API names being sent to Apex:', extraFieldApiNames);

        return getAdditionalLeadFieldValues({
            leadId: this.recordId,
            fieldApiNames: extraFieldApiNames
        }).then((result) => {
            this.additionalFieldValues = result || {};
            console.log('SendConsentFormQuickAction: resolved additional field values', JSON.parse(JSON.stringify(this.additionalFieldValues)));
        });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSend() {
        this.error = undefined;
        this.isPreparing = true;

        try {
            await this.waitForRendererReady();

            const mergedHtml = this.mergeTokens(this.formBody);

            console.log('SendConsentFormQuickAction: final merged text sent to PDF renderer:\n' + mergedHtml);

            const dataUri = await this.renderPdf(mergedHtml);
            const base64 = dataUri.substring(dataUri.indexOf(',') + 1);
            const fileName = `${this.formName || 'Consent_Form'}_${this.leadLastName}.pdf`;

            await sendConsentFormEmail({
                leadId: this.recordId,
                formTextId: this.authorizationFormTextId,
                toAddress: this.toAddress,
                pdfBase64: base64,
                fileName
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Consent form sent to ' + this.toAddress,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {
            this.error = this.extractErrorMessage(error);
        } finally {
            this.isPreparing = false;
        }
    }

    waitForRendererReady() {
        if (this.rendererReady) {
            return Promise.resolve();
        }

        return new Promise((resolve, reject) => {
            const timeoutId = setTimeout(() => {
                reject(new Error('Consent form renderer failed to load in time.'));
            }, 10000);

            const checkInterval = setInterval(() => {
                if (this.rendererReady) {
                    clearInterval(checkInterval);
                    clearTimeout(timeoutId);
                    resolve();
                }
            }, 100);
        });
    }

    renderPdf(html) {
        const iframe = this.template.querySelector('iframe');

        return new Promise((resolve, reject) => {
            this.pendingRenderResolve = resolve;
            this.pendingRenderReject = reject;

            iframe.contentWindow.postMessage(
                {
                    type: 'RENDER_PDF',
                    html
                },
                '*'
            );
        });
    }

    get leadLastName() {
        return this.lead
            ? this.lead.fields.LastName.value || 'Patient'
            : 'Patient';
    }

    tokenValues() {
        if (this.recordId && this.recordId.startsWith('001')) {
            console.log('SendConsentFormQuickAction: Account token values used for merging:', JSON.parse(JSON.stringify(this.additionalFieldValues)));
            return {
                ...this.additionalFieldValues
            };
        }

        if (!this.lead || !this.lead.fields) {
            return {
                ...this.additionalFieldValues
            };
        }

        const fields = this.lead.fields;

        const dobValue = fields.Patient_DOB__c.value
            ? new Date(fields.Patient_DOB__c.value).toLocaleDateString()
            : '';

        return {
            FirstName: fields.FirstName.value || '',
            LastName: fields.LastName.value || '',
            DOB: dobValue,
            Email: fields.Email.value || '',
            Phone: fields.Phone.value || '',
            ...this.additionalFieldValues
        };
    }

    tokensUsedIn(html) {
        if (!html) {
            return [];
        }

        const found = new Set();
        const regex = /{{\s*([\w.]+)\s*}}/g;

        let match = regex.exec(html);

        while (match) {
            found.add(match[1]);
            match = regex.exec(html);
        }

        return Array.from(found);
    }

    findMissingFields(html) {
        if (
            !html ||
            (this.recordId && this.recordId.startsWith('00Q') && !this.lead)
        ) {
            return [];
        }

        const values = this.tokenValues();

        return this.tokensUsedIn(html)
            .filter((token) => !values[token])
            .map((token) => TOKEN_LABELS[token] || token);
    }

    mergeTokens(html) {
        if (!html) {
            return html;
        }

        const tokenMap = this.tokenValues();

        console.log('SendConsentFormQuickAction: token map used for final merge:', JSON.parse(JSON.stringify(tokenMap)));

        return html.replace(
            /{{\s*([\w.]+)\s*}}/g,
            (match, token) =>
                Object.prototype.hasOwnProperty.call(tokenMap, token)
                    ? tokenMap[token]
                    : match
        );
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'An error occurred while sending the consent form.';
    }
}