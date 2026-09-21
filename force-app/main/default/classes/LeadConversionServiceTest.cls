@IsTest(SeeAllData=true)
private class LeadConversionServiceTest {
    private static CareProgram program() {
        return [SELECT Id, Name FROM CareProgram LIMIT 1];
    }

    private static HealthcareProvider provider() {
        return [SELECT Id, AccountId FROM HealthcareProvider WHERE AccountId != NULL LIMIT 1];
    }

    @IsTest
    static void convertCreatesPersonAccountWithPatientDemographics() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);
        System.assertNotEquals(null, result.accountId, 'A Person Account should have been created');

        Account patient = [
            SELECT
                IsPersonAccount,
                PersonBirthdate,
                PersonGender,
                PersonEmail,
                PersonMobilePhone,
                PersonOtherPhone,
                PersonMailingStreet,
                PersonMailingPostalCode,
                PersonOtherStreet,
                Phone
            FROM Account
            WHERE Id = :result.accountId
        ];

        System.assertEquals(true, patient.IsPersonAccount, 'Blank Company must produce a Person Account');
        System.assertEquals(Date.newInstance(1985, 3, 14), patient.PersonBirthdate, 'DOB should map to PersonBirthdate');
        System.assertEquals('Female', patient.PersonGender, 'Gender should map to PersonGender');
        System.assertEquals(qualified.Email, patient.PersonEmail, 'Email should map to PersonEmail');
        System.assertEquals(qualified.MobilePhone, patient.PersonMobilePhone, 'Mobile should map to PersonMobilePhone');
        System.assertEquals(qualified.Patient_Alternate_Phone__c, patient.PersonOtherPhone, 'Alternate phone should map to PersonOtherPhone');
        System.assertEquals(qualified.Street, patient.PersonMailingStreet, 'Primary address should map to mailing');
        System.assertEquals('2 Ship Lane', patient.PersonOtherStreet, 'Shipping address should map to other');
    }

    @IsTest
    static void convertCreatesEnrolleeLinkedToProgramLeadAndPlan() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);

        // The enrollee is inserted by CareEnrolleeQueueable, which runs at
        // Test.stopTest().
        CareProgramEnrollee enrollee = [
            SELECT Name, Status, AccountId, LeadId, CareProgramId, PrimaryMemberPlanId, IsActive, SourceSystem
            FROM CareProgramEnrollee
            WHERE LeadId = :qualified.Id
        ];

        System.assertEquals('New', enrollee.Status, 'Enrollee starts at the beginning of the LSC pipeline');
        System.assertEquals(result.accountId, enrollee.AccountId, 'Enrollee should point at the Person Account');
        System.assertEquals(program().Id, enrollee.CareProgramId, 'Enrollee should carry the Care Program of interest');
        System.assertEquals(true, enrollee.IsActive, 'Enrollee should be active');
        System.assertEquals('Salesforce Lead Intake', enrollee.SourceSystem, 'Source system should be stamped');
        System.assertEquals(result.memberPlanId, enrollee.PrimaryMemberPlanId, 'MemberPlan should be the primary plan');
        System.assert(enrollee.Name.contains(qualified.FirstName), 'Enrollee name should carry the patient name: ' + enrollee.Name);
    }

    @IsTest
    static void convertCreatesMemberPlanFromInsuranceFields() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        MemberPlan plan = [
            SELECT Name, MemberId, MemberNumber, GroupNumber, Status, RelationshipToSubscriber, Notes
            FROM MemberPlan
            WHERE Id = :result.memberPlanId
        ];

        System.assertEquals('Test Health Plan', plan.Name, 'Plan name should come from the Lead');
        System.assertEquals(result.accountId, plan.MemberId, 'Plan member should be the patient');
        System.assertEquals('POL-12345', plan.MemberNumber, 'Policy number should map to MemberNumber');
        System.assertEquals('GRP-67890', plan.GroupNumber, 'Group number should map to GroupNumber');
        System.assertEquals(
            'Self',
            plan.RelationshipToSubscriber,
            'Policy holder matching the patient means the patient is the subscriber'
        );
        System.assert(plan.Notes.contains('Test Employer'), 'Unmapped insurance detail should survive in Notes');
        System.assert(plan.Notes.contains('Plan Type'), 'Plan type has no MemberPlan field and belongs in Notes');
    }

    @IsTest
    static void convertCreatesLanguageDiagnosisAndCaregiver() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        List<PersonLanguage> languages = [
            SELECT Language, Rank
            FROM PersonLanguage
            WHERE IndividualId = :result.accountId
        ];
        System.assertEquals(1, languages.size(), 'Preferred language should become a PersonLanguage record');
        System.assertEquals('Spanish', languages[0].Language, 'Language should carry over');

        List<HealthCondition> conditions = [
            SELECT ProblemName, ConditionStatus
            FROM HealthCondition
            WHERE PatientId = :result.accountId
        ];
        System.assertEquals(1, conditions.size(), 'Diagnosis should become a HealthCondition');
        System.assertEquals('Active', conditions[0].ConditionStatus, 'A referral diagnosis starts active');

        List<AccountContactRelation> relations = [
            SELECT Roles, ContactId, IsActive
            FROM AccountContactRelation
            WHERE AccountId = :result.accountId AND Roles = 'Spouse'
        ];
        System.assertEquals(1, relations.size(), 'Caregiver should be related to the patient');

        Contact caregiver = [
            SELECT FirstName, LastName, IsPersonAccount
            FROM Contact
            WHERE Id = :relations[0].ContactId
        ];
        System.assertEquals('Casey', caregiver.FirstName, 'Caregiver first name should carry over');
        System.assertEquals('Giver', caregiver.LastName, 'Caregiver last name should carry over');
        System.assertEquals(true, caregiver.IsPersonAccount, 'Caregiver is a person in their own right');
    }

    @IsTest
    static void convertLinksResolvedPrescriberToCareProgramProvider() {
        HealthcareProvider prescriber = LeadConversionTestDataFactory.createHealthcareProvider(LeadConversionTestDataFactory.createProviderAccount().Id);
        delete [SELECT Id FROM CarePgmProvHealthcareProvider WHERE HealthcareProviderId = :prescriber.Id];
        delete [SELECT Id FROM CareProgramProvider WHERE AccountId = :prescriber.AccountId];

        CareProgramProvider cpp = new CareProgramProvider(
            Name = 'Test Provider',
            AccountId = prescriber.AccountId,
            Status = 'Active'
        );
        insert cpp;

        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, prescriber.Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);

        List<CarePgmProvHealthcareProvider> junctions = [
            SELECT CareProgramProviderId, IsPrimaryProvider
            FROM CarePgmProvHealthcareProvider
            WHERE HealthcareProviderId = :prescriber.Id
        ];
        System.assertEquals(1, junctions.size(), 'Prescriber should be joined to a CareProgramProvider');
        System.assertEquals(true, junctions[0].IsPrimaryProvider, 'Referring prescriber is the primary provider');

        CareProgramProvider careProvider = [
            SELECT AccountId, Status
            FROM CareProgramProvider
            WHERE Id = :junctions[0].CareProgramProviderId
        ];
        System.assertEquals(
            prescriber.AccountId,
            careProvider.AccountId,
            'CareProgramProvider keys on the provider Account'
        );
    }

    @IsTest
    static void convertReusesExistingCareProgramProvider() {
        HealthcareProvider prescriber = provider();
        delete [SELECT Id FROM CarePgmProvHealthcareProvider WHERE HealthcareProviderId = :prescriber.Id];
        delete [SELECT Id FROM CareProgramProvider WHERE AccountId = :prescriber.AccountId];
        CareProgramProvider existing = new CareProgramProvider(
            Name = 'Existing Provider',
            AccountId = prescriber.AccountId,
            Status = 'Active'
        );
        insert existing;

        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, prescriber.Id);

        Test.startTest();
        LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        List<CareProgramProvider> providers = [
            SELECT Id
            FROM CareProgramProvider
            WHERE AccountId = :prescriber.AccountId
        ];
        System.assertEquals(1, providers.size(), 'An existing provider row should be reused, not duplicated');

        List<CarePgmProvHealthcareProvider> junctions = [
            SELECT CareProgramProviderId
            FROM CarePgmProvHealthcareProvider
            WHERE HealthcareProviderId = :prescriber.Id
        ];
        System.assertEquals(1, junctions.size(), 'The prescriber should be linked once');
        System.assertEquals(existing.Id, junctions[0].CareProgramProviderId, 'Link should reuse the existing provider');
    }

    @IsTest
    static void convertRepointsConsentFromLeadToPatient() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);
        List<AuthorizationFormConsent> consents = LeadConversionTestDataFactory.createLeadConsents(qualified.Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);

        List<AuthorizationFormConsent> stillOnLead = [
            SELECT Id
            FROM AuthorizationFormConsent
            WHERE ConsentGiverId = :qualified.Id
        ];
        System.assertEquals(0, stillOnLead.size(), 'No consent should be left pointing at the converted Lead');

        List<AuthorizationFormConsent> onPatient = [
            SELECT Id
            FROM AuthorizationFormConsent
            WHERE ConsentGiverId = :result.accountId
        ];
        System.assertEquals(consents.size(), onPatient.size(), 'Every consent should now point at the patient');
    }

    @IsTest
    static void convertSkipsOptionalRecordsWhenSourceDataAbsent() {
        Lead sparse = LeadConversionTestDataFactory.buildLead(program().Id, null);
        sparse.Caregiver_FirstName__c = null;
        sparse.Caregiver_LastName__c = null;
        sparse.Caregiver_Phone__c = null;
        sparse.Caregiver_Relationship__c = null;
        sparse.Preferred_Language_c__c = null;
        sparse.Insurance_Plan__c = 'Uninsured';
        sparse.Insurance_Plan_Type__c = 'Uninsured';
        sparse.Insurance_Plan_Name__c = null;
        sparse.Policy_Number__c = null;
        sparse.Policy_Holder_Name__c = null;
        Database.insert(sparse, LeadConversionTestDataFactory.getDmlOptions());

        Database.update(
            new Lead(
                Id = sparse.Id,
                Intake_Status__c = 'Qualified',
                Consent_HIPAA_Status__c = 'Agreed',
                Consent_DataProcessing_Status__c = 'Agreed',
                Consent_CareProgram_Status__c = 'Agreed'
            ),
            LeadConversionTestDataFactory.getDmlOptions()
        );

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(sparse.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Missing optional data must not block conversion: ' + result.errorMessage);
        System.assertEquals(null, result.memberPlanId, 'No insurance data means no MemberPlan');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId = :sparse.Id],
            'The enrollee is always created, even with no optional data'
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM PersonLanguage WHERE IndividualId = :result.accountId],
            'No language means no PersonLanguage record'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM AccountContactRelation WHERE AccountId = :result.accountId AND Roles != NULL],
            'No caregiver means no relationship record'
        );

        CareProgramEnrollee enrollee = [SELECT PrimaryMemberPlanId FROM CareProgramEnrollee WHERE LeadId = :sparse.Id];
        System.assertEquals(null, enrollee.PrimaryMemberPlanId, 'Enrollee should have no primary plan');
    }

    @IsTest
    static void convertCopiesMailingToOtherWhenShippingSameAsPrimary() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);
        update new Lead(Id = qualified.Id, Shipping_Same_As_Primary__c = true);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);

        Account patient = [
            SELECT PersonOtherStreet, PersonOtherCity, PersonOtherPostalCode
            FROM Account
            WHERE Id = :result.accountId
        ];

        // The shipping fields still hold "2 Ship Lane", but the flag says the
        // shipping address is the primary one, so the primary must win.
        System.assertEquals(qualified.Street, patient.PersonOtherStreet, 'Same-as-primary should copy the mailing street');
        System.assertEquals('Testville', patient.PersonOtherCity, 'Same-as-primary should copy the mailing city');
        System.assertEquals('90001', patient.PersonOtherPostalCode, 'Same-as-primary should copy the mailing postcode');
    }

    /**
     * Documents platform behaviour the conversion relies on: Convert Lead moves
     * file links to the Account by itself, so the service does not touch them.
     */
    @IsTest
    static void convertMovesLeadFilesToPatient() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        ContentVersion version = new ContentVersion(
            Title = 'Referral Form',
            PathOnClient = 'referral.txt',
            VersionData = Blob.valueOf('referral document')
        );
        insert version;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = qualified.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);

        List<ContentDocumentLink> patientLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.accountId
        ];
        System.assertEquals(1, patientLinks.size(), 'Convert Lead should leave exactly one link on the patient');
        System.assertEquals(contentDocumentId, patientLinks[0].ContentDocumentId, 'The same document should be linked');

        System.assertEquals(
            0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :qualified.Id],
            'Convert Lead moves the link rather than copying it, so the Lead keeps none'
        );
    }

    @IsTest
    static void convertRespectsOptOutFlags() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        LeadConversionRequest request = new LeadConversionRequest(qualified.Id);
        request.createMemberPlan = false;
        request.linkPrescriber = false;

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(request);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'Conversion should succeed: ' + result.errorMessage);
        System.assertEquals(null, result.memberPlanId, 'Opting out of insurance should skip the MemberPlan');
        System.assertEquals(
            0,
            [SELECT COUNT() FROM CareProgramProvider WHERE AccountId = :result.accountId],
            'Opting out of the prescriber link should create no provider for patient'
        );
    }

    @IsTest
    static void convertBlocksLeadThatFailsTheGate() {
        Lead unqualified = LeadConversionTestDataFactory.createUnqualifiedLead(program().Id, provider().Id);

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(unqualified.Id));
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'An unqualified Lead must not convert');
        System.assert(result.errorMessage.contains('Intake Status'), 'Expected the gate message: ' + result.errorMessage);

        Lead after = [SELECT IsConverted FROM Lead WHERE Id = :unqualified.Id];
        System.assertEquals(false, after.IsConverted, 'The Lead should be untouched');
        System.assertEquals(0, [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId = :unqualified.Id], 'No enrollee should exist');
    }

    @IsTest
    static void convertBlocksAlreadyConvertedLead() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);
        LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));

        Test.startTest();
        LeadConversionResult second = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(false, second.isSuccess, 'A converted Lead must not convert twice');
        System.assert(second.errorMessage.contains('already been converted'), 'Unexpected: ' + second.errorMessage);
        System.assertEquals(1, [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId = :qualified.Id], 'Only one enrollee should exist');
    }

    @IsTest
    static void convertHandlesMixedBatchOfValidAndBlockedLeads() {
        CareProgram careProgram = program();
        HealthcareProvider prescriber = provider();

        Lead good = LeadConversionTestDataFactory.createQualifiedLead(careProgram.Id, prescriber.Id);
        Lead blocked = LeadConversionTestDataFactory.createUnqualifiedLead(careProgram.Id, prescriber.Id);

        Test.startTest();
        List<LeadConversionResult> results = LeadConversionService.convert(
            new List<LeadConversionRequest>{
                LeadConversionTestDataFactory.request(good.Id),
                LeadConversionTestDataFactory.request(blocked.Id)
            }
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'One result per request, in request order');
        System.assertEquals(good.Id, results[0].leadId, 'Results should keep request order');
        System.assertEquals(true, results[0].isSuccess, 'The qualified Lead should convert: ' + results[0].errorMessage);
        System.assertEquals(false, results[1].isSuccess, 'The blocked Lead should not convert');
        System.assertEquals(1, [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId IN (:good.Id, :blocked.Id)], 'Only the qualified Lead produces an enrollee');
    }

    @IsTest
    static void convertReturnsFailureForNullRequestEntries() {
        Test.startTest();
        List<LeadConversionResult> results = LeadConversionService.convert(
            new List<LeadConversionRequest>{ new LeadConversionRequest() }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'A malformed request still gets a result');
        System.assertEquals(false, results[0].isSuccess, 'A request with no Lead Id cannot succeed');
        System.assert(results[0].errorMessage.contains('No Lead ID'), 'Unexpected: ' + results[0].errorMessage);
    }

    /**
     * Returns the real Lead but with an insurance plan name far longer than
     * MemberPlan.Name allows, so the gate passes and the MemberPlan
     * insert fails after Convert Lead has already run — the exact window the
     * savepoint exists to protect.
     */
    private class BrokenInsuranceSelector extends LeadConvertSelector {
        public override Map<Id, Lead> selectLeadsForConversion(Set<Id> leadIds) {
            Map<Id, Lead> leads = super.selectLeadsForConversion(leadIds);
            for (Lead leadRecord : leads.values()) {
                leadRecord.Insurance_Plan_Name__c = 'Test Plan';
                leadRecord.Policy_Number__c = 'X'.repeat(500);
            }
            return leads;
        }
    }

    /** Care Program Id that points nowhere, to fail the asynchronous enrollee insert. */
    private class BrokenProgramSelector extends LeadConvertSelector {
        public override Map<Id, Lead> selectLeadsForConversion(Set<Id> leadIds) {
            Map<Id, Lead> leads = super.selectLeadsForConversion(leadIds);
            for (Lead leadRecord : leads.values()) {
                // 3-character key prefix plus 12 characters makes a valid
                // 15-character Id that matches no real record.
                leadRecord.Care_Program_Of_Interest__c = CareProgram.SObjectType.getDescribe().getKeyPrefix() +
                    '000000000001';
            }
            return leads;
        }
    }

    @IsTest
    static void enrolleeFailureAfterConversionRaisesATaskOnThePatient() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);
        LeadConversionService.selector = new BrokenProgramSelector();

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        // The conversion itself already committed, so it must not be reported
        // as a failure — but a human has to be told the enrollment did not land.
        System.assertEquals(true, result.isSuccess, 'The conversion itself succeeded: ' + result.errorMessage);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId = :qualified.Id],
            'The enrollee insert was expected to fail'
        );

        List<Task> alerts = [SELECT Subject, Priority FROM Task WHERE WhatId = :result.accountId];
        System.assertEquals(1, alerts.size(), 'A failed enrollment should raise a task on the patient');
        System.assert(
            alerts[0].Subject.contains('enrollment failed'),
            'Unexpected task subject: ' + alerts[0].Subject
        );
    }

    @IsTest
    static void convertRollsBackEverythingWhenADownstreamInsertFails() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);
        LeadConversionService.selector = new BrokenInsuranceSelector();

        Test.startTest();
        LeadConversionResult result = LeadConversionService.convert(LeadConversionTestDataFactory.request(qualified.Id));
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'A downstream failure must fail the conversion');
        System.assert(result.errorMessage.contains('rolled back'), 'Expected a rollback message: ' + result.errorMessage);

        Lead after = [SELECT IsConverted, Company FROM Lead WHERE Id = :qualified.Id];
        System.assertEquals(false, after.IsConverted, 'The Lead must not be left converted');
        System.assertNotEquals(null, after.Company, 'The blanked Company must be restored by the rollback');
        System.assertEquals(0, [SELECT COUNT() FROM MemberPlan WHERE MemberId IN (SELECT Id FROM Account WHERE FirstName = :qualified.FirstName)], 'No insurance plan should survive the rollback');
        System.assertEquals(0, [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId = :qualified.Id], 'No enrollee should be created');
    }
}