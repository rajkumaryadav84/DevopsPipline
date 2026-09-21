/**
 * One-time backfill utility: populates Provider_Name__c, Provider_NPI__c, and Provider_Type__c
 * on existing CareProgramProvider records by joining via CarePgmProvHealthcareProvider.
 * This is a deployed class so it sees the new custom fields immediately.
 */
public class CareProviderBackfill implements Queueable {
    public void execute(QueueableContext ctx) {
        // Get all CPP records missing Provider_Name__c
        List<CareProgramProvider> toUpdate = new List<CareProgramProvider>();

        for (CareProgramProvider cpp : [
            SELECT Id, Name, Provider_Name__c, Provider_NPI__c, Provider_Type__c
            FROM CareProgramProvider
            WHERE Provider_Name__c = null
        ]) {
            toUpdate.add(cpp);
        }

        if (toUpdate.isEmpty()) return;

        // Build map of CPP Id -> CPP
        Map<Id, CareProgramProvider> cppById = new Map<Id, CareProgramProvider>(toUpdate);

        // Get junctions to find linked HealthcareProviders
        Map<Id, Id> cppToHp = new Map<Id, Id>();
        for (CarePgmProvHealthcareProvider j : [
            SELECT CareProgramProviderId, HealthcareProviderId
            FROM CarePgmProvHealthcareProvider
            WHERE CareProgramProviderId IN :cppById.keySet()
        ]) {
            cppToHp.put(j.CareProgramProviderId, j.HealthcareProviderId);
        }

        // Get HealthcareProvider names & types
        if (!cppToHp.values().isEmpty()) {
            Map<Id, HealthcareProvider> hpMap = new Map<Id, HealthcareProvider>([
                SELECT Id, Name, ProviderType
                FROM HealthcareProvider
                WHERE Id IN :cppToHp.values()
            ]);

            for (CareProgramProvider cpp : toUpdate) {
                Id hpId = cppToHp.get(cpp.Id);
                if (hpId != null && hpMap.containsKey(hpId)) {
                    HealthcareProvider hp = hpMap.get(hpId);
                    cpp.Provider_Name__c = hp.Name;
                    cpp.Provider_Type__c = hp.ProviderType;
                }
                // Parse NPI from name e.g. "Dr. Luca Rossi (NPI: 1982736450)"
                if (String.isBlank(cpp.Provider_NPI__c) && cpp.Name != null && cpp.Name.contains('NPI: ')) {
                    cpp.Provider_NPI__c = cpp.Name.substringBetween('NPI: ', ')');
                }
            }
        }

        update toUpdate;
        System.debug('BACKFILL COMPLETE: updated ' + toUpdate.size() + ' records');
    }
}