global with sharing class FinancialAssistanceAppeal implements System.Callable {
    public Object call(String action, Map<String, Object> args) {
 
        Map<String, Object> inputMap = (Map<String, Object>)args.get('input');
        Map<String, Object> outputMap = (Map<String, Object>)args.get('output');
 
        if(action == 'createCaseServiceRequest') {
            return createCaseServiceRequest(inputMap, outputMap);
        } else if(action == 'updateCaseServiceProcessStatus') {
            return updateCaseServiceProcessStatus(inputMap, outputMap);
        } else if(action == 'getApplicationStageAndStepStatus') {
            return getApplicationStageAndStepStatus(inputMap, outputMap);
        } else if(action == 'getReapplyApplicationFormStatus') {
            return getReapplyApplicationFormStatus(inputMap, outputMap);
        }
 
        return null;
    }
 
    private Object createCaseServiceRequest(Map<String, Object> inputMap, Map<String, Object> outputMap) {
        // retrieve the attributes from the request payload
        String applicationForm = (String)inputMap.get('ApplicationForm');
        String appealDate = (String)inputMap.get('AppealDate');
        String description = (String)inputMap.get('Description');
        String type = (String)inputMap.get('Type');
        String status = (String)inputMap.get('Status');
        String applicationRejectReason = (String)inputMap.get('AppealReason');
        String svcCatalogItemDefApiName = (String)inputMap.get('svcCatalogItemDefApiName');
 
 
        // Set the input rep
        ConnectApi.ServiceProcessRequestInputRepresentation input = new ConnectApi.ServiceProcessRequestInputRepresentation();
        input.svcCatalogItemDefApiName = svcCatalogItemDefApiName;
        input.caseInfo = new Map<String, ConnectApi.GenericObject>();
        input.attributes = new Map<String, ConnectApi.GenericObject>();
 
        // set attributes
        ConnectApi.GenericObject applicationRejectReasonObj = new ConnectApi.GenericObject();
        applicationRejectReasonObj.value = applicationRejectReason;
        input.attributes.put('ApplicationRejectReason', applicationRejectReasonObj);
 
        ConnectApi.GenericObject applicationFormObj = new ConnectApi.GenericObject();
        applicationFormObj.value = applicationForm;
        input.attributes.put('ApplicationForm', applicationFormObj);
 
        ConnectApi.GenericObject appealDateObj = new ConnectApi.GenericObject();
        appealDateObj.value = appealDate;
        input.attributes.put('AppealDate', appealDateObj);
 
        ConnectApi.GenericObject descriptionObj = new ConnectApi.GenericObject();
        descriptionObj.value = description;
        input.attributes.put('Description', descriptionObj);
 
        ConnectApi.GenericObject typeObj = new ConnectApi.GenericObject();
        typeObj.value = type;
        input.attributes.put('Type', typeObj);
 
        ConnectApi.GenericObject statusObj = new ConnectApi.GenericObject();
        statusObj.value = status;
        input.attributes.put('Status', statusObj);
        
        ConnectApi.GenericObject caseOwnerObj = new ConnectApi.GenericObject();
        caseOwnerObj.value = '005Ws000003aMzaIAE';
        input.caseInfo.put('OwnerId', caseOwnerObj);
 
        // Invoke API
        Map<String, String> responseMap = new Map<String, String>();
        //calling connect API
        ConnectApi.ServiceProcessRepresentation output = ConnectApi.IServiceProcessConnectFamily.createCaseServiceProcess(input);
 
        if(output != null) {
            responseMap.put('caseId', output.caseId);
            responseMap.put('caseNumber', output.caseNumber);
            responseMap.put('svcCatalogRequestId', output.svcCatalogRequestId);
        }
 
        outputMap.put('apiResponse', responseMap);
        System.debug(responseMap);
        return outputMap;
    }
 
    private Object updateCaseServiceProcessStatus(Map<String, Object> inputMap, Map<String, Object> outputMap) {
        String svcCatalogRequestId = (String)inputMap.get('svcCatalogRequestId');
        String catalogReqStatus = (String)inputMap.get('catalogReqStatus');
        String caseStatus = (String)inputMap.get('caseStatus');
        String applicationFormId = (String)inputMap.get('applicationFormId');
        String caseId = (String)inputMap.get('caseId');
        String svcCatalogItemDefApiName = (String)inputMap.get('svcCatalogItemDefApiName');
 
        // Set the input rep
        ConnectApi.ServiceProcessRequestInputRepresentation input = new ConnectApi.ServiceProcessRequestInputRepresentation();
        input.svcCatalogItemDefApiName = svcCatalogItemDefApiName;
        input.caseInfo = new Map<String, ConnectApi.GenericObject>();
        input.attributes = new Map<String, ConnectApi.GenericObject>();
 
         // set case status
        ConnectApi.GenericObject caseStatusObj = new ConnectApi.GenericObject();
        caseStatusObj.value = caseStatus;
        input.caseInfo.put('Status', caseStatusObj);
 
        // set catalog req status
        ConnectApi.GenericObject catalogReqStatusObj = new ConnectApi.GenericObject();
        catalogReqStatusObj.value = catalogReqStatus;
        input.attributes.put('Status', catalogReqStatusObj);
 
        // Invoke API
        Map<String, String> responseMap = new Map<String, String>();
        //calling connect API
        ConnectApi.ServiceProcessRepresentation output = ConnectApi.IServiceProcessConnectFamily.updateCaseServiceProcesses(input, svcCatalogRequestId);
 
        if(output != null) {
            responseMap.put('svcCatalogRequestId', output.svcCatalogRequestId);
        }
		publishPlatformEvent(catalogReqStatus, applicationFormId, caseId);
        outputMap.put('apiResponse', responseMap);
        outputMap.put('currentDateTime', DateTime.now());
        return outputMap;
    }
 
    private Object getApplicationStageAndStepStatus(Map<String, Object> inputMap, Map<String, Object> outputMap) {
        if(inputMap.get('ProgramDetails') == null) {
            return null;
        }
 
        Map<String, Object> programDetails = (Map<String, Object>)inputMap.get('ProgramDetails');
        List<Map<String, Object>> stages = (List<Map<String, Object>>) programDetails.get('Stage');
 
        // Map to store the latest stage based on stage name
        Map<String, Map<String, Object>> latestStagesMap = new Map<String, Map<String, Object>>();
 
        // Iterate over each stage and store the latest one based on stage name
        for (Map<String, Object> stage : stages) {
            String stageName = (String) stage.get('StageName');
            // Ignore stages with name CheckAppealStatus
            if (stageName != 'CheckAppealStatus') {
                latestStagesMap.put(stageName, stage); // This will replace any existing stage with the same name
            }
        }
 
        // Reconstruct JSON with only the latest stages
        programDetails.put('Stage', latestStagesMap.values());
 
        stages = (List<Map<String, Object>>) programDetails.get('Stage');
        Integer exceptionStepNumber = -1;
        String exceptionMessage = '';
        if(programDetails.get('ProcessException') != null) {
            List<Map<String, Object>> processException = (List<Map<String, Object>>)programDetails.get('ProcessException');
            if(processException.size() > 0){
                exceptionStepNumber = Integer.valueOf((String)processException[processException.size()-1].get('StepNumber'));
                exceptionMessage = (String)processException[processException.size()-1].get('Message');
            }
        }
 
        Integer totalSteps = 0;
        for(Map<String, Object> stage : stages) {
            List<Map<String, Object>> steps = (List<Map<String, Object>>)stage.get('Step');
            for(Map<String, Object> step : steps) {
                totalSteps++;
            }
        }
 
        Integer currentStepNumber = 0;
        String error;
        Boolean isAppealApplicable = false;
        String lastStepName;
        for(Map<String, Object> stage : stages) {
            List<Map<String, Object>> steps = (List<Map<String, Object>>)stage.get('Step');
            String lastStepStatus;
            for(Map<String, Object> step : steps) {
                currentStepNumber++;
                // Add Error message status and step status based on step numbers and exception step number
                if(currentStepNumber > exceptionStepNumber) {
            		step.put('ErrorMessageStatus', (String)step.get('StepStatus'));
                } else if(currentStepNumber == exceptionStepNumber) {
                    if(totalSteps > exceptionStepNumber) {
                        step.put('StepStatus', 'Completed');
						step.put('ErrorMessageStatus', 'Completed');
                    } else {
                        step.put('ErrorMessage', exceptionMessage);
                        error = exceptionMessage;
                        step.put('ErrorMessageStatus', 'Rejected');
                        step.put('StepStatus', 'Rejected');
                    }
                } else {
                    step.put('StepStatus', 'Completed');
                    step.put('ErrorMessageStatus', 'Completed');
                }
                lastStepStatus = (String)step.get('StepStatus');
                lastStepName = (String)step.get('StepName');
            }
 
            // If last step status of that stage is completed, mark stage as completed else mark it according to last step status
            if(lastStepStatus == 'Completed') {
                stage.put('StageStatus', 'Completed');
                stage.put('StageMessageStatus', 'Completed');
            } else {
                if(lastStepStatus == 'Rejected') {
                    lastStepStatus = 'Failed';
                }
                stage.put('StageStatus', lastStepStatus);
                stage.put('StageMessageStatus', lastStepStatus);
            }
            stage.put('Expanded', false);
        }
 
 
        // Error field is used to auto populate the rejection reason when File Appeal button is clicked
        programDetails.put('Error', error);
 
        // Add is appealApplicable based on last step name
        if(lastStepName == 'VerifyCommercialHealthInsurance' || lastStepName == 'VerifyDrugBenefits' || lastStepName == 'VerifyProgramEligibility') {
            isAppealApplicable = true;
        }
 
        programDetails.put('isAppealApplicable', isAppealApplicable);
        String createdDateInString = (String)programDetails.get('CreatedDate');
		Datetime createdDate = (DateTime)JSON.deserialize('"' + createdDateInString + '"', DateTime.class);
        programDetails.put('showReapply', showReapplyApplicationForm(exceptionStepNumber, (Integer)programDetails.get('totalAppeals'),
                                                                    createdDate, (String)programDetails.get('ApplicationFormStatus')
                                                                     ,(Integer)programDetails.get('appealLimit'),
                                                                     (Integer)inputMap.get('ReapplyTimeout'), (Boolean)inputMap.get('DiffInDays'),
                                                                    (Boolean)programDetails.get('appealTimeout')));
        outputMap.put('programDetails', programDetails);
        return outputMap;
    }
 
    private Object getReapplyApplicationFormStatus(Map<String, Object> inputMap, Map<String, Object> outputMap) {
        if(inputMap.get('programDetails') != null) {
            Map<String, Object> programDetails = (Map<String, Object>)inputMap.get('programDetails');
            if(programDetails.get('Status') != null) {
                String applicationStatus = (String)programDetails.get('Status');
                Datetime applicationCreatedDate = (Datetime)programDetails.get('CreatedDate');
                Integer applicationAppealLimit = Integer.valueOf(programDetails.get('appealLimit'));
                Integer totalAppeals = Integer.valueOf(programDetails.get('totalAppeals'));
                Integer exceptionNumber = -1;
                if(programDetails.get('ProcessException') != null) {
                    List<Map<String, Object>> processException = (List<Map<String, Object>>)programDetails.get('ProcessException');
                    if(processException.size() > 0){
                        exceptionNumber = Integer.valueOf((String)processException[processException.size()-1].get('StepNumber'));
                    }
                }
 
                Integer reapplyTimeout = Integer.valueOf(inputMap.get('ReapplyTimeout'));
                Boolean svcCatalogAppealTimeout = Boolean.valueOf(programDetails.get('appealTimeout'));
                Boolean diffInDays = Boolean.valueOf(inputMap.get('DiffInDays'));
 
                outputMap.put('showReapply', showReapplyApplicationForm(exceptionNumber, totalAppeals, applicationCreatedDate,
                                                                   applicationStatus, applicationAppealLimit, reapplyTimeout,
                                                                    diffInDays, svcCatalogAppealTimeout));
            }
        }
 
        return outputMap;
    }
 
    private Boolean showReapplyApplicationForm(Integer processExceptionNumber, Integer totalAppeals, Datetime createdDate,
                                               String applicationStatus, Integer applicationAppealLimit,
                                               Integer appealTimeout, Boolean diffInDays, Boolean svcCatalogAppealTimeout) {
        if(applicationStatus == 'Rejected') {
            // If Application Appeal Limit is exhausted, show reapply
            if(totalAppeals >= applicationAppealLimit) {
            	return true;
        	}
 
            // If appeal has been timeout by flow and svc catalog status is updated, directly return true to show reapply.
            if(svcCatalogAppealTimeout) {
                return true;
            }
 
            Long denominator = 1000 * 60 * 60;
            if(diffInDays) {
                denominator =  denominator * 24;
            }
 
            Long differenceInMillis = Math.abs(DateTime.now().getTime() - createdDate.getTime());
 
            // If time difference between Application Form Created Date and Current Time is >= appelaTimeout given by Admin, return true to show reapply.
            if((Integer)(differenceInMillis / denominator ) >= appealTimeout) {
                return true;
            }
 
            // If process exception number is greater than 3, which means it failed either at benefit assignment or disbursement, we would show reapply.
            if(processExceptionNumber > 3) {
                return true;
            }
        }
 
        return false;
    }
 
 
    private void publishPlatformEvent(String status, String applicationFormId, String appealId) {
        ApplnFormAppealStsChgEvnt event = new ApplnFormAppealStsChgEvnt(AppealStatus =status,
                                                                        ApplicationFormIdentifier=applicationFormId,
                                                                        AppealIdentifier=appealId,EventCreationDateTime=Datetime.now());
 
		Database.SaveResult sr = EventBus.publish(event);
 
        if (sr.isSuccess()) {
            System.debug('Successfully published event.');
        } else {
            for(Database.Error err : sr.getErrors()) {
                System.debug('Error returned: ' +
                            err.getStatusCode() +
                            ' - ' +
                            err.getMessage());
            }
		}
    }
}