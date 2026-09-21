/**
 * Lets the Screen Flow ask "can this Lead be converted?" before showing the
 * confirmation screen, using the same rules the service enforces.
 */
public with sharing class LeadConversionGateInvocable {
    public class GateRequest {
        @InvocableVariable(label='Lead ID' required=true)
        public Id leadId;
    }

    public class GateResult {
        @InvocableVariable(label='Can Convert')
        public Boolean canConvert = false;

        @InvocableVariable(label='Blocking Reasons')
        public String blockingReasons;

        @InvocableVariable(label='Has Insurance Data')
        public Boolean hasInsuranceData = false;

        @InvocableVariable(label='Has Prescriber')
        public Boolean hasPrescriber = false;

        @InvocableVariable(label='Patient Name')
        public String patientName;

        @InvocableVariable(label='Care Program Name')
        public String careProgramName;
    }

    @InvocableMethod(
        label='Check Lead Conversion Gate'
        description='Returns whether a Lead passes the conversion gate, plus the detail the confirmation screen shows.'
        category='Life Sciences'
    )
    public static List<GateResult> check(List<GateRequest> requests) {
        Set<Id> leadIds = new Set<Id>();
        for (GateRequest request : requests) {
            if (request != null && request.leadId != null) {
                leadIds.add(request.leadId);
            }
        }

        Map<Id, Lead> leadsById = leadIds.isEmpty()
            ? new Map<Id, Lead>()
            : new LeadConvertSelector().selectLeadsForConversion(leadIds);

        List<GateResult> results = new List<GateResult>();
        for (GateRequest request : requests) {
            results.add(buildResult(request == null ? null : leadsById.get(request.leadId)));
        }
        return results;
    }

    private static GateResult buildResult(Lead leadRecord) {
        GateResult result = new GateResult();

        List<String> problems = LeadConversionValidator.validate(leadRecord);
        result.canConvert = problems.isEmpty();
        result.blockingReasons = problems.isEmpty() ? null : LeadConversionValidator.describeProblems(problems);

        if (leadRecord == null) {
            return result;
        }

        result.hasInsuranceData = String.isNotBlank(leadRecord.Insurance_Plan_Name__c);
        result.hasPrescriber = leadRecord.Resolved_Prescriber__c != null || String.isNotBlank(leadRecord.Prescriber_Full_Name__c);
        result.patientName = (String.isBlank(leadRecord.FirstName) ? '' : leadRecord.FirstName + ' ') +
            leadRecord.LastName;
        result.careProgramName = leadRecord.Care_Program_Of_Interest__r == null
            ? null
            : leadRecord.Care_Program_Of_Interest__r.Name;

        return result;
    }
}