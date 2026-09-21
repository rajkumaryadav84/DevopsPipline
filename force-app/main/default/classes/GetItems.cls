public without sharing class GetItems {
    

    @AuraEnabled(cacheable = true)
    public static List<Navigation_Item__c>  getPageItems(String pageName){
        //get the nav records
        Map<String, Id> lstNavRecords = getRecords();

        List<Navigation_Item__c> items = new List<Navigation_Item__c>();
        for(Navigation_Item__c item : [SELECT Id,Icon_Name__c, Section_Detail__c,Section_Heading__c,Target_App__c,RelatedEntityAPIName__c,Target_Tab_Name__c,NavigationType__c,Filter_Criteria__c,Target_RecordId__c, ObjectName__c
        FROM Navigation_Item__c WHERE isActive__c = true and PageName__c =:pageName order by Sequence_Number__c ]){
            if(item.Filter_Criteria__c != null){
                String recordId = getRecordIdBasedOnFilter(item.ObjectName__c,item.Filter_Criteria__c);
                if(recordId != null){
                    item.Target_RecordId__c = recordId;
                }
            }

            if(String.isNotBlank(item.Section_Detail__c)) {
                String richTextData = replaceNavigationLinks(pageName, item.Section_Detail__c, lstNavRecords);
                item.Section_Detail__c = richTextData;
            } 

            items.add(item);
        }
        return items;
    }

     private static String getRecordIdBasedOnFilter(String objectName, String filter){
        String soqlQuery = 'select Id,Name from ' + objectName + ' where ' + filter;
        System.debug('SOQL Query = ' + soqlQuery);
        try{
            List<Sobject> results = database.query(soqlQuery);
            System.debug('SOQL Query results = ' + results);
            return results[0].Id;
        }    
        catch(Exception e){
            System.debug('Exception = ' + e.toString());
            return null;
        }
            
    }

    private static Map<String, Id> getRecords() {
        Map<String, Id> mapRecords = new Map<String, Id>();

        ResearchStudyCandidate rscJBailey = [SELECT Id FROM ResearchStudyCandidate WHERE Candidate.Name = 'Jonathan Bailey' LIMIT 1];
        mapRecords.put('RSC_JONATHAN_BAILEY_REC', rscJBailey.Id);

        ResearchStudy rsType2Db = [SELECT Id FROM ResearchStudy WHERE Name = 'Evaluate MP-002-1005 in Subjects With Type 2 Diabetes Mellitus' LIMIT 1];
        mapRecords.put('RS_EVAL_TYPE2_DB', rsType2Db.Id);
        
        ResearchStudy rsRDMP = [SELECT Id FROM ResearchStudy WHERE Name = 'Rheumatic Disease Management Program' LIMIT 1];
        mapRecords.put('RS_RHEUMATIC_DISEASE_MGMT_PROGRAM', rsRDMP.Id);
        
        CareProgramEnrollee cpe = [SELECT Id FROM CareProgramEnrollee WHERE Name = 'Charles Green - Diabetes Management Program' LIMIT 1];
        mapRecords.put('CPE_CHARLES_GREEN_REC', cpe.Id);
        
        CareProgram cp = [SELECT Id FROM CareProgram WHERE Name = 'Diabetes Management Program' LIMIT 1];
        mapRecords.put('CPE_DIABETES_MANAGEMENT_PROGRAM_REC', cp.Id);

        return mapRecords;
    }

    private static String replaceNavigationLinks(String pageName, String richTextData, Map<String, Id> mapRecords) {
        String recValue = '';

        richTextData = richTextData.replace('RSC_LIST_VIEW', '<a href="/lightning/app/standard__ClinicalExcellence/o/ResearchStudyCandidate/list?filterName=MP_002_1005_Research_Study_Candidates" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('RSC_JONATHAN_BAILEY_REC');
        richTextData = richTextData.replace('RSC_JONATHAN_BAILEY_REC', '<a href="/lightning/app/standard__ClinicalExcellence/r/ResearchStudyCandidate/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        List<Network> communities = [SELECT Id, Name FROM Network WHERE Name = 'Makana Pharma Trial Search'];
        richTextData = richTextData.replace('MAKANA_PHARMA_TRIAL_SEARCH', '<a href="' + Network.getLoginUrl(communities[0].Id).removeEnd('/login') + '" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        
        recValue = mapRecords.get('RS_EVAL_TYPE2_DB');
        richTextData = richTextData.replace('RS_EVAL_TYPE2_DB', '<a href="/lightning/app/standard__ClinicalExcellence/r/ResearchStudyCandidate/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('RS_RHEUMATIC_DISEASE_MGMT_PROGRAM');
        richTextData = richTextData.replace('RS_RHEUMATIC_DISEASE_MGMT_PROGRAM', '<a href="/lightning/app/c__Site_Selection_Activation/r/ResearchStudy/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        
        recValue = mapRecords.get('CPE_CHARLES_GREEN_REC');
        richTextData = richTextData.replace('CPE_CHARLES_GREEN_REC', '<a href="/lightning/app/standard__PatientServiceConsole/r/CareProgramEnrollee/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        
        recValue = mapRecords.get('CPE_DIABETES_MANAGEMENT_PROGRAM_REC');
        richTextData = richTextData.replace('CPE_DIABETES_MANAGEMENT_PROGRAM_REC', '<a href="/lightning/app/standard__PatientServiceConsole/r/CareProgram/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        
        List<Network> network_sfq = [SELECT Id, Name FROM Network WHERE Name = 'SiteFeasibilityQuestionnaire'];
        richTextData = richTextData.replace('SFQ_PORTAL', '<a href="' + Network.getLoginUrl(network_sfq[0].Id).removeEnd('/login') + '" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        return richTextData;
    }

}