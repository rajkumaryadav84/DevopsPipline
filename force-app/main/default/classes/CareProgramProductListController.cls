/**
 * @description Controller supporting the careProgramProductRelatedList LWC.
 *               Resolves the CareProgramEnrollee for a given Person Account,
 *               retrieves the related CareProgramProduct records for that
 *               enrollee's CareProgram, and supports deleting products.
 *               Creation is handled client-side via lightning-record-edit-form;
 *               this class exposes stampEnrolleeAuditFields() so the LWC can
 *               update the enrollee's audit fields after a successful create.
 *
 *               Assumption: exactly one CareProgramEnrollee exists per Account,
 *               matching the stated requirement. If that assumption changes,
 *               adjust the LIMIT 1 query in getCareProgramProducts().
 *
 *               Assumption: custom fields Updated_By__c (Lookup(User)) and
 *               Updated_Date__c (DateTime) exist on CareProgramEnrollee.
 */
public with sharing class CareProgramProductListController {

    public class ProductWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String productName;
        @AuraEnabled public String status;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String availability;
    }

    public class ResultWrapper {
        @AuraEnabled public Id enrolleeId;
        @AuraEnabled public Id careProgramId;
        @AuraEnabled public String careProgramName;
        @AuraEnabled public List<ProductWrapper> products;
    }

    /**
     * @description Returns the enrollee/care program context and the list of
     *               CareProgramProduct records for the account's single enrollee.
     * @param accountId Person Account record Id (record page recordId)
     */
    @AuraEnabled(cacheable=true)
    public static ResultWrapper getCareProgramProducts(Id accountId) {
        ResultWrapper result = new ResultWrapper();
        result.products = new List<ProductWrapper>();

        if (accountId == null) {
            return result;
        }

        List<CareProgramEnrollee> enrollees = [
            SELECT Id, CareProgramId, CareProgram.Name
            FROM CareProgramEnrollee
            WHERE AccountId = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        if (enrollees.isEmpty()) {
            return result;
        }

        CareProgramEnrollee enrollee = enrollees[0];
        result.enrolleeId = enrollee.Id;
        result.careProgramId = enrollee.CareProgramId;
        result.careProgramName = enrollee.CareProgram != null ? enrollee.CareProgram.Name : null;

        if (enrollee.CareProgramId == null) {
            return result;
        }

        List<CareProgramProduct> products = [
            SELECT Id, Name, Status, availability
            FROM CareProgramProduct
            WHERE CareProgramId = :enrollee.CareProgramId
            WITH USER_MODE
            ORDER BY Name ASC NULLS LAST
        ];

        for (CareProgramProduct cpp : products) {
            ProductWrapper pw = new ProductWrapper();
            pw.id = cpp.Id;
            pw.productName = cpp.Name;
            pw.status = cpp.Status;
            pw.availability = cpp.availability;
            result.products.add(pw);
        }

        return result;
    }

    /**
     * @description Deletes a single CareProgramProduct and stamps audit fields
     *               on the related enrollee. Enforces object-level delete access
     *               and row-level visibility before performing the DML.
     */
    @AuraEnabled
    public static void deleteCareProgramProduct(Id productId, Id enrolleeId) {
        try {
            if (productId == null) {
                throw new AuraHandledException('Product Id is required.');
            }

            if (!Schema.sObjectType.CareProgramProduct.isDeletable()) {
                throw new AuraHandledException('You do not have permission to delete Care Program Products.');
            }

            List<CareProgramProduct> toDelete = [
                SELECT Id
                FROM CareProgramProduct
                WHERE Id = :productId
                WITH USER_MODE
            ];

            if (toDelete.isEmpty()) {
                return;
            }

            delete toDelete;
            stampEnrolleeAuditFields(enrolleeId);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting Care Program Product: ' + e.getMessage());
        }
    }

    /**
     * @description Stamps Updated_By__c / Updated_Date__c on the given
     *               CareProgramEnrollee. Called by the LWC after a successful
     *               create (via lightning-record-edit-form) and internally
     *               after a successful delete. Fails silently (logs only) so
     *               that audit stamping never blocks the user's primary action.
     */
    @AuraEnabled
    public static void stampEnrolleeAuditFields(Id enrolleeId) {
        try {
            if (enrolleeId == null) {
                return;
            }

            /*Boolean fieldsUpdateable =
                Schema.sObjectType.CareProgramEnrollee.fields.Updated_By__c.isUpdateable()
                && Schema.sObjectType.CareProgramEnrollee.fields.Updated_Date__c.isUpdateable();*/
            Boolean fieldsUpdateable = false;

            if (!fieldsUpdateable) {
                return;
            }

            CareProgramEnrollee toUpdate = new CareProgramEnrollee(
                Id = enrolleeId
                //Updated_By__c = UserInfo.getUserId(),
                //Updated_Date__c = System.now()
            );

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<CareProgramEnrollee>{ toUpdate }
            );

            List<CareProgramEnrollee> stripped = (List<CareProgramEnrollee>) decision.getRecords();

            if (!stripped.isEmpty()) {
                update stripped;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to stamp CareProgramEnrollee audit fields: ' + e.getMessage());
        }
    }
}