import { LightningElement, api, track } from 'lwc';

export default class PatientInsuranceInfo extends LightningElement {

    @track insurance = {
        insuranceProvider: '',
        memberId: '',
        groupNumber: '',
        policyHolderName: '',
        policyEffectiveDate: ''
    };

    insuranceProviderOptions = [
        { label: 'Aetna', value: 'Aetna' },
        { label: 'Blue Cross Blue Shield', value: 'Blue Cross Blue Shield' },
        { label: 'Cigna', value: 'Cigna' },
        { label: 'Humana', value: 'Humana' },
        { label: 'Kaiser Permanente', value: 'Kaiser Permanente' },
        { label: 'Medicare', value: 'Medicare' },
        { label: 'Medicaid', value: 'Medicaid' },
        { label: 'UnitedHealthcare', value: 'UnitedHealthcare' },
        { label: 'Other', value: 'Other' }
    ];

    handleChange(event) {

        const field = event.target.name;
        const value = event.target.value;

        this.insurance = {
            ...this.insurance,
            [field]: value
        };

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    section: 'insurance',
                    data: this.insurance
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
    getInsuranceData() {
        return this.insurance;
    }

}