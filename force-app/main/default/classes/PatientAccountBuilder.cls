/**
 * Maps Lead patient demographics onto the Person Account that Convert Lead
 * created. Pure construction — no DML, no SOQL.
 *
 * Not mapped here, deliberately:
 *  - Middle_Name__c: the org has Middle Name disabled, so neither Lead nor
 *    Account exposes a MiddleName field. Value stays on the Lead.
 *  - Prescription_Information__c: free text with no LSC standard home. Stays on
 *    the Lead, reachable through CareProgramEnrollee.LeadId.
 */
public with sharing class PatientAccountBuilder {
    /**
     * @param leadRecord source Lead, already converted
     * @param accountId Person Account produced by Database.convertLead
     * @return Account shaped for update
     */
    public static Account build(Lead leadRecord, Id accountId) {
        Account patient = new Account(Id = accountId);

        patient.PersonBirthdate = leadRecord.Patient_DOB__c;
        patient.PersonGender = leadRecord.Patient_Gender__c;
        patient.PersonEmail = leadRecord.Email;
        patient.Phone = leadRecord.Phone;
        patient.PersonMobilePhone = leadRecord.MobilePhone;
        patient.PersonOtherPhone = leadRecord.Patient_Alternate_Phone__c;
        patient.OwnerId = leadRecord.OwnerId;

        patient.PersonMailingStreet = leadRecord.Street;
        patient.PersonMailingCity = leadRecord.City;
        patient.PersonMailingState = leadRecord.State;
        patient.PersonMailingPostalCode = leadRecord.PostalCode;
        patient.PersonMailingCountry = leadRecord.Country;

        applyShippingAddress(patient, leadRecord);

        return patient;
    }

    /**
     * Shipping address becomes the person "Other" address. When the coordinator
     * ticked "same as primary" we copy the mailing values rather than trusting
     * the shipping fields, which are usually left blank in that case.
     */
    private static void applyShippingAddress(Account patient, Lead leadRecord) {
        if (leadRecord.Shipping_Same_As_Primary__c == true) {
            patient.PersonOtherStreet = leadRecord.Street;
            patient.PersonOtherCity = leadRecord.City;
            patient.PersonOtherState = leadRecord.State;
            patient.PersonOtherPostalCode = leadRecord.PostalCode;
            patient.PersonOtherCountry = leadRecord.Country;
            return;
        }

        patient.PersonOtherStreet = leadRecord.Shipping_Street__c;
        patient.PersonOtherCity = leadRecord.Shipping_City__c;
        patient.PersonOtherState = leadRecord.Shipping_State__c;
        patient.PersonOtherPostalCode = leadRecord.Shipping_Zip__c;
        patient.PersonOtherCountry = leadRecord.Shipping_Country__c;
    }
}