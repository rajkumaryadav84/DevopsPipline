public class PatientOnboardingController {
  @AuraEnabled
    public static Id saveDraft(String wrapperJson) {
     PatientWrapper wrapper = (PatientWrapper)JSON.deserialize(wrapperJson,PatientWrapper.class);
        if (wrapper == null) {
            throw new AuraHandledException('Patient information is required.');
        }

        // Duplicate Check
        List<PatientDuplicateService.DuplicateMatch> duplicates =
            PatientDuplicateService.checkDuplicate(
                wrapper.firstName,
                wrapper.lastName,
                wrapper.dob,
                wrapper.email,
                wrapper.mobileNumber,
                wrapper.patientId
            );

        if (!duplicates.isEmpty()) {
            throw new AuraHandledException('Duplicate patient found.');
        }

        Patient_Onboarding__c patient;

        // Update existing draft
        if (wrapper.patientId != null) {

            patient = [
                SELECT Id
                FROM Patient_Onboarding__c
                WHERE Id = :wrapper.patientId
                LIMIT 1
            ];

        } else {

            patient = new Patient_Onboarding__c();

        }

        mapWrapperToPatient(wrapper, patient);

        patient.Verification_Status__c = 'Draft';
        patient.Verification_Method__c =
            String.isBlank(wrapper.verificationMethod)
            ? 'Email'
            : wrapper.verificationMethod;

        patient.Is_Draft_c__c = true;
        // System.debug('Wrapper HIPAA: ' + wrapper.hipaaAck);
      // System.debug('Patient HIPAA: ' + patient.HIPAA_Privacy_Notice__c);

        if (wrapper.patientId == null) {
            insert patient;
        } else {
            update patient;
        }

        return patient.Id;
       
    }

    /**
     * Maps wrapper values to Patient object
     */
    private static void mapWrapperToPatient(
        PatientWrapper wrapper,
        Patient_Onboarding__c patient
    ) {

        patient.First_Name__c = wrapper.firstName;
        patient.Last_Name__c = wrapper.lastName;
        patient.Date_of_Birth__c = wrapper.dob;
        patient.Gender__c = wrapper.gender;
        patient.SSN_Last_4__c = wrapper.ssnLast4;
        patient.Preferred_Language__c = wrapper.preferredLanguage;

        patient.Mobile_Number__c = wrapper.mobileNumber;
        patient.Alternate_Phone__c = wrapper.alternatePhone;
        patient.Email__c = wrapper.email;
        patient.Home_Address__c = wrapper.homeAddress;

        patient.Insurance_Provider__c = wrapper.insuranceProvider;
        patient.Member_ID__c = wrapper.memberId;
        patient.Group_Number__c = wrapper.groupNumber;
        patient.Policy_Holder_Name__c = wrapper.policyHolderName;
        patient.Policy_Effective_Date__c = wrapper.policyEffectiveDate;

        patient.Contact_Name__c = wrapper.contactName;
        patient.Relationship__c = wrapper.relationship;
        patient.Emergency_Mobile__c = wrapper.emergencyMobile;

        patient.Primary_Care_Physician__c =
            wrapper.primaryCarePhysician;

        patient.Allergies__c = wrapper.allergies;
        patient.Current_Medications__c =
            wrapper.currentMedications;

        patient.Existing_Medical_Conditions__c =
            wrapper.existingMedicalConditions;

       // patient.HIPAA_Privacy_Notice__c =
         //   wrapper.hipaaAck;

       // patient.Consent_to_Treatment__c =
        //    wrapper.consentTreatment;

       // patient.Electronic_Communication_Authorization__c =
        //    wrapper.electronicCommAuth;

        patient.Communication_Preference__c =
            wrapper.communicationPreference != null
            ? String.join(wrapper.communicationPreference, ';')
            : null;
    }
    @AuraEnabled
public static SubmitResponse submitPatient(String wrapperJson) {
    PatientWrapper wrapper = (PatientWrapper)JSON.deserialize(wrapperJson,PatientWrapper.class);

    if(wrapper == null){
        throw new AuraHandledException('Patient information is required.');
    }
    System.debug('String.isBlank(wrapper.firstName)>>> '+String.isBlank(wrapper.firstName));
    System.debug('String.isBlank(wrapper.lastName)>>> '+String.isBlank(wrapper.lastName));
    System.debug('wrapper.dob == null>>> '+wrapper.dob);
    System.debug('String.isBlank(wrapper.mobileNumber)>>> '+String.isBlank(wrapper.mobileNumber));
    System.debug('String.isBlank(wrapper.email)>>> '+String.isBlank(wrapper.email));
    System.debug('String.isBlank(wrapper.contactName)>>> '+String.isBlank(wrapper.contactName));
    System.debug('String.isBlank(wrapper.relationship)>>> '+String.isBlank(wrapper.relationship));
    System.debug('String.isBlank(wrapper.emergencyMobile)>>> '+String.isBlank(wrapper.emergencyMobile));
    System.debug('String.isBlank(wrapper.hipaaAck)>>> '+wrapper.hipaaAck);
    System.debug('String.isBlank(wrapper.consentTreatment)>>> '+wrapper.consentTreatment);
    System.debug('String.isBlank(wrapper.electronicCommAuth)>>> '+wrapper.electronicCommAuth);
    if(String.isBlank(wrapper.firstName) ||
       String.isBlank(wrapper.lastName) ||
       wrapper.dob == null ||
       String.isBlank(wrapper.mobileNumber) ||
       String.isBlank(wrapper.email) ||
       String.isBlank(wrapper.contactName) ||
       String.isBlank(wrapper.relationship) ||
       String.isBlank(wrapper.emergencyMobile) ||
       !wrapper.hipaaAck ||
       !wrapper.consentTreatment ||
       !wrapper.electronicCommAuth){

        throw new AuraHandledException(
            'Please complete all mandatory fields.'
        );
    }

    // Duplicate Check
List<PatientDuplicateService.DuplicateMatch> duplicates =
    PatientDuplicateService.checkDuplicate(
        wrapper.firstName,
        wrapper.lastName,
        wrapper.dob,
        wrapper.email,
        wrapper.mobileNumber,
        null
    );

if (!duplicates.isEmpty()) {
    throw new AuraHandledException('Duplicate patient found.');
}

    Patient_Onboarding__c patient = new Patient_Onboarding__c();

    patient.First_Name__c = wrapper.firstName;
    patient.Last_Name__c = wrapper.lastName;
    patient.Date_of_Birth__c = wrapper.dob;
    patient.Gender__c = wrapper.gender;
    patient.SSN_Last_4__c = wrapper.ssnLast4;
    patient.Preferred_Language__c = wrapper.preferredLanguage;

    patient.Mobile_Number__c = wrapper.mobileNumber;
    patient.Alternate_Phone__c = wrapper.alternatePhone;
    patient.Email__c = wrapper.email;
    patient.Home_Address__c = wrapper.homeAddress;

    patient.Insurance_Provider__c = wrapper.insuranceProvider;
    patient.Member_ID__c = wrapper.memberId;
    patient.Group_Number__c = wrapper.groupNumber;
    patient.Policy_Holder_Name__c = wrapper.policyHolderName;
    //patient.Policy_Effective_Date__c = wrapper.policyEffectiveDate;

    patient.Contact_Name__c = wrapper.contactName;
    patient.Relationship__c = wrapper.relationship;
    patient.Emergency_Mobile__c = wrapper.emergencyMobile;

    patient.Primary_Care_Physician__c = wrapper.primaryCarePhysician;
    patient.Allergies__c = wrapper.allergies;
    patient.Current_Medications__c = wrapper.currentMedications;
    patient.Existing_Medical_Conditions__c =
        wrapper.existingMedicalConditions;

    patient.HIPAA_Privacy_Notice__c =
        wrapper.hipaaAck;

    patient.Consent_to_Treatment__c =
        wrapper.consentTreatment;

    patient.Electronic_Communication_Authorization__c =
        wrapper.electronicCommAuth;

    patient.Communication_Preference__c = String.join(wrapper.communicationPreference, ';');

    patient.Verification_Status__c = 'Pending Verification';
    patient.Verification_Method__c = 'Email';
    patient.Is_Draft_c__c = false;

    insert patient;

    // Send Verification Email
    PatientVerificationService.generateAndSendToken(patient.Id);
    
    SubmitResponse response = new SubmitResponse();

    response.patientId = patient.Id;
    response.verificationStatus = patient.Verification_Status__c;
    response.verificationMethod = patient.Verification_Method__c;
    response.verificationDate = patient.Verification_Date__c;

    return response;
}
    
    @AuraEnabled
public static void resendVerificationEmail(Id patientId) {

    if (patientId == null) {
        throw new AuraHandledException('Patient Id is required.');
    }

    PatientVerificationService.generateAndSendToken(patientId);
}
    
public class SubmitResponse {

    @AuraEnabled
    public Id patientId;

    @AuraEnabled
    public String verificationStatus;

    @AuraEnabled
    public String verificationMethod;

    @AuraEnabled
    public Datetime verificationDate;

}    
    
    
}