public with sharing class LeadTriggerHandler {

    private static final String LINKED_STATUS = 'Linked – Enroll Existing';
    private static final String READY_FOR_CONVERSION = 'Ready for Conversion';

    public static void validateDuplicatePatient(List<Lead> leads,Map<Id,Lead> leadMap) {

        Set<String> duplicateKeys = new Set<String>(); 

        // Prepare Lead Duplicate Keys
        for (Lead ld : leads) {
			Lead oldLead = leadMap.get(ld.Id);
            if (String.isBlank(ld.FirstName) || String.isBlank(ld.LastName) || String.isBlank(ld.Phone)) {
                continue;
            }
            if(ld.Phone != oldLead.Phone && oldLead.Phone == null ){
                continue;
            }
            if(ld.FirstName != oldLead.FirstName || ld.LastName != oldLead.LastName || ld.Phone != oldLead.Phone ){
                ld.Existing_Patient_Account__c = null;
            }
			
            duplicateKeys.add(ld.FirstName.trim().toLowerCase() + '_' + ld.LastName.trim().toLowerCase() + '_' +ld.Phone.replaceAll('[^0-9]', ''));
        }

        if (duplicateKeys.isEmpty()) {
            return;
        }

        // Query matching Person Accounts only
        Map<String, Account> accountMap = new Map<String, Account>();

        for (Account acc : [
            SELECT Id, Duplicate_Key__c
            FROM Account
            WHERE IsPersonAccount = true
            AND Duplicate_Key__c IN :duplicateKeys
        ]) {
            accountMap.put(acc.Duplicate_Key__c, acc);
        }

        // Validate Leads
        for (Lead ld : leads) {

            if (String.isBlank(ld.Duplicate_Key__c)) {
                continue;
            }

            if (!accountMap.isEmpty() &&  accountMap.containsKey(ld.Duplicate_Key__c)) {

                if (ld.Existing_Patient_Account__c == null
                    ) {

                    ld.addError('A Person Account already exists with the same First Name, Last Name and Phone.');
                }

            } else {
                ld.Intake_Status__c = READY_FOR_CONVERSION;
            }
        }
    }
}