/**
 * Flow entry point for Lead to Patient conversion. Holds no logic — the Screen
 * Flow gathers options, this hands them to LeadConversionService.
 */
public with sharing class LeadConversionInvocable {
    @InvocableMethod(
        label='Convert Lead to Patient'
        description='Converts a Lead into a Person Account and creates the Care Program Enrollee and related LSC records.'
        category='Life Sciences'
    )
    public static List<LeadConversionResult> convertLeads(List<LeadConversionRequest> requests) {
        return LeadConversionService.convert(requests);
    }
}