public with sharing class PatientEmailService {

    public static void sendVerificationEmail(
        Patient_Onboarding__c patient,
        String token
    ) {

        if (patient == null ||
            String.isBlank(patient.Email__c) ||
            String.isBlank(token)) {
            return;
        }

        // Dynamically get the org URL
       String verifyUrl =
    'https://nagarro65.my.site.com/patients/verify?token=' +
    EncodingUtil.urlEncode(token, 'UTF-8');
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

        email.setToAddresses(new List<String>{ patient.Email__c });
        email.setSubject('Verify Your Identity');

        String patientName = String.isBlank(patient.First_Name__c)
            ? 'Patient'
            : patient.First_Name__c;

        String body =
            '<html><body>' +
            '<p>Dear <b>' + patientName + '</b>,</p>' +

            '<p>Thank you for completing the Patient Onboarding form.</p>' +

            '<p>Please click the link below to verify your identity.</p>' +

            '<p>' +
            '<a href="' + verifyUrl + '">' +
            'Verify My Identity' +
            '</a>' +
            '</p>' +

            '<p>This verification link expires in <b>2 hours</b>.</p>' +

            '<p>If you did not request this verification, please ignore this email.</p>' +

            '<br/>' +
            '<p>Regards,<br/>Healthcare Team</p>' +
            '</body></html>';

        email.setHtmlBody(body);

        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { email }
        );
    }
}