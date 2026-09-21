import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCareProgramProducts from '@salesforce/apex/CareProgramProductListController.getCareProgramProducts';
import deleteCareProgramProduct from '@salesforce/apex/CareProgramProductListController.deleteCareProgramProduct';
import stampEnrolleeAuditFields from '@salesforce/apex/CareProgramProductListController.stampEnrolleeAuditFields';

const COLUMNS = [
    { label: 'Product', fieldName: 'productName', type: 'text', wrapText: true },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Availability', fieldName: 'availability', type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class CareProgramProductRelatedList extends LightningElement {
    /** Person Account record Id, auto-populated by the record page. */
    @api recordId;

    columns = COLUMNS;
    products = [];
    enrolleeId;
    careProgramId;
    careProgramName;
    isLoading = true;
    isModalOpen = false;
    isEditModalOpen = false;
    selectedProductId = null;

    wiredResult;

    @wire(getCareProgramProducts, { accountId: '$recordId' })
    wiredProducts(result) {
        this.wiredResult = result;
        const { data, error } = result;

        if (data) {
            this.enrolleeId = data.enrolleeId;
            this.careProgramId = data.careProgramId;
            this.careProgramName = data.careProgramName;
            this.products = data.products || [];
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.showToast('Error loading Care Program Products', this.reduceError(error), 'error');
        }
    }

    get hasEnrollee() {
        return !!this.enrolleeId;
    }

    get hasNoProducts() {
        return !this.isLoading && this.hasEnrollee && this.products.length === 0;
    }

    get isNewDisabled() {
        return !this.careProgramId;
    }

    get defaultFieldValues() {
        return this.careProgramId ? `CareProgramId=${this.careProgramId}` : '';
    }

    get emptyStateMessage() {
        return this.careProgramName
            ? `No Care Program Products found for ${this.careProgramName}.`
            : 'No Care Program Products found.';
    }

    handleNewClick() {
        if (!this.careProgramId) {
            this.showToast('Error', 'No Care Program found for this record.', 'error');
            return;
        }
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.selectedProductId = row.id;
            this.isEditModalOpen = true;
        } else if (actionName === 'delete') {
            this.deleteProduct(row.id);
        }
    }

    closeEditModal() {
        this.isEditModalOpen = false;
        this.selectedProductId = null;
    }

    async handleEditFormSuccess() {
        this.isEditModalOpen = false;
        this.selectedProductId = null;
        this.isLoading = true;
        this.showToast('Success', 'Care Program Product updated.', 'success');
        await refreshApex(this.wiredResult);
        this.isLoading = false;
    }

    async deleteProduct(productId) {
        this.isLoading = true;
        try {
            await deleteCareProgramProduct({ productId, enrolleeId: this.enrolleeId });
            this.showToast('Success', 'Care Program Product deleted.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.showToast('Error deleting product', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleFormSuccess() {
        this.isModalOpen = false;
        this.isLoading = true;

        try {
            await stampEnrolleeAuditFields({ enrolleeId: this.enrolleeId });
        } catch (error) {
            // Audit stamping is non-blocking; the create itself already succeeded.
            // eslint-disable-next-line no-console
            console.error('Failed to stamp enrollee audit fields', error);
        }

        this.showToast('Success', 'Care Program Product created.', 'success');
        await refreshApex(this.wiredResult);
        this.isLoading = false;
    }

    handleFormError(event) {
        this.showToast('Error creating product', this.reduceError(event.detail), 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (Array.isArray(error?.body?.pageErrors) && error.body.pageErrors.length) {
            return error.body.pageErrors.map((e) => e.message).join(', ');
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unknown error occurred.';
    }
}