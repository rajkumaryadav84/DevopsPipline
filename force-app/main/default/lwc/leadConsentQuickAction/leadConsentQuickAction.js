import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveConsent from '@salesforce/apex/LeadConsentQuickActionController.saveConsent';

const SOURCE_TYPE_OPTIONS = [
    { label: 'Email', value: 'Email' },
    { label: 'Phone', value: 'Phone' },
    { label: 'Web', value: 'Web' },
    { label: 'Social', value: 'Social' },
    { label: 'Mailing Address', value: 'MailingAddress' },
    { label: 'In Person', value: 'InPerson' },
    { label: 'Video', value: 'Video' }
];

const STATUS_OPTIONS = [
    { label: 'Seen', value: 'Seen' },
    { label: 'Signed', value: 'Signed' },
    { label: 'Rejected', value: 'Rejected' }
];

export default class LeadConsentQuickAction extends LightningElement {
    @api recordId;
    @api objectApiName;

    name = '';
    authorizationFormTextId;
    consentCapturedSourceType = '';
    consentCapturedDateTime = new Date().toISOString();
    status = '';
    email = '';
    contentDocumentId;
    uploadedFileName;
    error;
    isSaving = false;

    sourceTypeOptions = SOURCE_TYPE_OPTIONS;
    statusOptions = STATUS_OPTIONS;
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];

    get recordPickerFilter() {
        return {
            criteria: [
                {
                    fieldPath: 'Object__c',
                    operator: 'eq',
                    value: this.objectApiName
                }
            ]
        };
    }

    handleNameChange(event) {
        this.name = event.detail.value;
    }

    handleAuthFormTextChange(event) {
        this.authorizationFormTextId = event.detail.recordId;
    }

    handleSourceTypeChange(event) {
        this.consentCapturedSourceType = event.detail.value;
    }

    handleDateTimeChange(event) {
        this.consentCapturedDateTime = event.detail.value;
    }

    handleStatusChange(event) {
        this.status = event.detail.value;
    }

    handleEmailChange(event) {
        this.email = event.detail.value;
    }

    handleUploadFinished(event) {
        const files = event.detail.files;
        if (files && files.length > 0) {
            this.contentDocumentId = files[0].documentId;
            this.uploadedFileName = files[0].name;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        this.error = undefined;
        if (!this.name) {
            this.error = 'Name is required.';
            return;
        }

        this.isSaving = true;
        const consent = {
            Name: this.name,
            ConsentGiverId: this.recordId,
            AuthorizationFormTextId: this.authorizationFormTextId || null,
            ConsentCapturedSource: 'Lead Quick Action',
            ConsentCapturedSourceType: this.consentCapturedSourceType || null,
            ConsentCapturedDateTime: this.consentCapturedDateTime || null,
            Status: this.status || null,
            Email: this.email || null
        };

        saveConsent({ consent, contentDocumentId: this.contentDocumentId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Consent record created.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                this.error = error && error.body ? error.body.message : 'An error occurred while saving the consent record.';
            })
            .finally(() => {
                this.isSaving = false;
            });
    }
}