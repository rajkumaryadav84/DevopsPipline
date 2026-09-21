/**
 * Every query the Lead to Patient conversion needs. Kept in one class so the
 * service and builders stay free of SOQL and the whole conversion can be
 * bulk-fetched before any DML runs.
 */
public with sharing virtual class LeadConvertSelector {
    /**
     * Lead fields the conversion reads. Past_Qualification__c is deliberately
     * absent: it is not readable by every intake user, and the gate uses
     * Intake_Status__c directly.
     */
    public virtual Map<Id, Lead> selectLeadsForConversion(Set<Id> leadIds) {
        return new Map<Id, Lead>(
            [
                SELECT
                    Id,
                    Salutation,
                    FirstName,
                    LastName,
                    Company,
                    Email,
                    Phone,
                    MobilePhone,
                    Street,
                    City,
                    State,
                    PostalCode,
                    Country,
                    Status,
                    OwnerId,
                    IsConverted,
                    ConvertedAccountId,
                    Middle_Name__c,
                    Patient_DOB__c,
                    Patient_Gender__c,
                    Patient_Alternate_Phone__c,
                    Preferred_Language_c__c,
                    Shipping_Street__c,
                    Shipping_City__c,
                    Shipping_State__c,
                    Shipping_Zip__c,
                    Shipping_Country__c,
                    Shipping_Same_As_Primary__c,
                    Caregiver_FirstName__c,
                    Caregiver_LastName__c,
                    Caregiver_Phone__c,
                    Caregiver_Relationship__c,
                    Insurance_Plan_Name__c,
                    Insurance_Plan_Type__c,
                    Insurance_Phone__c,
                    Insurance_Employer__c,
                    Policy_Number__c,
                    Group_Number__c,
                    Policy_Holder_Name__c,
                    Policy_Holder_DOB__c,
                    Diagnosis__c,
                    Prescription_Information__c,
                    Prescriber_Full_Name__c,
                    Prescriber_NPI__c,
                    Care_Program_Of_Interest__c,
                    Care_Program_Of_Interest__r.Name,
                    Resolved_Prescriber__c,
                    Existing_Patient_Account__c,
                    Intake_Status__c,
                    All_Required_Consents_Complete__c,
                    Consent_HIPAA_Status__c,
                    Consent_DataProcessing_Status__c,
                    Consent_CareProgram_Status__c
                FROM Lead
                WHERE Id IN :leadIds
            ]
        );
    }

    /** Consents currently pointing at the Leads, keyed by Lead Id. */
    public Map<Id, List<AuthorizationFormConsent>> selectConsentsByLead(Set<Id> leadIds) {
        Map<Id, List<AuthorizationFormConsent>> byLead = new Map<Id, List<AuthorizationFormConsent>>();
        for (AuthorizationFormConsent consent : [
            SELECT Id, ConsentGiverId, Status, AuthorizationFormTextId, ConsentCapturedDateTime
            FROM AuthorizationFormConsent
            WHERE ConsentGiverId IN :leadIds
        ]) {
            Id leadId = (Id) consent.ConsentGiverId;
            if (!byLead.containsKey(leadId)) {
                byLead.put(leadId, new List<AuthorizationFormConsent>());
            }
            byLead.get(leadId).add(consent);
        }
        return byLead;
    }

    /** Resolved prescribers with the provider Account that CareProgramProvider keys on. */
    public Map<Id, HealthcareProvider> selectProviders(Set<Id> providerIds) {
        if (providerIds.isEmpty()) {
            return new Map<Id, HealthcareProvider>();
        }
        return new Map<Id, HealthcareProvider>(
            [
                SELECT Id, Name, AccountId, Account.Name, ProviderType
                FROM HealthcareProvider
                WHERE Id IN :providerIds
            ]
        );
    }

    /** Existing CareProgramProvider rows keyed by provider Account, so we reuse instead of duplicating. */
    public Map<Id, CareProgramProvider> selectCareProgramProvidersByAccount(Set<Id> accountIds) {
        Map<Id, CareProgramProvider> byAccount = new Map<Id, CareProgramProvider>();
        if (accountIds.isEmpty()) {
            return byAccount;
        }
        for (CareProgramProvider provider : [
            SELECT Id, AccountId
            FROM CareProgramProvider
            WHERE AccountId IN :accountIds
        ]) {
            if (!byAccount.containsKey(provider.AccountId)) {
                byAccount.put(provider.AccountId, provider);
            }
        }
        return byAccount;
    }

    /** Junction rows that already tie a HealthcareProvider to a CareProgramProvider. */
    public Set<Id> selectLinkedHealthcareProviderIds(Set<Id> careProgramProviderIds) {
        Set<Id> linked = new Set<Id>();
        if (careProgramProviderIds.isEmpty()) {
            return linked;
        }
        for (CarePgmProvHealthcareProvider junction : [
            SELECT HealthcareProviderId
            FROM CarePgmProvHealthcareProvider
            WHERE CareProgramProviderId IN :careProgramProviderIds
        ]) {
            linked.add(junction.HealthcareProviderId);
        }
        return linked;
    }

    /**
     * A Lead Status flagged IsConverted, used when the caller does not supply one.
     * The org currently exposes exactly one such value.
     */
    public String defaultConvertedStatus() {
        List<LeadStatus> statuses = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = TRUE
            ORDER BY SortOrder
            LIMIT 1
        ];
        return statuses.isEmpty() ? null : statuses[0].MasterLabel;
    }
}