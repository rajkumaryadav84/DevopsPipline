public with sharing class SendConsentFormController {

    public class AuthorizationFormTextWrapper {
        @AuraEnabled
        public String name;

        @AuraEnabled
        public String detailAuthorizationFormText;
    }

    // Identifies whether the record ID belongs to Account.
    private static Boolean isAccountRecord(Id recordId) {
        return recordId != null && recordId.getSObjectType() == Account.SObjectType;
    }

    @AuraEnabled(cacheable=true)
    public static AuthorizationFormTextWrapper getAuthorizationFormText(Id formTextId) {
        try {
            List<AuthorizationFormText> records = [
                SELECT Name, DetailAuthorizationFormText
                FROM AuthorizationFormText
                WHERE Id = :formTextId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (records.isEmpty()) {
                throw new AuraHandledException('Authorization Form Text not found.');
            }

            AuthorizationFormTextWrapper response = new AuthorizationFormTextWrapper();
            response.name = records[0].Name;
            response.detailAuthorizationFormText = records[0].DetailAuthorizationFormText;

            return response;

        } catch (AuraHandledException exc) {
            throw exc;
        } catch (Exception exc) {
            throw new AuraHandledException(exc.getMessage());
        }
    }

    // Dynamically retrieves additional Lead/Account fields whose API names are
    // present as unmapped tokens in DetailAuthorizationFormText.
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getAdditionalLeadFieldValues(Id leadId, List<String> fieldApiNames) {

        /*
         * Account functionality:
         *
         * For an Account record, the LWC sends all tokens found inside
         * {{ }}. Apex validates those fields against Account, queries the
         * Account, returns the values to the LWC, and the LWC performs the
         * existing token merge and PDF generation.
         */
        if (isAccountRecord(leadId)) {

            System.debug('This is an account record');
            System.debug('Account Record Id received from LWC: ' + leadId);
            System.debug('Field API names received from LWC: ' + fieldApiNames);

            try {
                Map<String, String> accountFieldValues = new Map<String, String>();

                if (fieldApiNames == null || fieldApiNames.isEmpty()) {
                    System.debug('No field API names were received from LWC.');
                    return accountFieldValues;
                }

                /*
                 * Object-level CRUD check for Account.
                 */
                if (!Account.SObjectType.getDescribe().isAccessible()) {
                    throw new AuraHandledException('Insufficient access to read Account records.');
                }

                /*
                 * Get all Account fields dynamically so every field API
                 * name received from the LWC can be validated.
                 */
                Map<String, Schema.SObjectField> accountFieldMap = Account.SObjectType.getDescribe().fields.getMap();

                Set<String> validAccountFieldApiNames = new Set<String>();
                List<String> invalidOrInaccessibleAccountFields = new List<String>();

                /*
                 * Validate every Account field API name received from LWC.
                 *
                 * This branch currently supports direct Account fields.
                 * Relationship fields such as Owner.Name are treated as
                 * invalid in the Account branch.
                 */
                for (String fieldApiName : fieldApiNames) {

                    if (String.isBlank(fieldApiName)) {
                        continue;
                    }

                    // {{inputbox*}} tokens are fillable-PDF-field placeholders
                    // handled entirely on the LWC/renderer side, not real
                    // Account fields.
                    if (fieldApiName.toLowerCase().startsWith('inputbox')) {
                        continue;
                    }

                    if (fieldApiName.contains('.')) {
                        invalidOrInaccessibleAccountFields.add(fieldApiName);
                        continue;
                    }

                    if (!accountFieldMap.containsKey(fieldApiName)) {
                        invalidOrInaccessibleAccountFields.add(fieldApiName);
                        continue;
                    }

                    if (!accountFieldMap.get(fieldApiName).getDescribe().isAccessible()) {
                        invalidOrInaccessibleAccountFields.add(fieldApiName);
                        continue;
                    }

                    validAccountFieldApiNames.add(fieldApiName);
                }

                System.debug('Valid Account field API names: ' + validAccountFieldApiNames);
                System.debug('Invalid or inaccessible Account field API names: ' + invalidOrInaccessibleAccountFields);

                if (!invalidOrInaccessibleAccountFields.isEmpty()) {
                    throw new AuraHandledException(
                        'Invalid or inaccessible Account field API name(s): ' +
                        String.join(invalidOrInaccessibleAccountFields, ', ')
                    );
                }

                if (validAccountFieldApiNames.isEmpty()) {
                    return accountFieldValues;
                }

                List<String> accountFieldsToQuery = new List<String>(validAccountFieldApiNames);
                accountFieldsToQuery.sort();

                String accountQuery = 'SELECT ' + String.join(accountFieldsToQuery, ', ') +
                                      ' FROM Account WHERE Id = :leadId LIMIT 1';

                System.debug('SendConsentFormController.getAdditionalLeadFieldValues Account query: ' + accountQuery);

                Account accountRecord = Database.query(accountQuery);

                System.debug('Account record returned by query: ' + accountRecord);

                for (String fieldApiName : accountFieldsToQuery) {
                    Object fieldValue = accountRecord.get(fieldApiName);

                    accountFieldValues.put(
                        fieldApiName,
                        fieldValue == null ? '' : String.valueOf(fieldValue)
                    );

                    System.debug('Account field API name: ' + fieldApiName + ', Account field value: ' + fieldValue);
                }

                System.debug('Account field values being returned to LWC: ' + accountFieldValues);

                return accountFieldValues;

            } catch (AuraHandledException accountException) {
                throw accountException;
            } catch (Exception accountException) {
                System.debug('Error while querying Account fields: ' + accountException.getMessage());
                throw new AuraHandledException(accountException.getMessage());
            }
        }

        /*
         * Existing Lead functionality continues below.
         */
        try {
            Map<String, String> fieldValues = new Map<String, String>();

            if (leadId == null || fieldApiNames == null || fieldApiNames.isEmpty()) {
                return fieldValues;
            }

            if (!Lead.SObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient access to read Lead records.');
            }

            Map<String, Schema.SObjectField> leadFieldMap = Lead.SObjectType.getDescribe().fields.getMap();

            Map<String, Schema.SObjectType> relationshipTargets = new Map<String, Schema.SObjectType>();

            for (Schema.SObjectField leadField : leadFieldMap.values()) {
                Schema.DescribeFieldResult dfr = leadField.getDescribe();
                String relationshipName = dfr.getRelationshipName();

                if (relationshipName != null && !dfr.getReferenceTo().isEmpty()) {
                    relationshipTargets.put(relationshipName, dfr.getReferenceTo()[0]);
                }
            }

            Set<String> validFieldApiNames = new Set<String>();
            List<String> invalidOrInaccessibleFields = new List<String>();

            for (String fieldApiName : fieldApiNames) {

                if (String.isBlank(fieldApiName)) {
                    continue;
                }

                if (fieldApiName.toLowerCase().startsWith('inputbox')) {
                    continue;
                }

                if (fieldApiName.contains('.')) {
                    List<String> pathParts = fieldApiName.split('\\.');

                    if (pathParts.size() != 2) {
                        invalidOrInaccessibleFields.add(fieldApiName);
                        continue;
                    }

                    String relationshipName = pathParts[0];
                    String relatedFieldName = pathParts[1];

                    if (!relationshipTargets.containsKey(relationshipName)) {
                        invalidOrInaccessibleFields.add(fieldApiName);
                        continue;
                    }

                    Schema.SObjectType targetType = relationshipTargets.get(relationshipName);

                    if (!targetType.getDescribe().isAccessible()) {
                        invalidOrInaccessibleFields.add(fieldApiName);
                        continue;
                    }

                    Map<String, Schema.SObjectField> targetFieldMap = targetType.getDescribe().fields.getMap();

                    if (!targetFieldMap.containsKey(relatedFieldName)) {
                        invalidOrInaccessibleFields.add(fieldApiName);
                        continue;
                    }

                    if (!targetFieldMap.get(relatedFieldName).getDescribe().isAccessible()) {
                        invalidOrInaccessibleFields.add(fieldApiName);
                        continue;
                    }

                    validFieldApiNames.add(fieldApiName);
                    continue;
                }

                if (!leadFieldMap.containsKey(fieldApiName)) {
                    invalidOrInaccessibleFields.add(fieldApiName);
                    continue;
                }

                if (!leadFieldMap.get(fieldApiName).getDescribe().isAccessible()) {
                    invalidOrInaccessibleFields.add(fieldApiName);
                    continue;
                }

                validFieldApiNames.add(fieldApiName);
            }

            if (!invalidOrInaccessibleFields.isEmpty()) {
                throw new AuraHandledException(
                    'Invalid or inaccessible Lead field API name(s): ' +
                    String.join(invalidOrInaccessibleFields, ', ')
                );
            }

            if (validFieldApiNames.isEmpty()) {
                return fieldValues;
            }

            List<String> fieldsToQuery = new List<String>(validFieldApiNames);
            fieldsToQuery.sort();

            String dynamicQuery = 'SELECT ' + String.join(fieldsToQuery, ', ') +
                                  ' FROM Lead WHERE Id = :leadId LIMIT 1';

            System.debug('SendConsentFormController.getAdditionalLeadFieldValues dynamicQuery: ' + dynamicQuery);

            Lead leadRecord = Database.query(dynamicQuery);

            for (String fieldApiName : validFieldApiNames) {
                Object fieldValue;

                if (fieldApiName.contains('.')) {
                    List<String> pathParts = fieldApiName.split('\\.');
                    SObject relatedRecord = leadRecord.getSObject(pathParts[0]);

                    fieldValue = (relatedRecord != null) ? relatedRecord.get(pathParts[1]) : null;
                } else {
                    fieldValue = leadRecord.get(fieldApiName);
                }

                fieldValues.put(
                    fieldApiName,
                    fieldValue == null ? '' : String.valueOf(fieldValue)
                );
            }

            System.debug('SendConsentFormController.getAdditionalLeadFieldValues resolved fieldValues: ' + fieldValues);

            return fieldValues;

        } catch (AuraHandledException exx) {
            throw exx;
        } catch (Exception exx) {
            throw new AuraHandledException(exx.getMessage());
        }
    }

    @AuraEnabled
    public static void sendConsentFormEmail(
        Id leadId,
        Id formTextId,
        String toAddress,
        String pdfBase64,
        String fileName
    ) {

        if (!ContentVersion.SObjectType.getDescribe().isCreateable()) {
            throw new AuraHandledException('Insufficient access to create Files.');
        }

        try {
            Blob pdfBlob = EncodingUtil.base64Decode(pdfBase64);

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(fileName);
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { toAddress });
            mail.setSubject('Consent Form for Your Review');
            mail.setPlainTextBody(
                'Please find attached your consent form. ' +
                'Review, sign, and return it at your earliest convenience.'
            );
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            mail.setSaveAsActivity(false);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            ContentVersion version = new ContentVersion();
            version.Title = fileName;
            version.PathOnClient = fileName;
            version.VersionData = pdfBlob;
            insert version;

            List<ContentVersion> insertedVersions = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :version.Id
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (!insertedVersions.isEmpty() && ContentDocumentLink.SObjectType.getDescribe().isCreateable()) {
                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = insertedVersions[0].ContentDocumentId;
                link.LinkedEntityId = leadId;
                link.ShareType = 'V';
                link.Visibility = 'AllUsers';

                insert link;
            }

        } catch (AuraHandledException exz) {
            throw exz;
        } catch (Exception exz) {
            throw new AuraHandledException(exz.getMessage());
        }
    }
}