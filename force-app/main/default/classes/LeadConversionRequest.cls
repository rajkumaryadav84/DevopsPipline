/**
 * Input for a single Lead to Patient conversion.
 * Doubles as the Flow invocable input, so every caller-supplied option is an
 * @InvocableVariable.
 */
public class LeadConversionRequest {
    @InvocableVariable(label='Lead ID' description='Lead to convert into a Person Account' required=true)
    public Id leadId;

    @InvocableVariable(label='Owner ID' description='Owner for the converted records. Defaults to the Lead owner.')
    public Id ownerId;

    @InvocableVariable(
        label='Create Insurance Plan'
        description='Create a MemberPlan from the Lead insurance fields when insurance data is present.'
    )
    public Boolean createMemberPlan;

    @InvocableVariable(
        label='Link Prescriber'
        description='Attach the resolved prescriber to the Care Program as a provider.'
    )
    public Boolean linkPrescriber;

    @InvocableVariable(
        label='Converted Lead Status'
        description='Lead Status marked IsConverted. Defaults to the org default converted status.'
    )
    public String convertedStatus;

    public LeadConversionRequest() {
    }

    public LeadConversionRequest(Id leadId) {
        this.leadId = leadId;
    }

    /** Callers may leave the flags null; treat null as opt-in. */
    public Boolean wantsMemberPlan() {
        return this.createMemberPlan != false;
    }

    public Boolean wantsPrescriberLink() {
        return this.linkPrescriber != false;
    }
}