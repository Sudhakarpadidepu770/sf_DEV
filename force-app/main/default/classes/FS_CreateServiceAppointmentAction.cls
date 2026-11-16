/**
 * Agentforce action: creates a Service Appointment for an existing Work Order in a given territory.
 * Input: workOrderNumber (required), territoryName (required), schedStartTime (optional, ISO datetime string).
 * Output: a single Result row describing success/failure.
 */
public with sharing class FS_CreateServiceAppointmentAction {

    public class Request {
        @InvocableVariable(required=true label='Work Order Number' description='e.g. WO-0001025.')
        public String workOrderNumber;
        @InvocableVariable(required=true label='Territory' description='e.g. Guntur, Vijayawada, Visakhapatnam, Tirupati, Hyderabad.')
        public String territoryName;
        @InvocableVariable(label='Scheduled Start Time' description='Optional. ISO datetime, e.g. 2026-09-23T10:00:00Z. If omitted, the appointment is created unscheduled.')
        public String schedStartTime;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String serviceAppointmentId;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Create Service Appointment'
        description='Creates a Service Appointment for an existing Work Order in the given territory, optionally with a scheduled start time.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.success = false;
            try {
                List<WorkOrder> wos = [
                    SELECT Id, Subject, WorkType.EstimatedDuration
                    FROM WorkOrder WHERE WorkOrderNumber = :r.workOrderNumber WITH USER_MODE LIMIT 1
                ];
                if (wos.isEmpty()) {
                    res.message = 'No Work Order found with that number.';
                    out.add(res);
                    continue;
                }
                List<ServiceTerritory> territories = [SELECT Id FROM ServiceTerritory WHERE Name = :r.territoryName WITH USER_MODE LIMIT 1];
                if (territories.isEmpty()) {
                    res.message = 'No Service Territory found with that name.';
                    out.add(res);
                    continue;
                }

                ServiceAppointment sa = new ServiceAppointment(
                    ParentRecordId = wos[0].Id,
                    Subject = wos[0].Subject,
                    ServiceTerritoryId = territories[0].Id,
                    Duration = wos[0].WorkType != null ? wos[0].WorkType.EstimatedDuration : null,
                    DurationType = 'Minutes'
                );
                Database.insert(sa, AccessLevel.USER_MODE);

                if (String.isNotBlank(r.schedStartTime)) {
                    DateTime start;
                    try { start = (DateTime) JSON.deserialize('"' + r.schedStartTime + '"', DateTime.class); } catch (Exception ignore) {}
                    if (start != null) {
                        sa.SchedStartTime = start;
                        sa.SchedEndTime = start.addMinutes(wos[0].WorkType != null && wos[0].WorkType.EstimatedDuration != null ? Integer.valueOf(wos[0].WorkType.EstimatedDuration) : 60);
                        Database.update(sa, AccessLevel.USER_MODE);
                    }
                }

                res.success = true;
                res.serviceAppointmentId = sa.Id;
                res.message = 'Service Appointment created successfully.';
            } catch (Exception e) {
                res.message = 'Could not create the Service Appointment right now.';
            }
            out.add(res);
        }
        return out;
    }
}