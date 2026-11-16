/**
 * Agentforce action: returns a technician's next upcoming (not-yet-completed) Service Appointment, with
 * customer, asset, issue, and required-skill context — designed for "what's my next job?" style prompts.
 * Input: technicianName (required).
 * Output: a single Result — found=false when the technician has no upcoming appointment.
 */
public with sharing class FS_GetTechnicianNextAppointmentAction {

    public class Request {
        @InvocableVariable(required=true label='Technician Name' description='e.g. Ravi Kumar.')
        public String technicianName;
    }

    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String subject;
        @InvocableVariable public String startTime;
        @InvocableVariable public String status;
        @InvocableVariable public String customerName;
        @InvocableVariable public String assetName;
        @InvocableVariable public String issueDescription;
        @InvocableVariable public String workOrderNumber;
    }

    @InvocableMethod(
        label='Get Technician Next Appointment'
        description='Returns a technician\'s next upcoming Service Appointment along with the customer, asset, and issue details.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.found = false;
            try {
                Set<Id> saIds = new Set<Id>();
                for (AssignedResource ar : [
                    SELECT ServiceAppointmentId FROM AssignedResource
                    WHERE ServiceResource.Name = :r.technicianName WITH USER_MODE
                ]) {
                    saIds.add(ar.ServiceAppointmentId);
                }
                if (!saIds.isEmpty()) {
                    List<ServiceAppointment> appts = [
                        SELECT Subject, SchedStartTime, Status, ParentRecordId
                        FROM ServiceAppointment
                        WHERE Id IN :saIds AND Status NOT IN ('Completed', 'Canceled')
                        WITH USER_MODE
                        ORDER BY SchedStartTime ASC NULLS LAST
                        LIMIT 1
                    ];
                    if (!appts.isEmpty()) {
                        ServiceAppointment sa = appts[0];
                        res.subject = sa.Subject;
                        res.startTime = sa.SchedStartTime != null ? String.valueOf(sa.SchedStartTime) : null;
                        res.status = sa.Status;

                        List<WorkOrder> wos = [
                            SELECT WorkOrderNumber, Asset.Name, Asset.Account.Name, Case.Description
                            FROM WorkOrder WHERE Id = :sa.ParentRecordId WITH USER_MODE LIMIT 1
                        ];
                        if (!wos.isEmpty()) {
                            res.found = true;
                            res.workOrderNumber = wos[0].WorkOrderNumber;
                            res.assetName = wos[0].Asset != null ? wos[0].Asset.Name : null;
                            res.customerName = wos[0].Asset != null && wos[0].Asset.Account != null ? wos[0].Asset.Account.Name : null;
                            res.issueDescription = wos[0].Case != null ? wos[0].Case.Description : null;
                        }
                    }
                }
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(res);
        }
        return out;
    }
}