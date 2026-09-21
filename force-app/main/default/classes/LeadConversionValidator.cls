/**
 * Conversion gate. Called twice on purpose: the Screen Flow calls it to decide
 * whether to show the confirmation screen, and LeadConversionService calls it
 * again so the gate cannot be bypassed by invoking the service directly.
 */
public with sharing class LeadConversionValidator {
    /** Intake Status a Lead must hold before it can become a patient. */
    public static final String REQUIRED_INTAKE_STATUS = 'Qualified';

    /**
     * @return blocking messages for this Lead. Empty means clear to convert.
     */
    public static List<String> validate(Lead record) {
        List<String> problems = new List<String>();

        if (record == null) {
            problems.add('Lead not found or not visible to you.');
            return problems;
        }

        if (record.IsConverted) {
            problems.add('This Lead has already been converted.');
            return problems;
        }

        if (record.Intake_Status__c != REQUIRED_INTAKE_STATUS) {
            problems.add(
                'Intake Status must be "' +
                    REQUIRED_INTAKE_STATUS +
                    '" before conversion. Current status: ' +
                    (String.isBlank(record.Intake_Status__c) ? 'blank' : record.Intake_Status__c) +
                    '.'
            );
        }

        if (record.All_Required_Consents_Complete__c != true) {
            problems.add(
                'All three consents (HIPAA, Data Processing, Care Program Enrollment) must be Agreed before conversion.'
            );
        }

        if (record.Care_Program_Of_Interest__c == null) {
            problems.add('Care Program Of Interest is required — the Care Program Enrollee cannot be created without it.');
        }

        if (String.isBlank(record.LastName)) {
            problems.add('Last Name is required to create a patient record.');
        }

        return problems;
    }

    /** Convenience for callers that only need a yes/no. */
    public static Boolean isConvertible(Lead record) {
        return validate(record).isEmpty();
    }

    /** Joins gate messages into one string for a Flow screen or an error result. */
    public static String describeProblems(List<String> problems) {
        return String.join(problems, '\n');
    }
}