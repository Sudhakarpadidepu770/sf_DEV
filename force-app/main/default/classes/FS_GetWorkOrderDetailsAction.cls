/**
 * Agentforce action: retrieves details for a Work Order by its Work Order Number or the related Case Number.
 * Input: workOrderNumber (optional), caseNumber (optional) — at least one is required.
 * Output: a single Result — found=false when no match exists.
 */
public with sharing class FS_GetWorkOrderDetailsAction {

    public class Request {
        @InvocableVariable(label='Work Order Number' description='Optional. e.g. WO-0001025.')
        public String workOrderNumber;
        @InvocableVariable(label='Case Number' description='Optional. Looks up the Work Order created from this Case.')
        public String caseNumber;
    }

    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String workOrderNumber;
        @InvocableVariable public String subject;
        @InvocableVariable public String status;
        @InvocableVariable public String priority;
        @InvocableVariable public String workType;
        @InvocableVariable public String assetName;
        @InvocableVariable public String caseNumber;
        @InvocableVariable public String requiredSkills;
    }

    @InvocableMethod(
        label='Get Work Order Details'
        description='Returns details for a Work Order looked up by Work Order Number or the originating Case Number.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.found = false;
            try {
                List<WorkOrder> matches = new List<WorkOrder>();
                if (String.isNotBlank(r.workOrderNumber)) {
                    matches = [
                        SELECT WorkOrderNumber, Subject, Status, Priority, WorkType.Name, Asset.Name, Case.CaseNumber, WorkTypeId
                        FROM WorkOrder WHERE WorkOrderNumber = :r.workOrderNumber WITH USER_MODE LIMIT 1
                    ];
                } else if (String.isNotBlank(r.caseNumber)) {
                    matches = [
                        SELECT WorkOrderNumber, Subject, Status, Priority, WorkType.Name, Asset.Name, Case.CaseNumber, WorkTypeId
                        FROM WorkOrder WHERE Case.CaseNumber = :r.caseNumber WITH USER_MODE LIMIT 1
                    ];
                }
                if (!matches.isEmpty()) {
                    WorkOrder wo = matches[0];
                    List<String> skills = new List<String>();
                    for (SkillRequirement sr : [SELECT Skill.MasterLabel FROM SkillRequirement WHERE RelatedRecordId = :wo.WorkTypeId WITH USER_MODE]) {
                        skills.add(sr.Skill.MasterLabel);
                    }
                    res.found = true;
                    res.workOrderNumber = wo.WorkOrderNumber;
                    res.subject = wo.Subject;
                    res.status = wo.Status;
                    res.priority = wo.Priority;
                    res.workType = wo.WorkType != null ? wo.WorkType.Name : null;
                    res.assetName = wo.Asset != null ? wo.Asset.Name : null;
                    res.caseNumber = wo.Case != null ? wo.Case.CaseNumber : null;
                    res.requiredSkills = String.join(skills, ', ');
                }
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(res);
        }
        return out;
    }
}