/**
 * Gate rules in isolation. Leads are built in memory via JSON so that
 * All_Required_Consents_Complete__c — a formula, and therefore not writable
 * through the constructor — can be set directly. No DML, no SOQL.
 */
@IsTest
private class LeadConversionValidatorTest {
    @IsTest
    static void validateReturnsNoProblemsForQualifiedLead() {
        Lead qualified = buildLead(false, 'Qualified', true, true, true);

        System.assertEquals(
            new List<String>(),
            LeadConversionValidator.validate(qualified),
            'A qualified, consented Lead with a Care Program should pass the gate'
        );
        System.assertEquals(true, LeadConversionValidator.isConvertible(qualified), 'Expected convertible');
    }

    @IsTest
    static void validateBlocksNullLead() {
        List<String> problems = LeadConversionValidator.validate(null);

        System.assertEquals(1, problems.size(), 'A missing Lead should produce exactly one problem');
        System.assert(problems[0].contains('not found'), 'Expected a not-found message, got: ' + problems[0]);
    }

    @IsTest
    static void validateBlocksAlreadyConvertedLeadWithoutOtherNoise() {
        Lead converted = buildLead(true, null, false, false, true);

        List<String> problems = LeadConversionValidator.validate(converted);

        System.assertEquals(1, problems.size(), 'Already-converted should short-circuit the remaining checks');
        System.assert(problems[0].contains('already been converted'), 'Unexpected message: ' + problems[0]);
    }

    @IsTest
    static void validateBlocksWrongIntakeStatus() {
        Lead notQualified = buildLead(false, 'Referral Received', true, true, true);

        List<String> problems = LeadConversionValidator.validate(notQualified);

        System.assertEquals(1, problems.size(), 'Only the intake status should fail: ' + problems);
        System.assert(problems[0].contains('Intake Status must be'), 'Unexpected message: ' + problems[0]);
        System.assert(problems[0].contains('Referral Received'), 'Message should name the current status');
    }

    @IsTest
    static void validateReportsBlankIntakeStatusReadably() {
        Lead blankStatus = buildLead(false, null, true, true, true);

        List<String> problems = LeadConversionValidator.validate(blankStatus);

        System.assert(problems[0].contains('blank'), 'A null status should read as "blank", got: ' + problems[0]);
    }

    @IsTest
    static void validateBlocksIncompleteConsent() {
        Lead noConsent = buildLead(false, 'Qualified', false, true, true);

        List<String> problems = LeadConversionValidator.validate(noConsent);

        System.assertEquals(1, problems.size(), 'Only consent should fail: ' + problems);
        System.assert(problems[0].contains('consents'), 'Unexpected message: ' + problems[0]);
    }

    @IsTest
    static void validateBlocksMissingCareProgramAndLastName() {
        Lead incomplete = buildLead(false, 'Qualified', true, false, false);

        List<String> problems = LeadConversionValidator.validate(incomplete);

        System.assertEquals(2, problems.size(), 'Care Program and Last Name should both fail: ' + problems);
        String joined = LeadConversionValidator.describeProblems(problems);
        System.assert(joined.contains('Care Program Of Interest'), 'Expected Care Program message in: ' + joined);
        System.assert(joined.contains('Last Name'), 'Expected Last Name message in: ' + joined);
        System.assert(joined.contains('\n'), 'describeProblems should newline-separate messages');
    }

    /**
     * Builds an in-memory Lead including the consent formula field, which the
     * sObject constructor rejects.
     */
    private static Lead buildLead(
        Boolean isConverted,
        String intakeStatus,
        Boolean consentsComplete,
        Boolean withCareProgram,
        Boolean withLastName
    ) {
        Map<String, Object> values = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Lead' },
            'IsConverted' => isConverted,
            'All_Required_Consents_Complete__c' => consentsComplete
        };

        if (intakeStatus != null) {
            values.put('Intake_Status__c', intakeStatus);
        }
        if (withLastName) {
            values.put('LastName', 'Tester');
        }
        if (withCareProgram) {
            values.put('Care_Program_Of_Interest__c', fakeId(CareProgram.SObjectType));
        }

        return (Lead) JSON.deserialize(JSON.serialize(values), Lead.class);
    }

    /**
     * Id that satisfies a lookup assignment without touching the database.
     * Built as a 15-character Id — the 18-character form carries a checksum
     * suffix that cannot be faked.
     */
    private static Id fakeId(Schema.SObjectType sobjectType) {
        String prefix = sobjectType.getDescribe().getKeyPrefix();
        return Id.valueOf(prefix + '0'.repeat(11) + '1');
    }
}