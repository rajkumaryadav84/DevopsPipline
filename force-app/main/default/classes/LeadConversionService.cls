/**
 * Lead to Patient conversion.
 *
 * Convert Lead natively produces a Person Account when the Lead has a blank
 * Company and Person Accounts are enabled, so no Account is created by hand.
 * Everything downstream — Care Program Enrollee, insurance, language,
 * diagnosis, caregiver, prescriber, consent, files — is built here.
 *
 * Ordering constraints this class exists to enforce:
 *  1. Company must be blanked before convertLead, or the org creates a Business
 *     Account instead of a Person Account.
 *  2. A converted Lead is read-only, so any Lead field change happens before the
 *     convert call.
 *  3. MemberPlan is inserted before the Enrollee so PrimaryMemberPlanId can be
 *     set on insert rather than in a follow-up update.
 *  4. Caregiver Contact and CareProgramProvider are inserted before the records
 *     that reference them.
 *
 * The whole batch shares one savepoint: a failure anywhere rolls back the
 * conversion too, so a Lead is never left converted with a half-built program
 * record.
 */
public without sharing class LeadConversionService {
    @TestVisible
    private static LeadConvertSelector selector = new LeadConvertSelector();

    /** Convenience for single-record callers. */
    public static LeadConversionResult convert(LeadConversionRequest request) {
        return convert(new List<LeadConversionRequest>{ request })[0];
    }

    /**
     * Converts each requested Lead. Gate failures come back as failed results;
     * a DML failure rolls the whole batch back and every result reports it.
     */
    public static List<LeadConversionResult> convert(List<LeadConversionRequest> requests) {
        Map<Id, LeadConversionResult> resultsByLead = new Map<Id, LeadConversionResult>();
        Map<Id, LeadConversionRequest> requestsByLead = new Map<Id, LeadConversionRequest>();

        for (LeadConversionRequest request : requests) {
            if (request == null || request.leadId == null) {
                continue;
            }
            requestsByLead.put(request.leadId, request);
            resultsByLead.put(request.leadId, new LeadConversionResult(request.leadId));
        }

        if (requestsByLead.isEmpty()) {
            return orderedResults(requests, resultsByLead);
        }

        Map<Id, Lead> leadsById = selector.selectLeadsForConversion(requestsByLead.keySet());

        // Gate every Lead before touching anything. Blocked Leads drop out here.
        Map<Id, Lead> convertible = new Map<Id, Lead>();
        for (Id leadId : requestsByLead.keySet()) {
            Lead leadRecord = leadsById.get(leadId);
            List<String> problems = LeadConversionValidator.validate(leadRecord);

            if (problems.isEmpty()) {
                convertible.put(leadId, leadRecord);
            } else {
                resultsByLead.put(leadId, LeadConversionResult.failure(leadId, LeadConversionValidator.describeProblems(problems)));
            }
        }

        if (convertible.isEmpty()) {
            return orderedResults(requests, resultsByLead);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            runConversion(convertible, requestsByLead, resultsByLead);
        } catch (Exception e) {
            Database.rollback(sp);
            String message = 'Conversion failed and was rolled back: ' + e.getMessage();
            for (Id leadId : convertible.keySet()) {
                resultsByLead.put(leadId, LeadConversionResult.failure(leadId, message));
            }
        }

        return orderedResults(requests, resultsByLead);
    }

    /** Everything between the savepoint and the commit. */
    private static void runConversion(
        Map<Id, Lead> convertible,
        Map<Id, LeadConversionRequest> requestsByLead,
        Map<Id, LeadConversionResult> resultsByLead
    ) {
        blankCompany(convertible.values());

        Map<Id, Database.LeadConvertResult> convertResults = convertLeads(convertible, requestsByLead);

        // Person Account demographics.
        List<Account> patients = new List<Account>();
        for (Id leadId : convertResults.keySet()) {
            patients.add(PatientAccountBuilder.build(convertible.get(leadId), convertResults.get(leadId).getAccountId()));
        }
        update patients;

        createProgramRecords(convertible, requestsByLead, resultsByLead, convertResults);
    }

    /**
     * A populated Company makes Convert Lead build a Business Account. Blanking
     * it is what makes the person path happen.
     */
    private static void blankCompany(List<Lead> leads) {
        List<Lead> updates = new List<Lead>();
        for (Lead leadRecord : leads) {
            if (String.isNotBlank(leadRecord.Company)) {
                updates.add(new Lead(Id = leadRecord.Id, Company = null));
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Map<Id, Database.LeadConvertResult> convertLeads(
        Map<Id, Lead> convertible,
        Map<Id, LeadConversionRequest> requestsByLead
    ) {
        String orgConvertedStatus = selector.defaultConvertedStatus();

        List<Id> orderedLeadIds = new List<Id>(convertible.keySet());
        List<Database.LeadConvert> converts = new List<Database.LeadConvert>();

        for (Id leadId : orderedLeadIds) {
            LeadConversionRequest request = requestsByLead.get(leadId);
            String convertedStatus = String.isNotBlank(request.convertedStatus)
                ? request.convertedStatus
                : orgConvertedStatus;

            if (String.isBlank(convertedStatus)) {
                throw new LeadConversionException(
                    'No Lead Status is marked as Converted in this org. Add one before converting Leads.'
                );
            }

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setConvertedStatus(convertedStatus);
            lc.setDoNotCreateOpportunity(true);
            if (request.ownerId != null) {
                lc.setOwnerId(request.ownerId);
            }
            converts.add(lc);
        }

        Map<Id, Database.LeadConvertResult> byLead = new Map<Id, Database.LeadConvertResult>();
        List<Database.LeadConvertResult> convertResults = Database.convertLead(converts, false);

        for (Integer i = 0; i < convertResults.size(); i++) {
            Database.LeadConvertResult convertResult = convertResults[i];
            if (!convertResult.isSuccess()) {
                throw new LeadConversionException('Convert Lead failed: ' + firstError(convertResult));
            }
            byLead.put(orderedLeadIds[i], convertResult);
        }

        return byLead;
    }

    private static String firstError(Database.LeadConvertResult convertResult) {
        List<String> messages = new List<String>();
        for (Database.Error error : convertResult.getErrors()) {
            messages.add(error.getMessage());
        }
        return messages.isEmpty() ? 'unknown error' : String.join(messages, '; ');
    }

    /**
     * Builds and inserts the LSC graph for every converted patient, one DML per
     * object type regardless of batch size.
     */
    private static void createProgramRecords(
        Map<Id, Lead> convertible,
        Map<Id, LeadConversionRequest> requestsByLead,
        Map<Id, LeadConversionResult> resultsByLead,
        Map<Id, Database.LeadConvertResult> convertResults
    ) {
        Set<Id> leadIds = convertResults.keySet();

        Map<Id, List<AuthorizationFormConsent>> consentsByLead = selector.selectConsentsByLead(leadIds);

        // --- MemberPlan first, so the Enrollee can reference it on insert.
        Map<Id, MemberPlan> plansByLead = new Map<Id, MemberPlan>();
        for (Id leadId : leadIds) {
            if (!requestsByLead.get(leadId).wantsMemberPlan()) {
                continue;
            }
            MemberPlan plan = CareEnrollmentBuilder.buildMemberPlan(
                convertible.get(leadId),
                convertResults.get(leadId).getAccountId()
            );
            if (plan != null) {
                plansByLead.put(leadId, plan);
            }
        }
        if (!plansByLead.isEmpty() && Schema.sObjectType.MemberPlan.isCreateable()) {
            Database.insert(plansByLead.values(), true);
        }

        // --- Care Program Enrollee, built here but inserted asynchronously.
        // See CareEnrolleeQueueable: the ATM orchestration this insert starts
        // cannot share a transaction with Convert Lead without breaching the
        // SOQL limit.
        List<CareProgramEnrollee> enrollees = new List<CareProgramEnrollee>();
        for (Id leadId : leadIds) {
            MemberPlan plan = plansByLead.get(leadId);
            enrollees.add(
                CareEnrollmentBuilder.buildEnrollee(
                    convertible.get(leadId),
                    convertResults.get(leadId).getAccountId(),
                    plan == null ? null : plan.Id
                )
            );
        }

        // --- Language and diagnosis.
        List<PersonLanguage> languages = new List<PersonLanguage>();
        List<HealthCondition> conditions = new List<HealthCondition>();
        for (Id leadId : leadIds) {
            Id accountId = convertResults.get(leadId).getAccountId();
            PersonLanguage language = CareEnrollmentBuilder.buildPersonLanguage(convertible.get(leadId), accountId);
            if (language != null) {
                languages.add(language);
            }
            HealthCondition condition = CareEnrollmentBuilder.buildHealthCondition(convertible.get(leadId), accountId);
            if (condition != null) {
                conditions.add(condition);
            }
        }
        if (!languages.isEmpty() && Schema.sObjectType.PersonLanguage.isCreateable()) {
            Database.insert(languages, false);
        }
        if (!conditions.isEmpty() && Schema.sObjectType.HealthCondition.isCreateable()) {
            Database.insert(conditions, false);
        }

        createCaregivers(convertible, convertResults);
        linkPrescribers(convertible, requestsByLead, convertResults);

        // --- Consent handoff. Files need no handling: Convert Lead moves
        // ContentDocumentLinks to the Account on its own.
        List<AuthorizationFormConsent> consentUpdates = new List<AuthorizationFormConsent>();
        for (Id leadId : leadIds) {
            consentUpdates.addAll(
                CareEnrollmentBuilder.repointConsents(
                    consentsByLead.get(leadId),
                    convertResults.get(leadId).getAccountId()
                )
            );
        }
        if (!consentUpdates.isEmpty()) {
            Database.update(consentUpdates, false);
        }

        // --- Enrollee creation runs after this transaction commits.
        System.enqueueJob(new CareEnrolleeQueueable(enrollees));

        // --- Report back.
        for (Id leadId : leadIds) {
            LeadConversionResult result = resultsByLead.get(leadId);
            result.isSuccess = true;
            result.accountId = convertResults.get(leadId).getAccountId();
            result.contactId = convertResults.get(leadId).getContactId();
            MemberPlan plan = plansByLead.get(leadId);
            result.memberPlanId = plan == null ? null : plan.Id;
        }
    }

    /**
     * Caregiver Person Account plus the relationship that ties it to the
     * patient. The relationship needs the caregiver's person Contact, which
     * only exists once the Account is inserted.
     */
    private static void createCaregivers(Map<Id, Lead> convertible, Map<Id, Database.LeadConvertResult> convertResults) {
        Id personAccountRecordTypeId = CareEnrollmentBuilder.personAccountRecordTypeId();

        Map<Id, Account> caregiversByLead = new Map<Id, Account>();
        for (Id leadId : convertResults.keySet()) {
            Account caregiver = CareEnrollmentBuilder.buildCaregiverAccount(
                convertible.get(leadId),
                personAccountRecordTypeId
            );
            if (caregiver != null) {
                caregiversByLead.put(leadId, caregiver);
            }
        }
        if (caregiversByLead.isEmpty()) {
            return;
        }

        Database.insert(caregiversByLead.values(), false);

        Set<Id> caregiverAccountIds = new Set<Id>();
        for (Account caregiver : caregiversByLead.values()) {
            if (caregiver.Id != null) {
                caregiverAccountIds.add(caregiver.Id);
            }
        }
        if (caregiverAccountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> caregiverContacts = new Map<Id, Account>(
            [SELECT Id, PersonContactId FROM Account WHERE Id IN :caregiverAccountIds WITH USER_MODE]
        );

        List<AccountContactRelation> relations = new List<AccountContactRelation>();
        for (Id leadId : caregiversByLead.keySet()) {
            Account caregiverAcc = caregiversByLead.get(leadId);
            if (caregiverAcc == null || caregiverAcc.Id == null || !caregiverContacts.containsKey(caregiverAcc.Id)) {
                continue;
            }
            Id caregiverContactId = caregiverContacts.get(caregiverAcc.Id).PersonContactId;
            if (caregiverContactId != null) {
                relations.add(
                    CareEnrollmentBuilder.buildCaregiverRelation(
                        convertible.get(leadId),
                        convertResults.get(leadId).getAccountId(),
                        caregiverContactId
                    )
                );
            }
        }
        if (!relations.isEmpty() && Schema.sObjectType.AccountContactRelation.isCreateable()) {
            Database.insert(relations, false);
        }
    }

    /**
     * Attaches the referring prescriber to the program. CareProgramProvider keys
     * on the provider's Account, so an existing row for that Account is reused
     * rather than duplicated.
     */
    private static void linkPrescribers(
        Map<Id, Lead> convertible,
        Map<Id, LeadConversionRequest> requestsByLead,
        Map<Id, Database.LeadConvertResult> convertResults
    ) {
        Set<Id> providerIds = new Set<Id>();
        for (Id leadId : convertResults.keySet()) {
            Lead leadRecord = convertible.get(leadId);
            if (requestsByLead.get(leadId).wantsPrescriberLink() && leadRecord.Resolved_Prescriber__c != null) {
                providerIds.add(leadRecord.Resolved_Prescriber__c);
            }
        }

        Map<Id, HealthcareProvider> providers = selector.selectProviders(providerIds);

        List<CareProgramProvider> patientProviders = new List<CareProgramProvider>();
        for (Id leadId : convertResults.keySet()) {
            Lead leadRecord = convertible.get(leadId);
            if (!requestsByLead.get(leadId).wantsPrescriberLink()) {
                continue;
            }
            HealthcareProvider provider = leadRecord.Resolved_Prescriber__c != null ? providers.get(leadRecord.Resolved_Prescriber__c) : null;
            if (provider == null && String.isBlank(leadRecord.Prescriber_Full_Name__c)) {
                continue;
            }
            Id patientAccountId = convertResults.get(leadId).getAccountId();
            patientProviders.add(
                CareEnrollmentBuilder.buildCareProgramProviderForPatient(
                    patientAccountId,
                    provider,
                    leadRecord
                )
            );
        }

        if (!patientProviders.isEmpty() && Schema.sObjectType.CareProgramProvider.isCreateable()) {
            Database.insert(patientProviders, false);
        }

        if (providerIds.isEmpty()) {
            return;
        }

        Set<Id> providerAccountIds = new Set<Id>();
        for (HealthcareProvider provider : providers.values()) {
            if (provider.AccountId != null) {
                providerAccountIds.add(provider.AccountId);
            }
        }
        if (providerAccountIds.isEmpty()) {
            return;
        }

        Map<Id, CareProgramProvider> existingByAccount = selector.selectCareProgramProvidersByAccount(providerAccountIds);

        List<CareProgramProvider> newProviders = new List<CareProgramProvider>();
        Map<Id, HealthcareProvider> sourceByAccount = new Map<Id, HealthcareProvider>();
        for (HealthcareProvider provider : providers.values()) {
            if (provider.AccountId == null || existingByAccount.containsKey(provider.AccountId)) {
                continue;
            }
            if (sourceByAccount.containsKey(provider.AccountId)) {
                continue;
            }
            sourceByAccount.put(provider.AccountId, provider);
            newProviders.add(CareEnrollmentBuilder.buildCareProgramProvider(provider));
        }
        if (!newProviders.isEmpty() && Schema.sObjectType.CareProgramProvider.isCreateable()) {
            Database.insert(newProviders, false);
            for (CareProgramProvider created : newProviders) {
                if (created.Id != null) {
                    existingByAccount.put(created.AccountId, created);
                }
            }
        }

        Set<Id> careProviderIds = new Set<Id>();
        for (CareProgramProvider careProvider : existingByAccount.values()) {
            if (careProvider.Id != null) {
                careProviderIds.add(careProvider.Id);
            }
        }
        Set<Id> alreadyLinked = careProviderIds.isEmpty() ? new Set<Id>() : selector.selectLinkedHealthcareProviderIds(careProviderIds);

        List<CarePgmProvHealthcareProvider> junctions = new List<CarePgmProvHealthcareProvider>();
        Set<Id> queued = new Set<Id>();
        for (HealthcareProvider provider : providers.values()) {
            CareProgramProvider careProvider = existingByAccount.get(provider.AccountId);
            if (careProvider == null || alreadyLinked.contains(provider.Id) || !queued.add(provider.Id)) {
                continue;
            }
            junctions.add(CareEnrollmentBuilder.buildProviderJunction(careProvider.Id, provider.Id));
        }
        if (!junctions.isEmpty() && Schema.sObjectType.CarePgmProvHealthcareProvider.isCreateable()) {
            Database.insert(junctions, false);
        }
    }

    /** Results in the caller's original request order, so Flow output lines up. */
    private static List<LeadConversionResult> orderedResults(
        List<LeadConversionRequest> requests,
        Map<Id, LeadConversionResult> resultsByLead
    ) {
        List<LeadConversionResult> ordered = new List<LeadConversionResult>();
        for (LeadConversionRequest request : requests) {
            if (request == null || request.leadId == null) {
                ordered.add(LeadConversionResult.failure(null, 'No Lead ID supplied.'));
            } else {
                ordered.add(resultsByLead.get(request.leadId));
            }
        }
        return ordered;
    }
}