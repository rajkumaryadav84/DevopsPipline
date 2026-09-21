public without sharing class CareProgramEnrollmentService {

    public class EnrollmentResult {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id enrolleeId { get; set; }
        @AuraEnabled public Boolean hasActiveEnrollee { get; set; }
        @AuraEnabled public CareProgramEnrollee existingEnrollee { get; set; }

        public EnrollmentResult() {
            this.isSuccess = false;
            this.hasActiveEnrollee = false;
        }
    }

    // Default active statuses that block duplicate enrollment
    private static final Set<String> ACTIVE_ENROLLEE_STATUSES = new Set<String>{
        'Pending Verification',
        'Active',
        'Enrolled',
        'In Progress',
        'Verified',
        'Program Eligibility'
    };

    /**
     * Retrieves all active CareProgramEnrollee records for a patient.
     */
    public static List<CareProgramEnrollee> getPatientActiveEnrollees(Id patientAccountId) {
        if (patientAccountId == null) {
            return new List<CareProgramEnrollee>();
        }

        return [
            SELECT Id, Name, Status, CareProgramId, CareProgram.Name, AccountId, Account.Name, CreatedDate, Enrollment_Date__c, Confirmation_Date__c
            FROM CareProgramEnrollee
            WHERE AccountId = :patientAccountId
              AND Status IN :ACTIVE_ENROLLEE_STATUSES
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Checks if a patient already has an active CareProgramEnrollee in the given CareProgram.
     */
    public static CareProgramEnrollee getActiveEnrollee(Id patientAccountId, Id careProgramId) {
        if (patientAccountId == null || careProgramId == null) {
            return null;
        }

        List<CareProgramEnrollee> existingEnrollees = [
            SELECT Id, Name, Status, CareProgramId, CareProgram.Name, AccountId, Account.Name, CreatedDate, Enrollment_Date__c, Confirmation_Date__c
            FROM CareProgramEnrollee
            WHERE AccountId = :patientAccountId
              AND CareProgramId = :careProgramId
              AND Status IN :ACTIVE_ENROLLEE_STATUSES
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return existingEnrollees.isEmpty() ? null : existingEnrollees[0];
    }

    /**
     * Enrolls an existing patient into a new Care Program without a Lead conversion event.
     * Prevents double-enrollment if an active enrollee already exists.
     * Populates Enrollment_Date__c and Confirmation_Date__c to creation date/time.
     */
    public static EnrollmentResult enrollPatient(Id patientAccountId, Id careProgramId, Id originatingLeadId) {
        EnrollmentResult result = new EnrollmentResult();

        if (patientAccountId == null || careProgramId == null) {
            result.message = 'Patient Account ID and Care Program ID are required.';
            return result;
        }

        // 1. Duplicate Guardrail Check
        CareProgramEnrollee existing = getActiveEnrollee(patientAccountId, careProgramId);
        if (existing != null) {
            result.hasActiveEnrollee = true;
            result.existingEnrollee = existing;
            result.enrolleeId = existing.Id;
            result.message = 'The patient is already actively enrolled in this Care Program (' + existing.CareProgram.Name + ').';
            return result;
        }

        // 2. Query Patient Account and Care Program details for default naming
        Account patient = [SELECT Name FROM Account WHERE Id = :patientAccountId LIMIT 1];
        CareProgram program = [SELECT Name FROM CareProgram WHERE Id = :careProgramId LIMIT 1];

        // 3. Construct new CareProgramEnrollee record
        CareProgramEnrollee newEnrollee = new CareProgramEnrollee();
        newEnrollee.AccountId = patientAccountId;
        newEnrollee.CareProgramId = careProgramId;
        newEnrollee.Status = 'Pending Verification'; // Default as required by Story 1
        newEnrollee.Name = patient.Name + ' - ' + program.Name;

        // Set Enrollment Date (Date) and Confirmation Date (DateTime) to Creation Date
        newEnrollee.Enrollment_Date__c = Date.today();
        newEnrollee.Confirmation_Date__c = System.now();
        newEnrollee.Confirmed_By__c = UserInfo.getUserId(); // Set to current user
        
        try {
            insert newEnrollee;
            
            result.isSuccess = true;
            result.enrolleeId = newEnrollee.Id;
            result.message = 'Successfully created Care Program Enrollee record.';
        } catch (Exception ex) {
            result.isSuccess = false;
            result.message = 'Failed to create Care Program Enrollee: ' + ex.getMessage();
        }

        return result;
    }
}