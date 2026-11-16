/**
 * Agentforce action: retrieves open Cases, optionally filtered by service category and/or priority.
 * Input: serviceCategory (optional, must match a Case Service_Category__c value), priority (optional: High/Medium/Low).
 * Output: one CaseSummary row per matching open Case (Status != 'Closed'), newest first, capped at 25 rows.
 */
public with sharing class FS_GetOpenCasesAction {

    public class Request {
        @InvocableVariable(label='Service Category' description='Optional. e.g. Television, Air Conditioner, Refrigerator.')
        public String serviceCategory;
        @InvocableVariable(label='Priority' description='Optional. High, Medium, or Low.')
        public String priority;
    }

    public class CaseSummary {
        @InvocableVariable public String caseNumber;
        @InvocableVariable public String subject;
        @InvocableVariable public String status;
        @InvocableVariable public String priority;
        @InvocableVariable public String serviceCategory;
        @InvocableVariable public String customerName;
    }

    public class Result {
        @InvocableVariable(label='Cases')
        public List<CaseSummary> cases = new List<CaseSummary>();
    }

    @InvocableMethod(
        label='Get Open Cases'
        description='Returns open service Cases, optionally filtered by service category and/or priority.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<CaseSummary> rows = res.cases;
            try {
                String query = 'SELECT CaseNumber, Subject, Status, Priority, Service_Category__c, Account.Name ' +
                    'FROM Case WHERE Status != \'Closed\'';
                Map<String, Object> binds = new Map<String, Object>();
                if (String.isNotBlank(r.serviceCategory)) {
                    query += ' AND Service_Category__c = :serviceCategory';
                    binds.put('serviceCategory', r.serviceCategory);
                }
                if (String.isNotBlank(r.priority)) {
                    query += ' AND Priority = :priority';
                    binds.put('priority', r.priority);
                }
                query += ' ORDER BY CreatedDate DESC LIMIT 25';
                for (Case c : (List<Case>) Database.queryWithBinds(query, binds, AccessLevel.USER_MODE)) {
                    CaseSummary cs = new CaseSummary();
                    cs.caseNumber = c.CaseNumber;
                    cs.subject = c.Subject;
                    cs.status = c.Status;
                    cs.priority = c.Priority;
                    cs.serviceCategory = c.Service_Category__c;
                    cs.customerName = c.Account != null ? c.Account.Name : null;
                    rows.add(cs);
                }
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(res);
        }
        return out;
    }
}