import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import resendVerificationEmail from '@salesforce/apex/PatientOnboardingController.resendVerificationEmail';

export default class ResendEmail extends LightningElement {

    @api recordId;

    connectedCallback() {

        console.log(this.recordId);
        this.sendEmail(this.recordId);
    }
    @wire(CurrentPageReference)

    getStateParameters(currentPageReference) {

       if (currentPageReference) {

          console.log(JSON.stringify(currentPageReference));
          this.recordId = currentPageReference.state.recordId;
          console.log(this.recordId);
       }

    }
   


     sendEmail(recId) {
        resendVerificationEmail({patientId : recId })
		.then(result => {
			this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Verification email resent successfully.',
                    variant: 'success'
                })
            );
             this.dispatchEvent(new CloseActionScreenEvent());
		})
		.catch(error => {
			this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
		})
       /* try {
             resendVerificationEmail({
                recordId: this.recordId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Verification email resent successfully.',
                    variant: 'success'
                })
            );
             this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );

        } finally {
            this.dispatchEvent(new CloseActionScreenEvent());
        }*/
    }
}