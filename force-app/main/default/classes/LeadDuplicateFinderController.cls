/**
 * Controller for the leadDuplicateCheck LWC.
 * - findDuplicates: given a Lead Id, finds Person Account records that match on
 *   FirstName + LastName + (Phone or Phone).
 * - acceptAccount: called when the user clicks "Accept" on a row. Updates the Lead's
 *   Existing_Patient_Account__c lookup and Intake_Status__c picklist.
 */
public with sharing class LeadDuplicateFinderController {

    @AuraEnabled(cacheable=true)
    public static List<AccountWrapper> findDuplicates(Id leadId) {
        List<AccountWrapper> result = new List<AccountWrapper>();

        Lead ld = [
            SELECT Id, FirstName, LastName, Phone
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        // Need at least a last name and one phone value to attempt a match
        if (String.isBlank(ld.LastName)) {
            return result;
        }

        Set<String> phoneNumbers = new Set<String>();
        if (String.isNotBlank(ld.Phone)) {
            phoneNumbers.add(ld.Phone);
        }
        

        if (phoneNumbers.isEmpty()) {
            return result;
        }

        // FirstName can legitimately be blank on a Lead/Account, so build the
        // filter dynamically to avoid excluding valid matches on a null FirstName.
        String firstNameFilter = String.isNotBlank(ld.FirstName)
            ? ' AND FirstName = :firstName'
            : '';

        String query =
            'SELECT Id, Name, PersonEmail, Phone ' +
            'FROM Account ' +
            'WHERE IsPersonAccount = true ' +
            'AND LastName = :lastName' +
            firstNameFilter +
            ' AND Phone IN :phoneNumbers ' +
            'WITH SYSTEM_MODE';

        String firstName = ld.FirstName;
        String lastName = ld.LastName;

        List<Account> matches = Database.query(query);

        for (Account acc : matches) {
            result.add(new AccountWrapper(acc));
        }
        return result;
    }

    @AuraEnabled
    public static void acceptAccount(Id leadId, Id accountId) {
        if (!Schema.sObjectType.Lead.fields.Existing_Patient_Account__c.isUpdateable()
            || !Schema.sObjectType.Lead.fields.Intake_Status__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update this Lead.');
        }

        try {
            Lead ld = new Lead(
                Id = leadId,
                Existing_Patient_Account__c = accountId,
                Intake_Status__c = 'Linked – Enroll Existing'
            );
            update ld;
        } catch (DmlException e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    public class AccountWrapper {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accName;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;

        public AccountWrapper(Account acc) {
            this.accountId = acc.Id;
            this.accName = acc.Name;
            this.phone =  acc.Phone ;
            this.email = acc.PersonEmail;
        }
    }
}