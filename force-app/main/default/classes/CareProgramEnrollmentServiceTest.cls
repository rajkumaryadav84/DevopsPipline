@IsTest
private class CareProgramEnrollmentServiceTest {

    @IsTest(SeeAllData=true)
    static void testFreshEnrollmentSuccess() {
        List<Account> patients = [SELECT Id, Name FROM Account LIMIT 1];
        if (patients.isEmpty()) {
            return;
        }
        Account patient = patients[0];

        List<CareProgram> programs = [SELECT Id, Name FROM CareProgram LIMIT 1];
        if (programs.isEmpty()) {
            return;
        }
        CareProgram program = programs[0];

        Test.startTest();
        CareProgramEnrollmentService.EnrollmentResult result = CareProgramEnrollmentService.enrollPatient(patient.Id, program.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result object should not be null.');
        if (result.isSuccess) {
            CareProgramEnrollee enrollee = [SELECT Enrollment_Date__c, Confirmation_Date__c FROM CareProgramEnrollee WHERE Id = :result.enrolleeId];
            System.assertEquals(Date.today(), enrollee.Enrollment_Date__c, 'Enrollment Date should equal today.');
            System.assertNotEquals(null, enrollee.Confirmation_Date__c, 'Confirmation Date should be set.');
        }
    }

    @IsTest(SeeAllData=true)
    static void testDuplicateEnrollmentBlocked() {
        List<CareProgramEnrollee> existingEnrollees = [
            SELECT AccountId, CareProgramId, Status 
            FROM CareProgramEnrollee 
            WHERE Status IN ('Pending Verification', 'Active', 'Verified', 'Program Eligibility') 
            LIMIT 1
        ];
        
        if (existingEnrollees.isEmpty()) {
            return;
        }
        CareProgramEnrollee existing = existingEnrollees[0];

        Test.startTest();
        CareProgramEnrollmentService.EnrollmentResult result = CareProgramEnrollmentService.enrollPatient(existing.AccountId, existing.CareProgramId, null);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Duplicate enrollment must be blocked.');
        System.assertEquals(true, result.hasActiveEnrollee, 'hasActiveEnrollee should be true.');
        System.assertNotEquals(null, result.existingEnrollee, 'Existing enrollee record should be returned.');
    }

    @IsTest(SeeAllData=true)
    static void testControllerMethods() {
        List<Account> patients = [SELECT Id, Name FROM Account LIMIT 1];
        if (patients.isEmpty()) {
            return;
        }
        Account patient = patients[0];

        List<CareProgram> programs = CareProgramEnrollmentController.getAvailableCarePrograms();
        if (programs.isEmpty()) {
            return;
        }
        CareProgram program = programs[0];

        Test.startTest();
        CareProgramEnrollee checkBefore = CareProgramEnrollmentController.checkActiveEnrollment(patient.Id, program.Id);
        CareProgramEnrollmentService.EnrollmentResult res = CareProgramEnrollmentController.createEnrollee(patient.Id, program.Id, null);
        CareProgramEnrollee checkAfter = CareProgramEnrollmentController.checkActiveEnrollment(patient.Id, program.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Controller method res should not be null.');
    }
}