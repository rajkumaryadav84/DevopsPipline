public without sharing class CareProgramEnrollmentController {

    @AuraEnabled(cacheable=true)
    public static List<CareProgram> getAvailableCarePrograms() {
        try {
            return [
                SELECT Id, Name, Status, StartDate, EndDate, Description
                FROM CareProgram
                WHERE Status IN ('Active', 'New', 'In Progress')
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load Care Programs: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<CareProgramEnrollee> getPatientActiveEnrollees(Id patientAccountId) {
        try {
            return CareProgramEnrollmentService.getPatientActiveEnrollees(patientAccountId);
        } catch (Exception e) {
            throw new AuraHandledException('Error checking active enrollment: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static CareProgramEnrollee checkActiveEnrollment(Id patientAccountId, Id careProgramId) {
        try {
            return CareProgramEnrollmentService.getActiveEnrollee(patientAccountId, careProgramId);
        } catch (Exception e) {
            throw new AuraHandledException('Error checking active enrollment: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static CareProgramEnrollmentService.EnrollmentResult createEnrollee(Id patientAccountId, Id careProgramId, Id originatingLeadId) {
        try {
            return CareProgramEnrollmentService.enrollPatient(patientAccountId, careProgramId, originatingLeadId);
        } catch (Exception e) {
            throw new AuraHandledException('Error creating enrollee: ' + e.getMessage());
        }
    }
}