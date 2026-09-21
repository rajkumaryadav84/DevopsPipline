import { LightningElement, api, track } from 'lwc';

export default class PatientConsentInfo extends LightningElement {

    @track consent = {

        hipaaAck:false,

        consentTreatment:false,

        electronicCommAuth:false,

        communicationPreference:[]

    };

    communicationOptions=[

        {
            label:'Email',
            value:'Email'
        },

        {
            label:'SMS',
            value:'SMS'
        },

        {
            label:'Phone',
            value:'Phone'
        }

    ];

   handleCheckbox(event) {

    const field = event.target.name;

    this.consent[field] = event.target.checked;

    console.log('Consent = ', JSON.stringify(this.consent));

    this.fireEvent();
}
    handleCommunication(event){

        this.consent.communicationPreference=event.detail.value;

        this.fireEvent();

    }

    fireEvent() {

    console.log('Fire Event Called');

    this.dispatchEvent(
        new CustomEvent('valuechange', {
            detail: {
                section: 'consent',
                data: this.consent
            }
        })
    );
}

    @api

    validate(){

        if(
            !this.consent.hipaaAck ||
            !this.consent.consentTreatment ||
            !this.consent.electronicCommAuth
        ){

            return false;

        }

        return true;

    }

    @api

    getConsentData(){

        return this.consent;

    }

}