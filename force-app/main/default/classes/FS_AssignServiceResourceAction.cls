/**
 * Agentforce action: assigns a technician (Service Resource) to a Service Appointment and marks it Scheduled.
 * Input: serviceAppointmentId (required — obtained from Create Service Appointment or Get Service Appointments),
 *        technicianName (required).
 * Output: a single Result row describing success/failure.
 * Note: the Service Appointment must already have SchedStartTime/SchedEndTime set (FSL requires scheduling
 * times to exist before a resource can be assigned) — use Create Service Appointment with a start time first.
 */
public with sharing class FS_AssignServiceResourceAction {

    public class Request {
        @InvocableVariable(required=true label='Service Appointment Id')
        public String serviceAppointmentId;
        @InvocableVariable(required=true label='Technician Name' description='e.g. Ravi Kumar.')
        public String technicianName;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Assign Service Resource'
        description='Assigns a technician to an already-scheduled Service Appointment and marks it Scheduled.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            res.success = false;
            try {
                List<ServiceAppointment> appts = [
                    SELECT Id, SchedStartTime, SchedEndTime, Status
                    FROM ServiceAppointment WHERE Id = :r.serviceAppointmentId WITH USER_MODE LIMIT 1
                ];
                if (appts.isEmpty()) {
                    res.message = 'Service Appointment not found.';
                    out.add(res);
                    continue;
                }
                if (appts[0].SchedStartTime == null || appts[0].SchedEndTime == null) {
                    res.message = 'This Service Appointment has no scheduled time yet — set a start time before assigning a technician.';
                    out.add(res);
                    continue;
                }
                List<ServiceResource> resources = [SELECT Id FROM ServiceResource WHERE Name = :r.technicianName AND IsActive = true WITH USER_MODE LIMIT 1];
                if (resources.isEmpty()) {
                    res.message = 'No active technician found with that name.';
                    out.add(res);
                    continue;
                }

                List<AssignedResource> existing = [
                    SELECT Id FROM AssignedResource
                    WHERE ServiceAppointmentId = :r.serviceAppointmentId WITH USER_MODE
                ];
                if (!existing.isEmpty()) {
                    res.message = 'This Service Appointment already has an assigned technician.';
                    out.add(res);
                    continue;
                }

                Database.insert(new AssignedResource(
                    ServiceAppointmentId = appts[0].Id,
                    ServiceResourceId = resources[0].Id
                ), AccessLevel.USER_MODE);

                ServiceAppointment saUpdate = new ServiceAppointment(Id = appts[0].Id, Status = 'Scheduled');
                Database.update(saUpdate, AccessLevel.USER_MODE);

                res.success = true;
                res.message = 'Technician assigned and appointment scheduled.';
            } catch (Exception e) {
                res.message = 'Could not assign the technician right now.';
            }
            out.add(res);
        }
        return out;
    }
}