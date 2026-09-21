trigger LeadTrigger on Lead ( before update) {
    if (Trigger.isBefore) {
       // LeadTriggerHandler.validateDuplicatePatient(Trigger.new,Trigger.oldMap);
    }
}