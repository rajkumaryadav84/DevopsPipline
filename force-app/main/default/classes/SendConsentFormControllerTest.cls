@IsTest
private class SendConsentFormControllerTest {
    @TestSetup
    static void setup() {
        AuthorizationForm form = new AuthorizationForm(Name = 'Test Consent Form');
        insert form;

        AuthorizationFormText formText = new AuthorizationFormText(
            Name = 'Test Consent Form',
            AuthorizationFormId = form.Id,
            IsActive = true,
            Locale = 'en_US',
            DetailAuthorizationFormText = '<p>Name: {{FirstName}} {{LastName}}</p>'
        );
        insert formText;

        Lead lead = new Lead(
            FirstName = 'Charles',
            LastName = 'Green',
            Company = 'ABC HealthCare',
            Email = 'charles.green@example.com',
            Phone = '1234567890',
            Status = 'Open - Not Contacted'
        );
        insert lead;
    }

    @IsTest
    static void getAuthorizationFormTextReturnsNameAndBody() {
        AuthorizationFormText formText = [SELECT Id FROM AuthorizationFormText LIMIT 1];

        Test.startTest();
        SendConsentFormController.AuthorizationFormTextWrapper wrapper = SendConsentFormController.getAuthorizationFormText(
            formText.Id
        );
        Test.stopTest();

        System.assertEquals('Test Consent Form', wrapper.name, 'Name should come through from the record');
        System.assert(
            wrapper.detailAuthorizationFormText.contains('{{FirstName}}'),
            'Body should contain the unmerged token, merging happens client-side'
        );
    }

    @IsTest
    static void getAuthorizationFormTextThrowsWhenNotFound() {
        Boolean threw = false;

        Test.startTest();
        try {
            SendConsentFormController.getAuthorizationFormText(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'A null/missing Id should raise an AuraHandledException');
    }

    @IsTest
    static void sendConsentFormEmailCreatesFileAndLinksToLead() {
        Lead lead = [SELECT Id FROM Lead LIMIT 1];
        AuthorizationFormText formText = [SELECT Id FROM AuthorizationFormText LIMIT 1];
        String pdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('fake pdf bytes'));

        Test.startTest();
        SendConsentFormController.sendConsentFormEmail(
            lead.Id,
            formText.Id,
            'charles.green@example.com',
            pdfBase64,
            'Test_Consent_Form.pdf'
        );
        Test.stopTest();

        List<ContentVersion> versions = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE Title = 'Test_Consent_Form.pdf'
        ];
        System.assertEquals(1, versions.size(), 'A ContentVersion should be created for the sent PDF');

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :versions[0].ContentDocumentId AND LinkedEntityId = :lead.Id
        ];
        System.assertEquals(1, links.size(), 'The Files entry should be linked to the Lead');
    }
}