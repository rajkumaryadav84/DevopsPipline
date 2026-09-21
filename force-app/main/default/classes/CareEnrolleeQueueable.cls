/**
 * Creates Care Program Enrollees in their own transaction.
 *
 * Why async: inserting a CareProgramEnrollee starts the managed Advanced
 * Therapy Management orchestration (healthcloud_ato_flows__ATMOrch). For an
 * ATM-enabled Care Program that orchestration runs hundreds of flow interviews
 * and consumes ~95 SOQL queries on its own. Sharing a transaction with Convert
 * Lead reliably breaches the 100-query limit and the whole conversion fails.
 * Splitting the enrollee out gives the orchestration a fresh limit budget.
 *
 * Consequence, by design: the patient and its related records commit first and
 * the enrollee follows moments later. If the enrollee insert fails the patient
 * still exists, so the failure is recorded as a Task on the patient rather than
 * being silently swallowed.
 */
public without sharing class CareEnrolleeQueueable implements Queueable {
    private final List<CareProgramEnrollee> enrollees;

    public CareEnrolleeQueueable(List<CareProgramEnrollee> enrollees) {
        this.enrollees = enrollees;
    }

    public void execute(QueueableContext context) {
        if (enrollees == null || enrollees.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.insert(enrollees, false);

        List<Task> failures = new List<Task>();
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                continue;
            }
            failures.add(buildFailureTask(enrollees[i], results[i]));
        }

        if (!failures.isEmpty()) {
            // Best effort: never let error reporting mask the original problem.
            Database.insert(failures, false);
        }
    }

    /**
     * Puts the failure in front of a human on the patient record, since the
     * conversion itself has already committed and cannot be rolled back.
     */
    private static Task buildFailureTask(CareProgramEnrollee enrollee, Database.SaveResult result) {
        List<String> messages = new List<String>();
        for (Database.Error error : result.getErrors()) {
            messages.add(error.getMessage());
        }

        return new Task(
            WhatId = enrollee.AccountId,
            Subject = 'Care Program enrollment failed after conversion',
            Description = 'The patient was created but the Care Program Enrollee could not be saved.\n\n' +
                'Care Program: ' +
                enrollee.CareProgramId +
                '\nSource Lead: ' +
                enrollee.LeadId +
                '\n\nError: ' +
                String.join(messages, '; '),
            Priority = 'High',
            Status = 'Open'
        );
    }
}