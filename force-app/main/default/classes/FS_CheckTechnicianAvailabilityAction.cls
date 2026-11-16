/**
 * Agentforce action: checks a technician's scheduled appointments for a given date, to help judge availability.
 * Input: technicianName (required), dateString (optional, yyyy-MM-dd, defaults to today).
 * Output: one AppointmentWindow row per appointment that technician already has that day.
 */
public with sharing class FS_CheckTechnicianAvailabilityAction {

    public class Request {
        @InvocableVariable(required=true label='Technician Name' description='e.g. Ravi Kumar.')
        public String technicianName;
        @InvocableVariable(label='Date' description='Optional. Format yyyy-MM-dd. Defaults to today.')
        public String dateString;
    }

    public class AppointmentWindow {
        @InvocableVariable public String subject;
        @InvocableVariable public String status;
        @InvocableVariable public String startTime;
        @InvocableVariable public String endTime;
    }

    public class Result {
        @InvocableVariable(label='Booked Windows')
        public List<AppointmentWindow> bookedWindows = new List<AppointmentWindow>();
    }

    @InvocableMethod(
        label='Check Technician Availability'
        description='Returns a technician\'s already-booked appointment windows for a given date (empty list means fully available that day).'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<AppointmentWindow> rows = res.bookedWindows;
            try {
                Date targetDate = Date.today();
                if (String.isNotBlank(r.dateString)) {
                    try { targetDate = Date.valueOf(r.dateString); } catch (Exception ignore) {}
                }
                DateTime rangeStart = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
                DateTime rangeEnd = rangeStart.addDays(1);

                Set<Id> saIds = new Set<Id>();
                for (AssignedResource ar : [
                    SELECT ServiceAppointmentId FROM AssignedResource
                    WHERE ServiceResource.Name = :r.technicianName WITH USER_MODE
                ]) {
                    saIds.add(ar.ServiceAppointmentId);
                }
                if (!saIds.isEmpty()) {
                    for (ServiceAppointment sa : [
                        SELECT Subject, Status, SchedStartTime, SchedEndTime
                        FROM ServiceAppointment
                        WHERE Id IN :saIds AND SchedStartTime >= :rangeStart AND SchedStartTime < :rangeEnd
                        WITH USER_MODE
                        ORDER BY SchedStartTime ASC
                    ]) {
                        AppointmentWindow aw = new AppointmentWindow();
                        aw.subject = sa.Subject;
                        aw.status = sa.Status;
                        aw.startTime = sa.SchedStartTime != null ? String.valueOf(sa.SchedStartTime) : null;
                        aw.endTime = sa.SchedEndTime != null ? String.valueOf(sa.SchedEndTime) : null;
                        rows.add(aw);
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