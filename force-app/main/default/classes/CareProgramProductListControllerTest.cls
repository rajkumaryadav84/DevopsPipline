@isTest
private class CareProgramProductListControllerTest {

    @TestSetup
    static void setupData() {
        Account personAccount = new Account(FirstName = 'Test', LastName = 'Patient');
        insert personAccount;

        CareProgram program = new CareProgram(Name = 'Test Care Program', Status = 'Active');
        insert program;

        CareProgramEnrollee enrollee = new CareProgramEnrollee(
            AccountId = personAccount.Id,
            CareProgramId = program.Id,
            Status = 'Pending'
        );
        insert enrollee;

        Product2 product = new Product2(Name = 'Test Product', IsActive = true);
        insert product;

        CareProgramProduct cpp = new CareProgramProduct(
            CareProgramId = program.Id,
            ProductId = product.Id,
            Status = 'Active'        );
        insert cpp;
    }

    @isTest
    static void testGetCareProgramProductsSuccess() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        CareProgramProductListController.ResultWrapper result =
            CareProgramProductListController.getCareProgramProducts(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.enrolleeId, 'Enrollee should be found for the account');
        System.assertEquals(1, result.products.size(), 'One related product should be returned');
        System.assertEquals('Test Product', result.products[0].productName, 'Product name should flatten correctly');
    }

    @isTest
    static void testGetCareProgramProductsNoEnrollee() {
        Account orphanAccount = new Account(FirstName = 'No', LastName = 'Enrollee');
        insert orphanAccount;

        Test.startTest();
        CareProgramProductListController.ResultWrapper result =
            CareProgramProductListController.getCareProgramProducts(orphanAccount.Id);
        Test.stopTest();

        System.assertEquals(null, result.enrolleeId, 'No enrollee should be found');
        System.assertEquals(0, result.products.size(), 'No products should be returned');
    }

    @isTest
    static void testGetCareProgramProductsNullAccountId() {
        Test.startTest();
        CareProgramProductListController.ResultWrapper result =
            CareProgramProductListController.getCareProgramProducts(null);
        Test.stopTest();

        System.assertEquals(null, result.enrolleeId, 'Null accountId should short-circuit');
        System.assertEquals(0, result.products.size(), 'No products expected for null accountId');
    }

    @isTest
    static void testDeleteCareProgramProduct() {
        CareProgramProduct cpp = [SELECT Id FROM CareProgramProduct LIMIT 1];
        CareProgramEnrollee enrollee = [SELECT Id FROM CareProgramEnrollee LIMIT 1];

        Test.startTest();
        CareProgramProductListController.deleteCareProgramProduct(cpp.Id, enrollee.Id);
        Test.stopTest();

        List<CareProgramProduct> remaining = [SELECT Id FROM CareProgramProduct WHERE Id = :cpp.Id];
        System.assertEquals(0, remaining.size(), 'Product should have been deleted');
    }

    @isTest
    static void testDeleteCareProgramProductNullId() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CareProgramProductListController.deleteCareProgramProduct(null, null);
        } catch (AuraHandledException ahe) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Null productId should raise an AuraHandledException');
    }

    @isTest
    static void testStampEnrolleeAuditFields() {
        CareProgramEnrollee enrollee = [SELECT Id FROM CareProgramEnrollee LIMIT 1];

        Test.startTest();
        // Exercises the update path; does not assert on custom field values here
        // since those fields (Updated_By__c / Updated_Date__c) must be created
        // in the target org before this fully validates end-to-end.
        CareProgramProductListController.stampEnrolleeAuditFields(enrollee.Id);
        Test.stopTest();
    }

    @isTest
    static void testStampEnrolleeAuditFieldsNullId() {
        Test.startTest();
        CareProgramProductListController.stampEnrolleeAuditFields(null);
        Test.stopTest();
        // No exception expected; method should simply no-op.
    }
}