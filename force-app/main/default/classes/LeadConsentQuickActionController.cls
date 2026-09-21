public with sharing class LeadConsentQuickActionController {
    @AuraEnabled
    public static Id saveConsent(AuthorizationFormConsent consent, String contentDocumentId) {
        if (!Schema.SObjectType.AuthorizationFormConsent.isCreateable()) {
            throw new AuraHandledException('Insufficient access to create Authorization Form Consent records.');
        }
        try {
            if (String.isNotBlank(contentDocumentId)) {
                List<ContentVersion> versions = [
                    SELECT Id
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                if (!versions.isEmpty()) {
                    consent.DocumentVersionId = versions[0].Id;
                }
            }
            insert consent;
            return consent.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}