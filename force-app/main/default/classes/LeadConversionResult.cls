/**
 * Outcome of one Lead to Patient conversion. Returned to the Screen Flow so the
 * success screen can link to the new patient and the error screen can explain
 * what stopped it.
 */
public class LeadConversionResult {
    @InvocableVariable(label='Lead ID')
    public Id leadId;

    @InvocableVariable(label='Success')
    public Boolean isSuccess = false;

    @InvocableVariable(label='Person Account ID')
    public Id accountId;

    @InvocableVariable(label='Person Contact ID')
    public Id contactId;

    /**
     * Not populated: the enrollee is inserted asynchronously by
     * CareEnrolleeQueueable, after this result is returned. Kept so callers can
     * see the field is intentionally empty rather than missing.
     */
    @InvocableVariable(label='Care Program Enrollee ID')
    public Id enrolleeId;

    @InvocableVariable(label='Member Plan ID')
    public Id memberPlanId;

    @InvocableVariable(label='Error Message')
    public String errorMessage;

    public LeadConversionResult() {
    }

    public LeadConversionResult(Id leadId) {
        this.leadId = leadId;
    }

    public static LeadConversionResult failure(Id leadId, String message) {
        LeadConversionResult result = new LeadConversionResult(leadId);
        result.isSuccess = false;
        result.errorMessage = message;
        return result;
    }
}