public with sharing class PatientVerificationService {

    public static void generateAndSendToken(Id patientId){

        if(patientId == null){
            return;
        }

        Patient_Onboarding__c patient = [

            SELECT Id,
                   First_Name__c,
                   Email__c,
                   Verification_Status__c

            FROM Patient_Onboarding__c

            WHERE Id=:patientId

            LIMIT 1
        ];

        // Generate Secure Token

        String token =
            EncodingUtil.convertToHex(
                Crypto.generateDigest(
                    'SHA-256',
                    Blob.valueOf(
                        patientId +
                        String.valueOf(System.now().getTime())
                    )
                )
            );

        // Expire old tokens

        List<Patient_Verification__c> oldTokens = [

            SELECT Id

            FROM Patient_Verification__c

            WHERE Patient_Onboarding__c=:patientId

            AND Is_Used__c=false
        ];

        for(Patient_Verification__c pv : oldTokens){

            pv.Is_Used__c = true;

        }

        if(!oldTokens.isEmpty()){

            update oldTokens;

        }

        // Create new token

        Patient_Verification__c verification =
            new Patient_Verification__c();

        verification.Patient_Onboarding__c = patient.Id;

        verification.Token__c = token;

        verification.Expiration_Date__c =
            System.now().addHours(2);

        verification.Is_Used__c = false;

        insert verification;

        // Update Patient

        patient.Verification_Status__c = 'Pending Verification';

        update patient;

        // Send Email

        PatientEmailService.sendVerificationEmail(
            patient,
            token
        );

    }
    


}