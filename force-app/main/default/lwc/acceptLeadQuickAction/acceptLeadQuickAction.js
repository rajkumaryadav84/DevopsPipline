import { LightningElement, api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import LEAD_ID_FIELD from '@salesforce/schema/Lead.Id';
import LEAD_OWNER_FIELD from '@salesforce/schema/Lead.OwnerId';

export default class AcceptLeadQuickAction extends LightningElement {
    @api recordId;

    @api invoke() {
        const fields = {};
        fields[LEAD_ID_FIELD.fieldApiName] = this.recordId;
        fields[LEAD_OWNER_FIELD.fieldApiName] = USER_ID;

        updateRecord({ fields })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Lead accepted. You are now the owner.',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error && error.body ? error.body.message : 'Unable to accept this Lead.',
                        variant: 'error'
                    })
                );
            });
    }
}