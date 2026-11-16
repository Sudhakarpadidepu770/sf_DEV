/**
 * Agentforce action: returns an aggregate summary of a day's field service activity — appointment counts
 * by status, and case counts by service category.
 * Input: dateString (optional, yyyy-MM-dd, defaults to today).
 * Output: a single Summary row with aggregate counts.
 */
public with sharing class FS_GetServiceSummaryAction {

    public class Request {
        @InvocableVariable(label='Date' description='Optional. Format yyyy-MM-dd. Defaults to today.')
        public String dateString;
    }

    public class Summary {
        @InvocableVariable public Integer totalAppointments;
        @InvocableVariable public Integer completedAppointments;
        @InvocableVariable public Integer inProgressAppointments;
        @InvocableVariable public Integer scheduledAppointments;
        @InvocableVariable public String categoryBreakdown;
    }

    @InvocableMethod(
        label='Get Service Summary'
        description='Returns aggregate counts of field service appointments (by status) and cases (by category) for a given date.'
        category='Field Service'
    )
    public static List<Summary> run(List<Request> requests) {
        List<Summary> out = new List<Summary>();
        for (Request r : requests) {
            Summary s = new Summary();
            s.totalAppointments = 0;
            s.completedAppointments = 0;
            s.inProgressAppointments = 0;
            s.scheduledAppointments = 0;
            try {
                Date targetDate = Date.today();
                if (String.isNotBlank(r.dateString)) {
                    try { targetDate = Date.valueOf(r.dateString); } catch (Exception ignore) {}
                }
                DateTime rangeStart = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
                DateTime rangeEnd = rangeStart.addDays(1);

                for (AggregateResult ar : [
                    SELECT Status s, COUNT(Id) c
                    FROM ServiceAppointment
                    WHERE SchedStartTime >= :rangeStart AND SchedStartTime < :rangeEnd
                    WITH USER_MODE
                    GROUP BY Status
                ]) {
                    String status = (String) ar.get('s');
                    Integer count = (Integer) ar.get('c');
                    s.totalAppointments += count;
                    if (status == 'Completed') s.completedAppointments = count;
                    if (status == 'In Progress') s.inProgressAppointments = count;
                    if (status == 'Scheduled') s.scheduledAppointments = count;
                }

                List<String> categoryLines = new List<String>();
                for (AggregateResult ar : [
                    SELECT Service_Category__c cat, COUNT(Id) c
                    FROM Case
                    WHERE Service_Category__c != null
                    WITH USER_MODE
                    GROUP BY Service_Category__c
                    ORDER BY COUNT(Id) DESC
                ]) {
                    categoryLines.add((String) ar.get('cat') + ': ' + (Integer) ar.get('c'));
                }
                s.categoryBreakdown = String.join(categoryLines, ', ');
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(s);
        }
        return out;
    }
}