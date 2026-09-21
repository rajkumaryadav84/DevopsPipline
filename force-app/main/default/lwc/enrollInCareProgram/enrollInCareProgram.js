import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAvailableCarePrograms from '@salesforce/apex/CareProgramEnrollmentController.getAvailableCarePrograms';
import getPatientActiveEnrollees from '@salesforce/apex/CareProgramEnrollmentController.getPatientActiveEnrollees';
import createEnrollee from '@salesforce/apex/CareProgramEnrollmentController.createEnrollee';

export default class EnrollInCareProgram extends NavigationMixin(LightningElement) {
    @api recordId; // Account (Patient) Record ID when embedded on Account page

    @track selectedProgramId = '';
    @track programOptions = [];
    @track programMap = new Map();
    @track selectedProgramDetails = null;

    @track activeEnrolleeMap = new Map();
    @track isLoading = false;
    @track hasActiveEnrollee = false;
    @track existingEnrollee = null;

    @wire(getAvailableCarePrograms)
    wiredPrograms({ error, data }) {
        if (data) {
            this.programOptions = data.map(prog => {
                this.programMap.set(prog.Id, prog);
                return { label: prog.Name, value: prog.Id };
            });
        } else if (error) {
            const errMsg = error.body ? error.body.message : (error.message || 'Failed to load Care Programs');
            this.showToast('Error', errMsg, 'error');
        }
    }

    @wire(getPatientActiveEnrollees, { patientAccountId: '$recordId' })
    wiredActiveEnrollees({ error, data }) {
        if (data) {
            const newMap = new Map();
            data.forEach(enrollee => {
                if (enrollee.CareProgramId) {
                    newMap.set(enrollee.CareProgramId, enrollee);
                }
            });
            this.activeEnrolleeMap = newMap;
            if (this.selectedProgramId) {
                this.evaluateActiveEnrollment();
            }
        }
    }

    get isEnrollDisabled() {
        return !this.selectedProgramId || this.hasActiveEnrollee || this.isLoading;
    }

    handleProgramChange(event) {
        this.selectedProgramId = event.detail.value;
        this.selectedProgramDetails = this.programMap.get(this.selectedProgramId);
        // Fast instant client-side lookup - 0ms UI delay!
        this.evaluateActiveEnrollment();
    }

    evaluateActiveEnrollment() {
        this.hasActiveEnrollee = false;
        this.existingEnrollee = null;

        if (this.selectedProgramId && this.activeEnrolleeMap.has(this.selectedProgramId)) {
            const activeRecord = this.activeEnrolleeMap.get(this.selectedProgramId);
            this.hasActiveEnrollee = true;
            this.existingEnrollee = {
                Id: activeRecord.Id,
                Name: activeRecord.Name,
                Status: activeRecord.Status,
                CareProgramName: activeRecord.CareProgram ? activeRecord.CareProgram.Name : (this.selectedProgramDetails ? this.selectedProgramDetails.Name : '')
            };
        }
    }

    async handleEnroll() {
        if (!this.recordId || !this.selectedProgramId) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await createEnrollee({
                patientAccountId: this.recordId,
                careProgramId: this.selectedProgramId,
                originatingLeadId: null
            });

            if (result.isSuccess) {
                this.showToast('Success', 'Patient successfully enrolled in Care Program!', 'success');
                // Navigate to newly created CareProgramEnrollee record page
                this.navigateToRecord(result.enrolleeId, 'CareProgramEnrollee');
            } else if (result.hasActiveEnrollee) {
                this.hasActiveEnrollee = true;
                this.existingEnrollee = {
                    Id: result.existingEnrollee.Id,
                    Name: result.existingEnrollee.Name,
                    Status: result.existingEnrollee.Status,
                    CareProgramName: result.existingEnrollee.CareProgram.Name
                };
                this.showToast('Enrollment Blocked', result.message, 'warning');
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (err) {
            this.showToast('Error', err.body ? err.body.message : err.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    navigateToExistingEnrollee() {
        if (this.existingEnrollee && this.existingEnrollee.Id) {
            this.navigateToRecord(this.existingEnrollee.Id, 'CareProgramEnrollee');
        }
    }

    navigateToRecord(recordId, objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'view'
            }
        });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}