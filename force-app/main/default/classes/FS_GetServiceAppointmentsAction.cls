/**
 * Agentforce action: retrieves Service Appointments, optionally filtered by technician name and/or date and/or status.
 * Input: technicianName (optional), dateString (optional, yyyy-MM-dd), status (optional).
 * Output: one AppointmentRow per matching appointment, capped at 25.
 */
public with sharing class FS_GetServiceAppointmentsAction {

    public class Request {
        @InvocableVariable(label='Technician Name' description='Optional. e.g. Ravi Kumar.')
        public String technicianName;
        @InvocableVariable(label='Date' description='Optional. Format yyyy-MM-dd.')
        public String dateString;
        @InvocableVariable(label='Status' description='Optional. Scheduled, Dispatched, In Progress, Completed, Canceled, None.')
        public String status;
    }

    public class AppointmentRow {
        @InvocableVariable public String subject;
        @InvocableVariable public String status;
        @InvocableVariable public String startTime;
        @InvocableVariable public String technicianName;
        @InvocableVariable public String territory;
    }

    public class Result {
        @InvocableVariable(label='Appointments')
        public List<AppointmentRow> appointments = new List<AppointmentRow>();
    }

    @InvocableMethod(
        label='Get Service Appointments'
        description='Returns Service Appointments optionally filtered by technician, date, and/or status.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<AppointmentRow> rows = res.appointments;
            try {
                Set<Id> saIdsForTech = null;
                if (String.isNotBlank(r.technicianName)) {
                    saIdsForTech = new Set<Id>();
                    for (AssignedResource ar : [
                        SELECT ServiceAppointmentId FROM AssignedResource
                        WHERE ServiceResource.Name = :r.technicianName WITH USER_MODE
                    ]) {
                        saIdsForTech.add(ar.ServiceAppointmentId);
                    }
                }

                String query = 'SELECT Subject, Status, SchedStartTime, ServiceTerritory.Name FROM ServiceAppointment WHERE Id != null';
                Map<String, Object> binds = new Map<String, Object>();
                if (saIdsForTech != null) {
                    query += ' AND Id IN :saIdsForTech';
                    binds.put('saIdsForTech', saIdsForTech);
                }
                if (String.isNotBlank(r.dateString)) {
                    Date targetDate;
                    try { targetDate = Date.valueOf(r.dateString); } catch (Exception ignore) {}
                    if (targetDate != null) {
                        DateTime rangeStart = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
                        DateTime rangeEnd = rangeStart.addDays(1);
                        query += ' AND SchedStartTime >= :rangeStart AND SchedStartTime < :rangeEnd';
                        binds.put('rangeStart', rangeStart);
                        binds.put('rangeEnd', rangeEnd);
                    }
                }
                if (String.isNotBlank(r.status)) {
                    query += ' AND Status = :statusVal';
                    binds.put('statusVal', r.status);
                }
                query += ' ORDER BY SchedStartTime ASC NULLS LAST LIMIT 25';

                Map<Id, String> techByAppt = new Map<Id, String>();
                List<ServiceAppointment> appts = (List<ServiceAppointment>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
                Set<Id> apptIds = new Set<Id>();
                for (ServiceAppointment sa : appts) apptIds.add(sa.Id);
                if (!apptIds.isEmpty()) {
                    for (AssignedResource ar : [
                        SELECT ServiceAppointmentId, ServiceResource.Name FROM AssignedResource
                        WHERE ServiceAppointmentId IN :apptIds WITH USER_MODE
                    ]) {
                        techByAppt.put(ar.ServiceAppointmentId, ar.ServiceResource.Name);
                    }
                }
                for (ServiceAppointment sa : appts) {
                    AppointmentRow ar2 = new AppointmentRow();
                    ar2.subject = sa.Subject;
                    ar2.status = sa.Status;
                    ar2.startTime = sa.SchedStartTime != null ? String.valueOf(sa.SchedStartTime) : null;
                    ar2.technicianName = techByAppt.get(sa.Id);
                    ar2.territory = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : null;
                    rows.add(ar2);
                }
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(res);
        }
        return out;
    }
}