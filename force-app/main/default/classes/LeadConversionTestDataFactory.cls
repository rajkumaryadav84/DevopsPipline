/**
 * Test data for Lead to Patient conversion.
 *
 * Leads are built to clear the org's qualification validation rules
 * (Qual_Patient_Required, Qual_Prescriber_Required, Qual_Clinical_Required,
 * Qual_Insurance_Required, Qual_Insurance_Details_Required,
 * Prescriber_Required_For_HCP_Referral, Prescriber_NPI_Format), because those
 * fire the moment a Lead reaches Qualified.
 */
@IsTest
public class LeadConversionTestDataFactory {
    public static final String HCP_REFERRAL_RT = 'HCP_Referral';

    public static CareProgram createCareProgram() {
        List<CareProgram> existing = [SELECT Id, Name FROM CareProgram LIMIT 1];
        return existing.isEmpty() ? null : existing[0];
    }

    public static Account createProviderAccount() {
        Account providerAccount = new Account(Name = 'Test Provider Practice ' + getUniqueId());
        insert providerAccount;
        return providerAccount;
    }

    public static HealthcareProvider createHealthcareProvider(Id providerAccountId) {
        String uid = getUniqueId();
        HealthcareProvider hp = new HealthcareProvider(
            Name = 'Dr Test Prescriber ' + uid,
            AccountId = providerAccountId,
            Status = 'Active'
        );
        insert hp;
        return hp;
    }

    public static Database.DMLOptions getDmlOptions() {
        Database.DMLOptions dmlOpt = new Database.DMLOptions();
        dmlOpt.DuplicateRuleHeader.allowSave = true;
        dmlOpt.DuplicateRuleHeader.runAsCurrentUser = true;
        return dmlOpt;
    }

    /** Fully populated Lead sitting at Qualified with all three consents Agreed. */
    public static Lead createQualifiedLead(Id careProgramId, Id resolvedPrescriberId) {
        HealthcareProvider hp = resolvedPrescriberId != null ? [SELECT Name FROM HealthcareProvider WHERE Id = :resolvedPrescriberId] : null;
        String prescriberName = hp != null ? hp.Name : 'Dr Test Prescriber';

        Lead newLead = buildLead(careProgramId, resolvedPrescriberId);
        newLead.Prescriber_Full_Name__c = prescriberName;
        Database.insert(newLead, getDmlOptions());

        // Lead_Intake_flow stamps Company and Intake Status on create; move the
        // intake status in an update step so gate/conversion tests match flow execution.
        Lead qualified = new Lead(
            Id = newLead.Id,
            Intake_Status__c = 'Qualified',
            Consent_HIPAA_Status__c = 'Agreed',
            Consent_DataProcessing_Status__c = 'Agreed',
            Consent_CareProgram_Status__c = 'Agreed',
            Prescriber_Full_Name__c = prescriberName,
            Resolved_Prescriber__c = resolvedPrescriberId
        );
        Database.update(qualified, getDmlOptions());

        return [
            SELECT Id, FirstName, LastName, Company, Email, Phone, MobilePhone, Patient_Alternate_Phone__c, Street, City, State, PostalCode, Country, Intake_Status__c, Resolved_Prescriber__c, Care_Program_Of_Interest__c, Prescriber_Full_Name__c, Prescriber_NPI__c
            FROM Lead
            WHERE Id = :newLead.Id
        ];
    }

    /** Lead shaped for conversion but left short of the gate. */
    public static Lead createUnqualifiedLead(Id careProgramId) {
        return createUnqualifiedLead(careProgramId, null);
    }

    public static Lead createUnqualifiedLead(Id careProgramId, Id resolvedPrescriberId) {
        Lead newLead = buildLead(careProgramId, resolvedPrescriberId);
        Database.insert(newLead, getDmlOptions());
        return newLead;
    }

    private static Integer counter = 0;

    private static String getUniqueId() {
        counter++;
        return String.valueOf(counter) + '_' + String.valueOf(System.currentTimeMillis());
    }

    public static Lead buildLead(Id careProgramId, Id resolvedPrescriberId) {
        Id recordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('HCP_Referral').getRecordTypeId();
        String uid = getUniqueId();
        String phoneStr = String.valueOf(Math.abs(Crypto.getRandomInteger())).left(10).leftPad(10, '0');

        return new Lead(
            RecordTypeId = recordTypeId,
            FirstName = 'Pat' + uid,
            LastName = 'Tester' + uid,
            Company = 'Patient Referral',
            LeadSource = 'HCP Referral',
            Email = 'pat' + uid + '@example.com',
            Phone = phoneStr,
            MobilePhone = phoneStr,
            Street = uid + ' Test Street',
            City = 'Testville',
            State = 'CA',
            PostalCode = '90001',
            Country = 'USA',
            Patient_DOB__c = Date.newInstance(1985, 3, 14),
            Patient_Gender__c = 'Female',
            Patient_Alternate_Phone__c = '5551230002',
            Preferred_Language_c__c = 'Spanish',
            Shipping_Street__c = '2 Ship Lane',
            Shipping_City__c = 'Shiptown',
            Shipping_State__c = 'CA',
            Shipping_Zip__c = '90002',
            Shipping_Country__c = 'USA',
            Shipping_Same_As_Primary__c = false,
            Caregiver_FirstName__c = 'Casey',
            Caregiver_LastName__c = 'Giver',
            Caregiver_Phone__c = '5551230003',
            Caregiver_Relationship__c = 'Spouse',
            Insurance_Plan__c = 'Commercial',
            Insurance_Plan_Type__c = 'Commercial',
            Insurance_Plan_Name__c = 'Test Health Plan',
            Insurance_Phone__c = '5551230004',
            Insurance_Employer__c = 'Test Employer',
            Policy_Number__c = 'POL-12345',
            Group_Number__c = 'GRP-67890',
            Policy_Holder_Name__c = 'Pat' + uid + ' Tester' + uid,
            Policy_Holder_DOB__c = Date.newInstance(1985, 3, 14),
            Diagnosis__c = 'Test diagnosis for conversion coverage',
            Prescription_Information__c = 'Test prescription details',
            Prescriber_Full_Name__c = 'Dr Test Prescriber',
            Prescriber_NPI__c = '1234567890',
            Care_Program_Of_Interest__c = careProgramId,
            Resolved_Prescriber__c = resolvedPrescriberId
        );
    }

    /**
     * Consent records pointing at the Lead, as the intake process leaves them.
     * AuthorizationFormConsent requires a form text parent, so the form and its
     * text are created first.
     */
    public static List<AuthorizationFormConsent> createLeadConsents(Id leadId) {
        AuthorizationForm form = new AuthorizationForm(Name = 'HIPAA Authorization Consent Form');
        insert form;

        // IsActive must stay false: activating an AuthorizationFormText in this
        // org raises an uncatchable platform error that kills the whole
        // transaction. Consent records attach to an inactive text just fine,
        // which is all this test data needs.
        AuthorizationFormText formText = new AuthorizationFormText(
            Name = 'HIPAA Authorization Consent Form v1',
            AuthorizationFormId = form.Id,
            SummaryAuthFormText = 'Test consent text',
            IsActive = false,
            IsReadOnly = false
        );
        insert formText;

        List<AuthorizationFormConsent> consents = new List<AuthorizationFormConsent>{
            new AuthorizationFormConsent(
                Name = 'HIPAA Consent',
                ConsentGiverId = leadId,
                AuthorizationFormTextId = formText.Id,
                Status = 'Signed',
                ConsentCapturedDateTime = System.now()
            ),
            new AuthorizationFormConsent(
                Name = 'Data Processing Consent',
                ConsentGiverId = leadId,
                AuthorizationFormTextId = formText.Id,
                Status = 'Signed',
                ConsentCapturedDateTime = System.now()
            )
        };
        insert consents;
        return consents;
    }

    public static LeadConversionRequest request(Id leadId) {
        LeadConversionRequest req = new LeadConversionRequest(leadId);
        req.createMemberPlan = true;
        req.linkPrescriber = true;
        return req;
    }
}