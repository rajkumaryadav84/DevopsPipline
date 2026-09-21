import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import verifyPatient from '@salesforce/apex/PatientVerificationController.verifyPatient';

export default class PatientVerificationInfo extends LightningElement {

    @api verificationStatus = 'Pending Verification';
    @api verificationMethod = 'Email';
    @api verificationDate;

    token;
    message;
    isVerified = false;

    @wire(CurrentPageReference)
    getStateParameters(pageRef) {

        if (pageRef && pageRef.state) {

            this.token = pageRef.state.c__token;

            if (this.token && !this.isVerified) {
                this.isVerified = true;
                this.verifyToken();
            }
        }
    }

    async verifyToken() {

        try {

            const result = await verifyPatient({
                token: this.token
            });

            this.message = result;
            this.verificationStatus = 'Verified';
            this.verificationMethod = 'Email';
            this.verificationDate = new Date().toISOString();

        } catch (error) {

            this.verificationStatus = 'Verification Failed';

            this.message = error.body
                ? error.body.message
                : error.message;

        }
    }
}