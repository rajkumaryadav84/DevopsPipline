public with sharing class PatientDuplicateService {

    public class DuplicateMatch {
        @AuraEnabled public Id patientId;
        @AuraEnabled public String patientName;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String email;
        @AuraEnabled public String mobileNumber;
        @AuraEnabled public String verificationStatus;
    }

    @AuraEnabled(cacheable=true)
    public static List<DuplicateMatch> checkDuplicate(
        String firstName,
        String lastName,
        Date dob,
        String email,
        String mobileNumber,
        Id excludePatientId
    ) {

        List<DuplicateMatch> duplicateList = new List<DuplicateMatch>();

        if(String.isBlank(firstName) &&
           String.isBlank(lastName) &&
           dob == null &&
           String.isBlank(email) &&
           String.isBlank(mobileNumber)){
            return duplicateList;
        }

        List<String> conditions = new List<String>();

        if(!String.isBlank(email)){
            conditions.add('Email__c = :email');
        }

        if(!String.isBlank(mobileNumber)){
            conditions.add('Mobile_Number__c = :mobileNumber');
        }

        if(!String.isBlank(firstName) &&
           !String.isBlank(lastName) &&
           dob != null){

            conditions.add('(First_Name__c = :firstName AND Last_Name__c = :lastName AND Date_of_Birth__c = :dob)');
        }

        if(conditions.isEmpty()){
            return duplicateList;
        }

        String query =
            'SELECT Id,' +
            ' First_Name__c,' +
            ' Last_Name__c,' +
            ' Date_of_Birth__c,' +
            ' Email__c,' +
            ' Mobile_Number__c,' +
            ' Verification_Status__c ' +
            'FROM Patient_Onboarding__c ' +
            'WHERE ' +
            String.join(conditions,' OR ');

        List<Patient_Onboarding__c> patients =
            Database.query(query);

        for(Patient_Onboarding__c patient : patients){

            if(excludePatientId != null &&
               patient.Id == excludePatientId){
                continue;
            }

            DuplicateMatch match = new DuplicateMatch();

            match.patientId = patient.Id;
            match.patientName =
                patient.First_Name__c + ' ' +
                patient.Last_Name__c;

            match.dateOfBirth =
                patient.Date_of_Birth__c;

            match.email =
                patient.Email__c;

            match.mobileNumber =
                patient.Mobile_Number__c;

            match.verificationStatus =
                patient.Verification_Status__c;

            duplicateList.add(match);
        }

        return duplicateList;
    }
   @AuraEnabled
public static Boolean isDuplicate(
    String firstName,
    String lastName,
    Date dob,
    String email,
    String mobileNumber,
    Id excludePatientId
) {

    List<DuplicateMatch> duplicates = checkDuplicate(
        firstName,
        lastName,
        dob,
        email,
        mobileNumber,
        excludePatientId
    );

    return !duplicates.isEmpty();
}
}