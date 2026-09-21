public with sharing class PatientVerificationController {

    @AuraEnabled
    public static String verifyPatient(String token){

        if(String.isBlank(token)){
            return 'INVALID';
        }

        List<Patient_Verification__c> verificationList = [

            SELECT Id,
                   Token__c,
                   Is_Used__c,
                   Expiration_Date__c,
                   Patient_Onboarding__c

            FROM Patient_Verification__c

            WHERE Token__c=:token

            LIMIT 1
        ];

        if(verificationList.isEmpty()){
            return 'INVALID';
        }

        Patient_Verification__c verification =
            verificationList[0];

        if(verification.Is_Used__c){
            return 'ALREADY_USED';
        }

        if(verification.Expiration_Date__c < System.now()){

            return 'EXPIRED';

        }

        Patient_Onboarding__c patient = [

            SELECT Id,
                   Verification_Status__c,
                   Verification_Date__c,
                   Record_Status__c

            FROM Patient_Onboarding__c

            WHERE Id=:verification.Patient_Onboarding__c

            LIMIT 1
        ];

        patient.Verification_Status__c = 'Verified';

        patient.Verification_Date__c = System.now();

        patient.Record_Status__c = 'Completed';

        update patient;

        verification.Is_Used__c = true;

        update verification;

        return 'SUCCESS';

    }

}