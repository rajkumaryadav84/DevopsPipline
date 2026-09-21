import { LightningElement, api, track } from 'lwc';

export default class PatientEmergencyContact extends LightningElement {

    @track emergency = {
        contactName: '',
        relationship: '',
        emergencyMobile: ''
    };

    relationshipOptions = [
        { label: 'Spouse', value: 'Spouse' },
        { label: 'Parent', value: 'Parent' },
        { label: 'Mother', value: 'Mother' },
        { label: 'Father', value: 'Father' },
        { label: 'Sibling', value: 'Sibling' },
        { label: 'Brother', value: 'Brother' },
        { label: 'Sister', value: 'Sister' },
        { label: 'Child', value: 'Child' },
        { label: 'Guardian', value: 'Guardian' },
        { label: 'Friend', value: 'Friend' },
        { label: 'Relative', value: 'Relative' },
        { label: 'Caregiver', value: 'Caregiver' },
        { label: 'Other', value: 'Other' }
    ];

    handleChange(event) {

        const field = event.target.name;
        const value = event.target.value;

        this.emergency = {
            ...this.emergency,
            [field]: value
        };

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    section: 'emergency',
                    data: this.emergency
                }
            })
        );
    }

    @api
    validate() {

        let isValid = true;

        const fields = this.template.querySelectorAll(
            'lightning-input, lightning-combobox'
        );

        fields.forEach(field => {
            if (!field.reportValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }

    @api
    getEmergencyData() {
        return this.emergency;
    }

}