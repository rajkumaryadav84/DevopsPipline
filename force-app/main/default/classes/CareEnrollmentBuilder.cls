/**
 * Builds the LSC records that hang off a newly created patient. Pure
 * construction — the service owns ordering and DML.
 *
 * Every builder returns null when its source data is absent, so the service can
 * skip it without repeating the emptiness checks.
 */
public with sharing class CareEnrollmentBuilder {
    public static final String SOURCE_SYSTEM = 'Salesforce Lead Intake';
    public static final String ENROLLEE_INITIAL_STATUS = 'Pending Verification';//Updated from "New" to "Pending Verification" - Change date 11/08/2026 - VISHAL PANCHAL

    /**
     * Care Program Enrollee — the program-side record for the patient
     * (SCRUM-23). CareProgramId is required by the object, so callers must gate
     * on it first.
     *
     * @param memberPlanId optional; when supplied it becomes the primary plan
     */
    public static CareProgramEnrollee buildEnrollee(Lead leadRecord, Id accountId, Id memberPlanId) {
        CareProgramEnrollee enrollee = new CareProgramEnrollee(
            Name = enrolleeName(leadRecord),
            CareProgramId = leadRecord.Care_Program_Of_Interest__c,
            AccountId = accountId,
            LeadId = leadRecord.Id,
            Status = ENROLLEE_INITIAL_STATUS,
            SourceSystem = SOURCE_SYSTEM,
            SourceSystemIdentifier = leadRecord.Id,
            IsActive = true,
            Enrollment_Date__c = System.Today(),
            Confirmed_By__c = UserInfo.getUserId(),
            Confirmation_Date__c = System.now()
        );

        if (memberPlanId != null) {
            enrollee.PrimaryMemberPlanId = memberPlanId;
        }

        return enrollee;
    }

    /** "{First} {Last} - {Care Program}", trimmed to the field limit. */
    private static String enrolleeName(Lead leadRecord) {
        String patientName = String.isBlank(leadRecord.FirstName)
            ? leadRecord.LastName
            : leadRecord.FirstName + ' ' + leadRecord.LastName;

        String programName = leadRecord.Care_Program_Of_Interest__r == null
            ? null
            : leadRecord.Care_Program_Of_Interest__r.Name;

        String fullName = String.isBlank(programName) ? patientName : patientName + ' - ' + programName;

        return fullName.length() > 80 ? fullName.left(80) : fullName;
    }

    /**
     * MemberPlan from the Lead insurance block. MemberPlan has no fields for
     * plan type, insurer phone, employer, or policy holder, so those land in
     * Notes as labelled text rather than being dropped.
     */
    public static MemberPlan buildMemberPlan(Lead leadRecord, Id accountId) {
        if (String.isBlank(leadRecord.Insurance_Plan_Name__c)) {
            return null;
        }

        MemberPlan plan = new MemberPlan(
            Name = leadRecord.Insurance_Plan_Name__c.left(255),
            MemberId = accountId,
            MemberNumber = leadRecord.Policy_Number__c,
            GroupNumber = leadRecord.Group_Number__c,
            Status = 'Active',
            VerificationStatus = 'Not Checked',
            RelationshipToSubscriber = relationshipToSubscriber(leadRecord),
            SourceSystem = SOURCE_SYSTEM,
            SourceSystemIdentifier = leadRecord.Id,
            Notes = unmappedInsuranceNotes(leadRecord)
        );

        return plan;
    }

    /**
     * Blank policy holder, or a holder whose name matches the patient, means the
     * patient is the subscriber. Anything else we can only call "other" — the
     * Lead does not capture the actual relationship to the policy holder.
     */
    private static String relationshipToSubscriber(Lead leadRecord) {
        if (String.isBlank(leadRecord.Policy_Holder_Name__c)) {
            return 'Self';
        }

        String patientName = ((String.isBlank(leadRecord.FirstName) ? '' : leadRecord.FirstName + ' ') +
                leadRecord.LastName)
            .trim()
            .toLowerCase();

        return leadRecord.Policy_Holder_Name__c.trim().toLowerCase() == patientName ? 'Self' : 'Other Relationship';
    }

    /** Insurance detail MemberPlan has no home for, preserved as readable text. */
    private static String unmappedInsuranceNotes(Lead leadRecord) {
        List<String> lines = new List<String>();
        addNote(lines, 'Plan Type', leadRecord.Insurance_Plan_Type__c);
        addNote(lines, 'Insurer Phone', leadRecord.Insurance_Phone__c);
        addNote(lines, 'Employer', leadRecord.Insurance_Employer__c);
        addNote(lines, 'Policy Holder', leadRecord.Policy_Holder_Name__c);
        if (leadRecord.Policy_Holder_DOB__c != null) {
            lines.add('Policy Holder DOB: ' + String.valueOf(leadRecord.Policy_Holder_DOB__c));
        }
        return lines.isEmpty() ? null : String.join(lines, '\n');
    }

    private static void addNote(List<String> lines, String label, String value) {
        if (String.isNotBlank(value)) {
            lines.add(label + ': ' + value);
        }
    }

    /** Preferred language as an LSC PersonLanguage record rather than a custom field. */
    public static PersonLanguage buildPersonLanguage(Lead leadRecord, Id accountId) {
        if (String.isBlank(leadRecord.Preferred_Language_c__c)) {
            return null;
        }

        // Rank 1 marks the primary language; the object has no dedicated
        // primary flag.
        return new PersonLanguage(
            IndividualId = accountId,
            Language = leadRecord.Preferred_Language_c__c,
            Rank = 1,
            SourceSystemName = SOURCE_SYSTEM,
            SourceSystemIdentifier = leadRecord.Id
        );
    }

    /** Referral diagnosis as an LSC HealthCondition rather than free text on the patient. */
    public static HealthCondition buildHealthCondition(Lead leadRecord, Id accountId) {
        if (String.isBlank(leadRecord.Diagnosis__c)) {
            return null;
        }

        return new HealthCondition(
            PatientId = accountId,
            ProblemName = leadRecord.Diagnosis__c.left(255),
            ProblemDescription = leadRecord.Diagnosis__c,
            ConditionStatus = 'Active',
            SourceSystem = SOURCE_SYSTEM,
            SourceSystemIdentifier = leadRecord.Id
        );
    }

    /**
     * Caregiver becomes their own Person Account. A caregiver is a person, not
     * an attribute of the patient, and a Contact with no Account is private —
     * Salesforce refuses to relate a private contact to an account, so the
     * relationship has to hang off a real person record.
     */
    public static Account buildCaregiverAccount(Lead leadRecord, Id personAccountRecordTypeId) {
        if (String.isBlank(leadRecord.Caregiver_LastName__c)) {
            return null;
        }

        return new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = leadRecord.Caregiver_FirstName__c,
            LastName = leadRecord.Caregiver_LastName__c,
            PersonMobilePhone = leadRecord.Caregiver_Phone__c
        );
    }

    private static Id cachedPersonAccountRecordTypeId;

    /**
     * Record type Id for Person Accounts, cached per transaction.
     * Schema.RecordTypeInfo exposes no person-type flag, so this comes from
     * RecordType where IsPersonType is set.
     */
    public static Id personAccountRecordTypeId() {
        if (cachedPersonAccountRecordTypeId != null) {
            return cachedPersonAccountRecordTypeId;
        }

        List<RecordType> personTypes = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Account' AND IsPersonType = TRUE AND IsActive = TRUE
            ORDER BY DeveloperName
            LIMIT 1
        ];
        if (personTypes.isEmpty()) {
            throw new LeadConversionException('No active Person Account record type exists in this org.');
        }

        cachedPersonAccountRecordTypeId = personTypes[0].Id;
        return cachedPersonAccountRecordTypeId;
    }

    /** Links the caregiver Contact to the patient with the referral's relationship as the role. */
    public static AccountContactRelation buildCaregiverRelation(Lead leadRecord, Id accountId, Id caregiverContactId) {
        return new AccountContactRelation(
            AccountId = accountId,
            ContactId = caregiverContactId,
            Roles = leadRecord.Caregiver_Relationship__c,
            IsActive = true
        );
    }

    /**
     * Program-level provider record for the referring prescriber's Account.
     * CareProgramProvider keys on an Account, which is why the caller resolves
     * HealthcareProvider.AccountId first.
     */
    public static CareProgramProvider buildCareProgramProvider(HealthcareProvider provider) {
        String providerName = provider.Account != null && String.isNotBlank(provider.Account.Name)
            ? provider.Account.Name
            : provider.Name;

        return new CareProgramProvider(
            Name = providerName == null ? 'Referring Provider' : providerName.left(80),
            AccountId = provider.AccountId,
            Status = 'Active',
            SourceSystem = SOURCE_SYSTEM,
            SourceSystemIdentifier = provider.Id
        );
    }

    public static CareProgramProvider buildCareProgramProviderForPatient(
        Id patientAccountId,
        HealthcareProvider provider,
        Lead leadRecord
    ) {
        String nameStr = '';
        if (provider != null) {
            nameStr = provider.Name;
        } else if (leadRecord != null && String.isNotBlank(leadRecord.Prescriber_Full_Name__c)) {
            nameStr = leadRecord.Prescriber_Full_Name__c;
        }

        if (String.isBlank(nameStr)) {
            nameStr = 'Referring Prescriber';
        }

        String providerNameVal = nameStr;
        String providerNpiVal  = leadRecord != null ? leadRecord.Prescriber_NPI__c : null;
        String providerTypeVal = provider != null ? provider.ProviderType : null;

        return new CareProgramProvider(
            Name                 = nameStr.left(80),
            Provider_Name__c     = providerNameVal,
            Provider_NPI__c      = providerNpiVal,
            Provider_Type__c     = providerTypeVal,
            AccountId            = patientAccountId,
            Status               = 'Active',
            SourceSystem         = SOURCE_SYSTEM,
            SourceSystemIdentifier = leadRecord != null ? leadRecord.Id : patientAccountId
        );
    }

    /** Junction tying the HealthcareProvider to its CareProgramProvider. */
    public static CarePgmProvHealthcareProvider buildProviderJunction(Id careProgramProviderId, Id healthcareProviderId) {
        return new CarePgmProvHealthcareProvider(
            Name = 'Referring Prescriber',
            CareProgramProviderId = careProgramProviderId,
            HealthcareProviderId = healthcareProviderId,
            IsPrimaryProvider = true,
            SourceSystem = SOURCE_SYSTEM,
            SourceSystemIdentifier = healthcareProviderId
        );
    }

    /**
     * Re-points consent to the patient. ConsentGiverId is a single polymorphic
     * lookup, so the Lead link is replaced rather than duplicated — one consent
     * record stays the single source of truth. Lead traceability survives via
     * CareProgramEnrollee.LeadId and Lead.ConvertedAccountId.
     */
    public static List<AuthorizationFormConsent> repointConsents(
        List<AuthorizationFormConsent> consents,
        Id accountId
    ) {
        List<AuthorizationFormConsent> updates = new List<AuthorizationFormConsent>();
        if (consents == null) {
            return updates;
        }

        for (AuthorizationFormConsent consent : consents) {
            updates.add(new AuthorizationFormConsent(Id = consent.Id, ConsentGiverId = accountId));
        }
        return updates;
    }

    // Files are not handled here: Convert Lead moves ContentDocumentLinks from
    // the Lead to the new Account itself, verified by
    // LeadConversionServiceTest.convertMovesLeadFilesToPatient. Re-linking them
    // would only create duplicates.
}