/**
 * Agentforce action: creates a Work Order from an existing Case, using the Service_Category_Mapping__mdt
 * configuration to resolve the correct Work Type, priority, and duration — mirrors the logic in the
 * Case_To_Work_Order_Creation Flow, for cases where an agent needs to trigger creation directly rather
 * than via the Case Status='Working' automation.
 * Input: caseNumber (required).
 * Output: a single Result row describing success/failure and the resulting Work Order Number.
 */
public with sharing class FS_CreateWorkOrderAction {

    public class Request {
        @InvocableVariable(required=true label='Case Number' description='e.g. 00001025.')
        public String caseNumber;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String workOrderNumber;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Create Work Order From Case'
        description='Creates a Work Order from an existing Case using the configured service-category-to-work-type mapping.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.success = false;
            try {
                List<Case> cases = [
                    SELECT Id, Subject, AssetId, Service_Category__c
                    FROM Case WHERE CaseNumber = :r.caseNumber WITH USER_MODE LIMIT 1
                ];
                if (cases.isEmpty()) {
                    res.message = 'No Case found with that number.';
                    out.add(res);
                    continue;
                }
                Case c = cases[0];

                List<WorkOrder> existing = [SELECT Id, WorkOrderNumber FROM WorkOrder WHERE CaseId = :c.Id WITH USER_MODE LIMIT 1];
                if (!existing.isEmpty()) {
                    res.success = true;
                    res.workOrderNumber = existing[0].WorkOrderNumber;
                    res.message = 'A Work Order already exists for this Case.';
                    out.add(res);
                    continue;
                }

                if (String.isBlank(c.Service_Category__c)) {
                    res.message = 'This Case has no Service Category set, so a Work Type cannot be resolved.';
                    out.add(res);
                    continue;
                }

                List<Service_Category_Mapping__mdt> mappings = [
                    SELECT Default_Work_Type_Name__c, Default_Priority__c
                    FROM Service_Category_Mapping__mdt
                    WHERE Service_Category_API_Value__c = :c.Service_Category__c AND Is_Active__c = true
                    LIMIT 1
                ];
                if (mappings.isEmpty()) {
                    res.message = 'No active service category mapping found for "' + c.Service_Category__c + '".';
                    out.add(res);
                    continue;
                }

                List<WorkType> workTypes = [SELECT Id FROM WorkType WHERE Name = :mappings[0].Default_Work_Type_Name__c WITH USER_MODE LIMIT 1];
                if (workTypes.isEmpty()) {
                    res.message = 'The mapped Work Type "' + mappings[0].Default_Work_Type_Name__c + '" was not found.';
                    out.add(res);
                    continue;
                }

                WorkOrder wo = new WorkOrder(
                    Subject = c.Subject,
                    CaseId = c.Id,
                    AssetId = c.AssetId,
                    WorkTypeId = workTypes[0].Id,
                    Priority = mappings[0].Default_Priority__c,
                    Status = 'New'
                );
                Database.insert(wo, AccessLevel.USER_MODE);

                WorkOrder created = [SELECT WorkOrderNumber FROM WorkOrder WHERE Id = :wo.Id WITH USER_MODE];
                res.success = true;
                res.workOrderNumber = created.WorkOrderNumber;
                res.message = 'Work Order created successfully.';
            } catch (Exception e) {
                res.message = 'Could not create the Work Order right now.';
            }
            out.add(res);
        }
        return out;
    }
}