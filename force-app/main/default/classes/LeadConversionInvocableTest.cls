@IsTest(SeeAllData=true)
private class LeadConversionInvocableTest {
    private static CareProgram program() {
        return [SELECT Id, Name FROM CareProgram LIMIT 1];
    }

    private static HealthcareProvider provider() {
        return [SELECT Id, AccountId FROM HealthcareProvider WHERE AccountId != NULL LIMIT 1];
    }

    @IsTest
    static void invocableConvertsAndReturnsPatientIds() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        Test.startTest();
        List<LeadConversionResult> results = LeadConversionInvocable.convertLeads(
            new List<LeadConversionRequest>{ LeadConversionTestDataFactory.request(qualified.Id) }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result per request');
        System.assertEquals(true, results[0].isSuccess, 'Conversion should succeed: ' + results[0].errorMessage);
        System.assertNotEquals(null, results[0].accountId, 'Flow needs the Account Id to link to the patient');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM CareProgramEnrollee WHERE LeadId = :qualified.Id],
            'The enrollee is created by the queueable, which runs at Test.stopTest()'
        );
    }

    @IsTest
    static void gateReportsConvertibleLeadWithScreenDetail() {
        Lead qualified = LeadConversionTestDataFactory.createQualifiedLead(program().Id, provider().Id);

        LeadConversionGateInvocable.GateRequest request = new LeadConversionGateInvocable.GateRequest();
        request.leadId = qualified.Id;

        Test.startTest();
        List<LeadConversionGateInvocable.GateResult> results = LeadConversionGateInvocable.check(
            new List<LeadConversionGateInvocable.GateRequest>{ request }
        );
        Test.stopTest();

        LeadConversionGateInvocable.GateResult gate = results[0];
        System.assertEquals(true, gate.canConvert, 'A qualified Lead should pass: ' + gate.blockingReasons);
        System.assertEquals(null, gate.blockingReasons, 'A passing gate has no reasons');
        System.assertEquals(true, gate.hasInsuranceData, 'The Lead carries insurance data');
        System.assertEquals(true, gate.hasPrescriber, 'The Lead has a resolved prescriber');
        System.assertEquals(qualified.FirstName + ' ' + qualified.LastName, gate.patientName, 'Screen shows the patient name');
        System.assertEquals(program().Name, gate.careProgramName, 'Screen shows the care program');
    }

    @IsTest
    static void gateReportsBlockingReasonsForUnqualifiedLead() {
        Lead unqualified = LeadConversionTestDataFactory.createUnqualifiedLead(program().Id, provider().Id);

        LeadConversionGateInvocable.GateRequest request = new LeadConversionGateInvocable.GateRequest();
        request.leadId = unqualified.Id;

        Test.startTest();
        List<LeadConversionGateInvocable.GateResult> results = LeadConversionGateInvocable.check(
            new List<LeadConversionGateInvocable.GateRequest>{ request }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].canConvert, 'An unqualified Lead should be blocked');
        System.assertNotEquals(null, results[0].blockingReasons, 'The screen needs a reason to show');
        System.assert(
            results[0].blockingReasons.contains('Intake Status'),
            'Expected the intake status reason: ' + results[0].blockingReasons
        );
    }

    @IsTest
    static void gateHandlesMissingLeadWithoutFailing() {
        LeadConversionGateInvocable.GateRequest request = new LeadConversionGateInvocable.GateRequest();
        request.leadId = null;

        Test.startTest();
        List<LeadConversionGateInvocable.GateResult> results = LeadConversionGateInvocable.check(
            new List<LeadConversionGateInvocable.GateRequest>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'A result is still returned');
        System.assertEquals(false, results[0].canConvert, 'No Lead means no conversion');
        System.assert(results[0].blockingReasons.contains('not found'), 'Unexpected: ' + results[0].blockingReasons);
    }
}