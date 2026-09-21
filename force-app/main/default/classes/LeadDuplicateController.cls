public with sharing class LeadDuplicateController {

    public class DuplicateResponse {
        @AuraEnabled public Id existingPatientAccountId;
        @AuraEnabled public List<Account> accounts;
    }

    @AuraEnabled(cacheable=true)
    public static DuplicateResponse getDuplicatePersonAccounts(Id leadId) {

        Lead ld = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Phone,
                   Existing_Patient_Account__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        DuplicateResponse response = new DuplicateResponse();
        response.existingPatientAccountId = ld.Existing_Patient_Account__c;
        response.accounts = new List<Account>();

        if (String.isBlank(ld.FirstName) ||
            String.isBlank(ld.LastName) ||
            String.isBlank(ld.Phone)) {
            return response;
        }

        String duplicateKey =
            ld.FirstName.trim().toLowerCase() + '_' +
            ld.LastName.trim().toLowerCase() + '_' +
            ld.Phone.replaceAll('[^0-9]', '');

        response.accounts = [
            SELECT Id,
                   Name,
                   PersonEmail,
                   Phone,
                   Duplicate_Key__c
            FROM Account
            WHERE IsPersonAccount = true
            AND Duplicate_Key__c = :duplicateKey
            ORDER BY Name
        ];

        return response;
    }
}