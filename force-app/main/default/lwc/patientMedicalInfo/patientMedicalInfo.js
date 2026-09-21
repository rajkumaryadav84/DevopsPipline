import { LightningElement, api, track } from 'lwc';

export default class PatientMedicalInfo extends LightningElement {

    @track medical = {
        primaryCarePhysician: '',
        allergies: '',
        currentMedications: '',
        existingMedicalConditions: ''
    };

    handleChange(event) {

        const field = event.target.name;
        const value = event.target.value;

        this.medical = {
            ...this.medical,
            [field]: value
        };

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    section: 'medical',
                    data: this.medical
                }
            })
        );
    }

    @api
    getMedicalData() {
        return this.medical;
    }
}