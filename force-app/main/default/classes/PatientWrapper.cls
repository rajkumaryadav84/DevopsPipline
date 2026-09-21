public class PatientWrapper {

    @AuraEnabled public Id patientId;

    // Personal Information
    @AuraEnabled public String firstName;
    @AuraEnabled public String lastName;
    @AuraEnabled public Date dob;
    @AuraEnabled public String gender;
    @AuraEnabled public String ssnLast4;
    @AuraEnabled public String preferredLanguage;

    // Contact Information
    @AuraEnabled public String mobileNumber;
    @AuraEnabled public String alternatePhone;
    @AuraEnabled public String email;
    @AuraEnabled public String homeAddress;

    // Insurance
    @AuraEnabled public String insuranceProvider;
    @AuraEnabled public String memberId;
    @AuraEnabled public String groupNumber;
    @AuraEnabled public String policyHolderName;
    @AuraEnabled public Date policyEffectiveDate;

    // Emergency Contact
    @AuraEnabled public String contactName;
    @AuraEnabled public String relationship;
    @AuraEnabled public String emergencyMobile;

    // Medical
    @AuraEnabled public String primaryCarePhysician;
    @AuraEnabled public String allergies;
    @AuraEnabled public String currentMedications;
    @AuraEnabled public String existingMedicalConditions;

    // HIPAA
    @AuraEnabled public Boolean hipaaAck;
    @AuraEnabled public Boolean consentTreatment;
    @AuraEnabled public Boolean electronicCommAuth;
    @AuraEnabled public List<String> communicationPreference;
// Verification
@AuraEnabled public String verificationMethod;
@AuraEnabled public String verificationStatus;
@AuraEnabled public Datetime verificationDate;    
}