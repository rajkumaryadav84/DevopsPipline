import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import findDuplicates from '@salesforce/apex/LeadDuplicateFinderController.findDuplicates';
import acceptAccount from '@salesforce/apex/LeadDuplicateFinderController.acceptAccount';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'accName', type: 'text' },
    { label: 'Phone', fieldName: 'phone', type: 'phone' },
    { label: 'Email', fieldName: 'email', type: 'email' },
    {
        type: 'button',
        typeAttributes: {
            label: 'Accept',
            name: 'accept',
            title: 'Link this Lead to this Account',
            variant: 'brand'
        }
    }
];

export default class LeadDuplicateCheck extends LightningElement {
    @api recordId; // Lead Id, auto-populated on a Lead record page

    columns = COLUMNS;
    duplicates = [];
    isLoading = true;
    hasSearched = false;
    wiredResult;

    @wire(findDuplicates, { leadId: '$recordId' })
    wiredDuplicates(result) {
        this.wiredResult = result;
        this.isLoading = false;
        this.hasSearched = true;

        if (result.data) {
            this.duplicates = result.data;
        } else if (result.error) {
            this.duplicates = [];
            this.showToast('Error loading duplicates', this.reduceError(result.error), 'error');
        }
    }

    get hasDuplicates() {
        return this.duplicates && this.duplicates.length > 0;
    }

    get showNoDuplicates() {
        return this.hasSearched && !this.isLoading && !this.hasDuplicates;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'accept') {
            this.acceptRow(row);
        }
    }

    async acceptRow(row) {
        this.isLoading = true;
        try {
            await acceptAccount({ leadId: this.recordId, accountId: row.accountId });

            this.showToast(
                'Success',
                `Lead linked to ${row.accName} and marked "Linked – Enroll Existing".`,
                'success'
            );

            // Let other components on the page (e.g. the record's own fields) know it changed
            getRecordNotifyChange([{ recordId: this.recordId }]);

            // Refresh the duplicate list / wired data
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error linking account', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unknown error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}