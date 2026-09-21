import { LightningElement, track,api,wire } from 'lwc';

export default class PatientContactInfo extends LightningElement {

    @track contact = {
        mobileNumber: '',
        alternatePhone: '',
        email: '',
        homeAddress: ''
    };

    handleChange(event) {

        const field = event.target.name;
        const value = event.target.value;

        this.contact = {
            ...this.contact,
            [field]: value
        };

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    section: 'contact',
                    data: this.contact
                }
            })
        );
    }

    @api
    validate() {

        let isValid = true;

        const inputs = this.template.querySelectorAll(
            'lightning-input, lightning-textarea'
        );

        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }

}