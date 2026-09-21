import { LightningElement, api, wire } from 'lwc';
import getDuplicatePersonAccounts from '@salesforce/apex/LeadDuplicateController.getDuplicatePersonAccounts';

import { updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { RefreshEvent } from 'lightning/refresh';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { registerRefreshHandler, unregisterRefreshHandler } from 'lightning/refresh';
import ID_FIELD from '@salesforce/schema/Lead.Id';
import EXISTING_PATIENT_FIELD from '@salesforce/schema/Lead.Existing_Patient_Account__c';

const accColumn = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Phone', fieldName: 'Phone' },
    { label: 'Email', fieldName: 'PersonEmail' }
    ]
const COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Phone', fieldName: 'Phone' },
    { label: 'Email', fieldName: 'PersonEmail' },
    {
        type: 'button',
        typeAttributes: {
            label: 'Select',
            name: 'select',
            variant: 'brand',
            disabled: { fieldName: 'disableButton' }
        }
    }
];

export default class LeadDuplicateModal extends LightningElement {

    @api recordId;

    columns = COLUMNS;
    accColumns = accColumn
    accounts = [];
    showModal = false;
    showTable = false;
    wiredResult;

    @wire(getDuplicatePersonAccounts, { leadId: '$recordId' })
    wiredAccounts(result) {

        this.wiredResult = result;

        if(result.data){

            const selectedId = result.data.existingPatientAccountId;

            this.accounts = result.data.accounts.map(acc => {
                return {
                    ...acc,
                    disableButton: acc.Id === selectedId
                };
            });
          
            this.showModal =
            this.accounts.length > 0 &&
            !selectedId;
            this.showTable =this.accounts.length > 0 ;
        }
        else if(result.error){
            console.error(result.error);
        }
    }

    async handleRowAction(event) {

        if (event.detail.action.name !== 'select') {
            return;
        }

        const account = event.detail.row;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[EXISTING_PATIENT_FIELD.fieldApiName] = account.Id;

        try {

            // Update the Lead
            await updateRecord({ fields });

            // Refresh the Apex wire
            await refreshApex(this.wiredResult);

            // Notify the record page to refresh
            this.dispatchEvent(new RefreshEvent());

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Existing Patient linked successfully.',
                    variant: 'success'
                })
            );

        } catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'An error occurred.',
                    variant: 'error'
                })
            );
        }
    }

    closeModal(){
        this.showModal = false;
    }

    connectedCallback() {
        this.refreshHandlerId = registerRefreshHandler(
            this,
            this.handleRefresh.bind(this)
        );
    }

    disconnectedCallback() {
        unregisterRefreshHandler(this.refreshHandlerId);
    }

    async handleRefresh() {
        await refreshApex(this.wiredResult);
    }

    
}