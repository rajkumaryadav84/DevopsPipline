global with sharing class LifeSciencesPSPBenefitVerificationTest implements System.Callable {

    public static final String SOURCE_SYSTEM_VALUE = 'Salesforce';

    global Map<String, Object> call(String action, Map<String, Object> args) {
        Map<String, Object> inputMap = (Map<String, Object>)args.get('input');
        Map<String, Object> outputMap = (Map<String, Object>)args.get('output');
        Map<String, Object> options = (Map<String, Object>)args.get('options');
        return invokeMethod(action, inputMap, outputMap, options);
    }

    class FieldNotCreatableException extends Exception {
	}

	class EntityNotCreatableException extends Exception {
	}

	class CareLimitTypeNotFundException extends Exception {
	}

	class MedicationCodeNotFoundException extends Exception {
    }

    global Map<String, Object> invokeMethod(String methodName, Map<String,Object> input,Map<String,Object> output,Map<String,Object> options) {
        try {
            switch on methodName {
                when 'saveCareBenefitVerifyRequest'
                {
                    output = saveCareBenefitVerifyRequest(input, output, options);
                }
                when 'updateCareBenefitVerifyRequest'
                {
                    output = updateCareBenefitVerifyRequest(input, output, options);
                }
                when 'resetCareBenefitVerifyRequest'
                {
                    output = resetCareBenefitVerifyRequest(input, output, options);
                }
                when 'fetchResponseBodyOfCBVR'
                {
                    output = fetchResponseBodyOfCBVR(input, output, options);
                }
                when 'updateVerificationMode'
                {
                    output = updateVerificationMode(input, output, options);
                }
            }
        } catch(Exception e) {
        	System.debug('Exception in Saving medication request' + e.getMessage());
            output.put('success', false);
            output.put('message', 'Unexpected Error');
        }
        return output;
    }

    private String createObject(String objectApiName, Map<String, Object> objecFieldstData)  {

			// Retrieve the describe information for the specified object
			Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
			if (!objectDescribe.isCreateable()) {
				throw new EntityNotCreatableException(objectApiName+ ' is not creatable');
			}
			// Get all the fields for the object
			Map<String, Schema.SObjectField> objectFieldsMap = objectDescribe.fields.getMap();

			// Create a new SObject dynamically based on the object describe
			SObject newRecord = (SObject) Type.forName(objectApiName).newInstance();

			// Iterate through the fields and set their values
        	for (String fieldName : objecFieldstData.keySet()) {
                if (objectFieldsMap.containsKey(fieldName)) {
                	Schema.DescribeFieldResult fieldDescribe = objectFieldsMap.get(fieldName).getDescribe();
                	if(!fieldDescribe.isCreateable())
                		throw new FieldNotCreatableException('Field ' + fieldName + ' field of ' + objectApiName +' is not creatable.Please check the user access for the field.');
                    newRecord.put(fieldName, objecFieldstData.get(fieldName));
                }
            }
        	insert newRecord;
        	return newRecord.Id;
    }

    private void updateObject(String objectApiName, Map<String, Object> objectFieldsData, String objectId)  {
            // Retrieve the describe information for the specified object
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
            // Get all the fields for the object
            Map<String, Schema.SObjectField> objectFieldsMap = objectDescribe.fields.getMap();
            // Get record based on id
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectApiName);
            Sobject record = targetType.newSObject();
            record.put('Id',objectId);
            // Iterate through the fields and set their values
            for (String fieldName : objectFieldsData.keySet()) {
                if (objectFieldsMap.containsKey(fieldName)) {
                    record.put(fieldName, objectFieldsData.get(fieldName));
                }
            }
            update record;
    }

    private Map<String, Object> saveCareBenefitVerifyRequest(Map<String,Object> input, Map<String,Object> output, Map<String,Object> options) {
    	output.put('success', false);
    	Savepoint sp = Database.setSavepoint();
    	try {
    		Map<String, Object> careBenefitVerifyRequest = (Map<String, Object>)input.get('careBenefitVerifyRequest');
    		if(careBenefitVerifyRequest.isEmpty()) {
    			output.put('message', 'Request data is Empty');
    			return output;
    		}
    		Map<String, Object> medicationObjectData = (Map<String, Object>)careBenefitVerifyRequest.get('MedicationObjectData');
    		if(medicationObjectData.isEmpty()) {
    			output.put('message', 'Medication data is Empty');
    			return output;
    		}

            String productId = (String)medicationObjectData.get('ProductId');
            String codeSetBundleId = getCodeSetBundleId(productId);

            if(codeSetBundleId != null && !String.isEmpty(codeSetBundleId)) {
                medicationObjectData.put('MedicationCodeId', codeSetBundleId);
            }
            else{
                throw new MedicationCodeNotFoundException('The product code is not configured. Your Salesforce admin can help with that.');
            }

    		// Create Medication object.
			String medicationObjectId = createObject('Medication', medicationObjectData);
			if(String.isEmpty(medicationObjectId)) {
				output.put('message', 'Error in creating Medication record.');
				return output;
			}
			Map<String, Object> careBenefitVerifyRequestObjectData = (Map<String, Object>)careBenefitVerifyRequest.get('CareBenefitVerifyRequestObjectData');
			if(careBenefitVerifyRequestObjectData.isEmpty()) {
				output.put('message', 'Care Benefit Verify Request data is Empty');
				return output;
			}

			Map<String, Object> medicationRequestObjectData = (Map<String, Object>)careBenefitVerifyRequest.get('MedicationRequestObjectData');
			if(medicationRequestObjectData.isEmpty()) {
				output.put('message', 'Medication Request data is Empty');
				return output;
			}
      
			medicationRequestObjectData.put('medicationId', medicationObjectId);
			if(!medicationRequestObjectData.containsKey('Status')) {
				medicationRequestObjectData.put('Status', 'Active');
			}
			if(!medicationRequestObjectData.containsKey('Type')) {
				medicationRequestObjectData.put('Type', 'Proposal');
			}
            
            Datetime currentYearEndDateTime = Datetime.newInstance(Date.today().year(), 12, 31, 23, 59, 59);
			medicationRequestObjectData.put('PrescribedDate',dateTime.now());
            if(!medicationRequestObjectData.containsKey('PrescriptionPeriodEnd')) {
                medicationRequestObjectData.put('PrescriptionPeriodEnd', currentYearEndDateTime);
            } else {
                medicationRequestObjectData.put('PrescriptionPeriodEnd',Datetime.valueOf((String)medicationRequestObjectData.get('PrescriptionPeriodEnd')));   
            }

			// Create medication request object.
			String medicationRequestId = createObject('MedicationRequest', medicationRequestObjectData);
			if(String.isEmpty(medicationRequestId)) {
				output.put('message', 'Error in creating Medication Request record.');
				return output;
			}

			// Create identifier object.
			Map<String, Object> identifierObject = new Map<String,Object>();
			MedicationRequest medicationRequestRecord = [SELECT Name FROM MedicationRequest WHERE Id = :medicationRequestId LIMIT 1];
			identifierObject.put('IdValue', medicationRequestRecord.Name);
			identifierObject.put('SourceSystem', SOURCE_SYSTEM_VALUE);
			identifierObject.put('ParentRecordId', medicationRequestId);

			String identifierId = createObject('Identifier', identifierObject);
			if(String.isEmpty(identifierId)) {
				output.put('message', 'Error in creating Identifier record.');
				return output;
			}

			careBenefitVerifyRequestObjectData.put('AuthorizedPrescriptionId', medicationRequestId);

			// create coverage Benefit object.
			Map<String, Object> coverageBenefitObjectData = (Map<String, Object>)careBenefitVerifyRequest.get('CoverageBenefitObjectData');
			if(!coverageBenefitObjectData.containsKey('VerificationDate')) {
				coverageBenefitObjectData.put('VerificationDate', dateTime.now());
			}
			String coverageBenefitId = createObject('CoverageBenefit', coverageBenefitObjectData);

			Map<String, Object> coverageBenefitItemObjectData = (Map<String, Object>)careBenefitVerifyRequest.get('CoverageBenefitItemObjectData');
			coverageBenefitItemObjectData.put('coverageBenefitId', coverageBenefitId);

			// create coverage benefit item object.
			String coverageBenefitItemId = createObject('CoverageBenefitItem', coverageBenefitItemObjectData);

			// create coverage benefit item limit objects.
			Map<String, Object> coverageBenefitItemLimitObjectData = (Map<String, Object>)careBenefitVerifyRequest.get('CoverageBenefitItemLimitObjectData');
			for(String key:coverageBenefitItemLimitObjectData.keySet()) {
				List<CareLimitType> careLimitTypes = getCareLimitTypeObject(key);
				if(careLimitTypes.isEmpty()) {
				 	throw new CareLimitTypeNotFundException('Care Limit Type ' + key + ' not Found Exception');
				}
				Map<String, Object> coverageBenefitItemLimitData = (Map<String, Object>)coverageBenefitItemLimitObjectData.get(key);
				coverageBenefitItemLimitData.put('coverageBenefitItemId', coverageBenefitItemId);
				coverageBenefitItemLimitData.put('careLimitTypeId', careLimitTypes[0].Id);
				createObject('CoverageBenefitItemLimit', coverageBenefitItemLimitData);
			}


			careBenefitVerifyRequestObjectData.put('coverageBenefitId', coverageBenefitId);
			careBenefitVerifyRequestObjectData.put('coverageBenefitItemId', coverageBenefitItemId);
			careBenefitVerifyRequestObjectData.put('RequestDate', dateTime.now());

			String careBenefitVerifyRequestId= createObject('CareBenefitVerifyRequest', careBenefitVerifyRequestObjectData);
			List<CoverageBenefit> coverageBenefit = [SELECT Id, CareBenefitVerifyRequestId FROM CoverageBenefit WHERE Id = :coverageBenefitId];

			if(coverageBenefit!=null) {
			    coverageBenefit[0].CareBenefitVerifyRequestId = careBenefitVerifyRequestId;
			    update coverageBenefit;
			}

			output.put('success', true);
			output.put('message', 'Care Benefit Request Object created successfully.');
			//returning objects created for input json for submitPharmacyBenefitVerification API
			if(careBenefitVerifyRequestObjectData.get('verificationMode') == 'Electronic')
			{
			    Map<String,Object> json = new Map<String,Object>();
			    json.put('cbvrId',careBenefitVerifyRequestId);
			    json.put('memberPlanId',careBenefitVerifyRequestObjectData.get('memberPlanId'));
			    json.put('providerId',careBenefitVerifyRequestObjectData.get('ProviderId'));
			    json.put('medicationRequestId',medicationRequestId);
			    json.put('medicationId',medicationObjectId);
			    json.put('prescriberId', careBenefitVerifyRequestObjectData.get('PrescriberId'));
			    output.put('json',json);
			}

		} catch(Exception e) {
			Database.rollback(sp);
			output.put('message', e.getMessage());
		}
      	return output;
    }

    private List<CareLimitType> getCareLimitTypeObject(String limitType) {
        List<CareLimitType> careLimitTypeIds= [Select Id from CareLimitType where LimitType = :limitType];
        return careLimitTypeIds;
    }

    private Map<String, Object> updateCareBenefitVerifyRequest(Map<String,Object> input, Map<String,Object> output, Map<String,Object> options) {
        output.put('success', false);
        Savepoint sp = Database.setSavepoint();
        try {
            Map<String, Object> careBenefitVerifyRequest = (Map<String, Object>)input.get('careBenefitVerifyRequest');
            Map<String, Object> careBenefitVerifyRequestData = new Map<String, Object>();
            if(careBenefitVerifyRequest.isEmpty()) {
                careBenefitVerifyRequestData.put('status', 'Error');
                careBenefitVerifyRequestData.put('statusReason', 'Request could not be sent');
                careBenefitVerifyRequestData.put('responseContentType', 'application/json');
                careBenefitVerifyRequestData.put('responseName', 'ERROR');
                Blob responseBodyBlob = Blob.valueof('Response data from mule is Empty');
                careBenefitVerifyRequestData.put('responseBody', responseBodyBlob);
                output.put('status', 'Error');
                output.put('message', 'Response data from mule is Empty');
                return output;
            }

            if(careBenefitVerifyRequest.containsKey('status')){
                String status = String.valueOf(careBenefitVerifyRequest.get('status'));
                careBenefitVerifyRequestData.put('statusReason', careBenefitVerifyRequest.get('summary'));
                if(status == 'acknowledged'){
                    careBenefitVerifyRequestData.put('status', 'Acknowledged');
                    careBenefitVerifyRequestData.put('responseContentType', null);
                    careBenefitVerifyRequestData.put('responseName', null);
                    careBenefitVerifyRequestData.put('responseBody', null);
                    output.put('status', 'Acknowledged');
                }else if (status == 'error'){
                    careBenefitVerifyRequestData.put('status', 'Error');
                    Map<String, Object> careBenefitVerifyRequestErrorData = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(careBenefitVerifyRequest.get('error')));
                    String jsonString = JSON.serialize(careBenefitVerifyRequest);
                    Blob responseBodyBlob = Blob.valueof(jsonString);
                    careBenefitVerifyRequestData.put('responseContentType', 'application/json');
                    careBenefitVerifyRequestData.put('responseName', careBenefitVerifyRequestErrorData.get('errorCode'));
                    careBenefitVerifyRequestData.put('responseBody', responseBodyBlob);
                    output.put('status', 'Error');
                }
            }else{
                    careBenefitVerifyRequestData.put('status', 'Error');
                    careBenefitVerifyRequestData.put('statusReason', 'Request could not be sent');
                    careBenefitVerifyRequestData.put('responseContentType', 'application/json');
                    careBenefitVerifyRequestData.put('responseName', 'ERROR');
                    Blob responseBodyBlob = Blob.valueof('Request could not be sent');
                    careBenefitVerifyRequestData.put('responseBody', responseBodyBlob);
                    output.put('status', 'Error');
            }
            updateObject('CareBenefitVerifyRequest', careBenefitVerifyRequestData, (String)careBenefitVerifyRequest.get('Id'));
            output.put('success', true);
            output.put('message', 'Care Benefit Request updated successfully.');
        } catch(Exception e) {
            Database.rollback(sp);
            output.put('success', false);
            output.put('message', e.getMessage());
        }
        return output;
    }

  private Map<String, Object> resetCareBenefitVerifyRequest(Map<String,Object> input, Map<String,Object> output, Map<String,Object> options) {
        output.put('success', false);
        Savepoint sp = Database.setSavepoint();
        try {
           Map<String, Object> careBenefitVerifyRequest = (Map<String, Object>)input.get('careBenefitVerifyRequest');
            if(careBenefitVerifyRequest.isEmpty()) {
                output.put('message', 'Nothing to reset');
                return output;
            }
            Map<String, Object> careBenefitVerifyRequestData = new Map<String, Object>();
            if(careBenefitVerifyRequest.containsKey('verificationMode')){
                String verificationMode = String.valueOf(careBenefitVerifyRequest.get('verificationMode'));
                //Resetting to manual verification
                if(verificationMode == 'Manual'){
                     careBenefitVerifyRequestData.put('verificationMode', careBenefitVerifyRequest.get('verificationMode'));
                     careBenefitVerifyRequestData.put('status', '');
                     careBenefitVerifyRequestData.put('statusReason', '');
                     careBenefitVerifyRequestData.put('responseContentType', null);
                     careBenefitVerifyRequestData.put('responseName', null);
                     careBenefitVerifyRequestData.put('responseBody', null);
                }
            }

            updateObject('CareBenefitVerifyRequest', careBenefitVerifyRequestData, (String)careBenefitVerifyRequest.get('Id'));
            output.put('success', true);
            output.put('message', 'Care Benefit Request reset successfully.');

        } catch(Exception e) {
            Database.rollback(sp);
            output.put('success', false);
            output.put('message', e.getMessage());
        }
        return output;
    }


    private Map<String, Object> fetchResponseBodyOfCBVR(Map<String,Object> input, Map<String,Object> output, Map<String,Object> options) {
        output.put('success', false);
        Savepoint sp = Database.setSavepoint();
        try {
           Map<String, Object> careBenefitVerifyRequest = (Map<String, Object>)input.get('cbvr');
            if(careBenefitVerifyRequest.isEmpty()) {
                output.put('message', 'Nothing to extract');
                return output;
            }

            if(careBenefitVerifyRequest.containsKey('id')){
               String careBenefitVerifyRequestId = (String)careBenefitVerifyRequest.get('id');
               List<CareBenefitVerifyRequest> careBenefitVerifyRequestList = [SELECT ResponseBody FROM CareBenefitVerifyRequest WHERE Id = :careBenefitVerifyRequestId LIMIT 1];
               if(careBenefitVerifyRequestList.size() > 0){
                   CareBenefitVerifyRequest cbvr = careBenefitVerifyRequestList.get(0);
                   if(cbvr != null){
                       Object responseBodyObj = cbvr.get('ResponseBody');
                       if(responseBodyObj != null){
                           String decodedString = responseBodyObj.toString();
                           Map<String, Object> careBenefitVerifyRequestData = (Map<String, Object>)JSON.deserializeUntyped(decodedString);
                           if(careBenefitVerifyRequestData.containsKey('error')){
                               Map<String, Object> careBenefitVerifyRequestErrorData = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(careBenefitVerifyRequestData.get('error')));
                               if(careBenefitVerifyRequestErrorData.containsKey('errorMessage')){
                                   output.put('errorMessage', careBenefitVerifyRequestErrorData.get('errorMessage'));
                                   output.put('success', true);
                                   output.put('message', 'Error message fetched successfully.');
                               }
                           }
                       }
                   }
               }
            }
            output.put('success', false);
            output.put('message', 'Error message could not be fetched successfully.');
        } catch(Exception e) {
            Database.rollback(sp);
            output.put('success', false);
            output.put('message', e.getMessage());
        }
        return output;
    }

    private String getCodeSetBundleId(String productId) {
        if(productId == null || String.isEmpty(productId)){
            return '';
        }
        Product2 product = [SELECT ProductCode FROM Product2 WHERE Id = :productId LIMIT 1];
        List<CodeSet> codeSets = [SELECT Id FROM CodeSet WHERE Code = :product.ProductCode LIMIT 1];
        if(codeSets.isEmpty()){
            return '';
        }
        String codeSetId = codeSets.get(0).Id;
        if(codeSetId == null || String.isEmpty(codeSetId)){
            return '';
        }
        List<String> codeSetIds = new List<String>();
        codeSetIds.add(codeSetId);
        return '0iPWs000000SEODMA4';
    }

    private Map<String, Object> updateVerificationMode(Map<String,Object> input, Map<String,Object> output, Map<String,Object> options){
        Savepoint sp = Database.setSavepoint();
        output.put('success', 'false');
        try{
                String cbvrId = (String)input.get('cbvrId');
                String verificationMode = (String)input.get('verificationMode');
                Map<String, Object> careBenefitVerifyRequestData = new Map<String, Object>();
                careBenefitVerifyRequestData.put('verificationmode',verificationMode);
                updateObject('CareBenefitVerifyRequest', careBenefitVerifyRequestData, cbvrId);
                output.put('success','true');
                output.put('message', 'Care Benefit Request verification mode updated successfully.');
                return output;
        }
        catch(Exception e){
            Database.rollback(sp);
            output.put('success', 'false');
            output.put('message', e.getMessage());
        }
        return output;
    }
}