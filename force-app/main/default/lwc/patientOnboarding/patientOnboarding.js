import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import resendVerificationEmail from '@salesforce/apex/PatientOnboardingController.resendVerificationEmail';
import saveDraft from '@salesforce/apex/PatientOnboardingController.saveDraft';
import submitPatient from '@salesforce/apex/PatientOnboardingController.submitPatient';

export default class PatientOnboarding extends LightningElement {
    showResendButton = false;
    @track patient = {
        // Personal Information
        firstName: '',
        lastName: '',
        dob: '',
        gender: '',
        ssnLast4: '',
        preferredLanguage: '',

        // Contact
        mobileNumber: '',
        alternatePhone: '',
        email: '',
        homeAddress: '',

        // Insurance
        insuranceProvider: '',
        memberId: '',
        groupNumber: '',
        policyHolderName: '',
        policyEffectiveDate: '',

        // Emergency
        contactName: '',
        relationship: '',
        emergencyMobile: '',

        // Medical
        primaryCarePhysician: '',
        allergies: '',
        currentMedications: '',
        existingMedicalConditions: '',

        // Consent
        hipaaAck: false,
        consentTreatment: false,
        electronicCommAuth: false,
        communicationPreference: [],

        // Verification
        verificationStatus: 'Pending Verification',
        verificationMethod: 'Email',
        verificationDate: null
    };

    isLoading = false;

    handleValueChange(event) {

    console.log('Received:', JSON.stringify(event.detail));

    this.patient = {
        ...this.patient,
        ...event.detail.data
    };

    console.log('Parent:', JSON.stringify(this.patient));
}
   

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({title,message,variant}));
    }

    validateForm() {
        let isValid = true;
        const components = [
            'c-patient-personal-info',
            'c-patient-contact-info',
            'c-patient-insurance-info',
            'c-patient-emergency-contact',
            'c-patient-medical-info',
            'c-patient-consent-info'
        ];

        components.forEach(component => {
            const child = this.template.querySelector(component);
            if (child && child.validate) {
                if (!child.validate()) {
                    isValid = false;
                }
            }
        });
        return isValid;
    }

    async handleSaveDraftFunc() {
    console.log('handleSaveDraftFunc Clicked');

    this.isLoading = true;

    try {
        console.log('Sending to Apex:', JSON.stringify(this.patient));
        const result = await saveDraft({
            wrapperJson: JSON.stringify(this.convertEmptyStringsToNull(this.patient))
        });

        console.log('Save Draft Result:', result);

        if (result) {
            this.patient = {
                ...this.patient,
                patientId: result
            };
        }

        this.showToast(
            'Success',
            'Patient saved as Draft successfully.',
            'success'
        );

    } catch (error) {
        console.error('Save Draft Error:', error);
        console.error('Error Body:', error.body);

        this.showToast(
            'Error',
            error.body ? error.body.message : error.message,
            'error'
        );
    } finally {
        this.isLoading = false;
    }
}
    async handleSubmitFunc() {
        console.log('handleSubmitFunc Clicked');
        console.log('this.patient'+JSON.stringify(this.patient));
        //if (!this.validateForm()) {
         //   this.showToast('Validation Error','Please complete all required fields.','error');
       //     return;
      //  }
        this.isLoading = true;
        try {
            const result = await submitPatient({wrapperJson: JSON.stringify(this.convertEmptyStringsToNull(this.patient))});
             //wrapperJson: JSON.stringify(this.convertEmptyStringsToNull(this.patient))

            this.patient = {...this.patient,
                patientId: result.patientId,
                verificationStatus: result.verificationStatus,
                verificationMethod: result.verificationMethod,
                verificationDate: result.verificationDate
            };
            this.showResendButton = true;

            this.showToast('Success','Patient submitted successfully. Verification email has been sent.','success');
        } catch (error) {
            this.showToast('Error',error.body ? error.body.message : error.message,'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSaveDraft() {
    console.log('Save Draft Clicked');
    this.handleSaveDraftFunc();
}

    handleSubmit() {
        console.log('Submit Clicked');
        this.handleSubmitFunc();
    }

    convertEmptyStringsToNull(data) {
    if (Array.isArray(data)) {
        return data.map(item => this.convertEmptyStringsToNull(item));
    }

    if (data !== null && typeof data === 'object') {
        const updatedObject = {};

        Object.keys(data).forEach(key => {
            updatedObject[key] = this.convertEmptyStringsToNull(data[key]);
        });

        return updatedObject;
    }

    if (data === '') {
        return null;
    }

    return data;
}
async handleResendEmail() {

    this.isLoading = true;

    try {

        await resendVerificationEmail({
            patientId: this.patient.patientId
        });

        this.showToast(
            'Success',
            'A new verification email has been sent.',
            'success'
        );

    } catch(error) {

        this.showToast(
            'Error',
            error.body ? error.body.message : error.message,
            'error'
        );

    } finally {

        this.isLoading = false;

    }
}
}