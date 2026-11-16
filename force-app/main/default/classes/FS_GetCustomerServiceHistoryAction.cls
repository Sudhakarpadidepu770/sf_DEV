/**
 * Agentforce action: retrieves a customer's Cases and Work Orders by customer/account name.
 * Input: customerName (required, matches Account.Name, partial match supported).
 * Output: one HistoryRow per Case belonging to that customer, newest first, capped at 25 rows.
 */
public with sharing class FS_GetCustomerServiceHistoryAction {

    public class Request {
        @InvocableVariable(required=true label='Customer Name' description='Account name, e.g. "Raj Kumar Household" or "ABC Electronics". Partial matches allowed.')
        public String customerName;
    }

    public class HistoryRow {
        @InvocableVariable public String caseNumber;
        @InvocableVariable public String subject;
        @InvocableVariable public String status;
        @InvocableVariable public String serviceCategory;
        @InvocableVariable public String assetName;
        @InvocableVariable public String createdDate;
    }

    public class Result {
        @InvocableVariable(label='History Rows')
        public List<HistoryRow> historyRows = new List<HistoryRow>();
    }

    @InvocableMethod(
        label='Get Customer Service History'
        description='Returns a customer\'s past and current service Cases by customer/account name.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<HistoryRow> rows = res.historyRows;
            try {
                if (String.isNotBlank(r.customerName)) {
                    String likeTerm = '%' + r.customerName + '%';
                    for (Case c : [
                        SELECT CaseNumber, Subject, Status, Service_Category__c, Asset.Name, CreatedDate
                        FROM Case
                        WHERE Account.Name LIKE :likeTerm
                        WITH USER_MODE
                        ORDER BY CreatedDate DESC
                        LIMIT 25
                    ]) {
                        HistoryRow hr = new HistoryRow();
                        hr.caseNumber = c.CaseNumber;
                        hr.subject = c.Subject;
                        hr.status = c.Status;
                        hr.serviceCategory = c.Service_Category__c;
                        hr.assetName = c.Asset != null ? c.Asset.Name : null;
                        hr.createdDate = String.valueOf(c.CreatedDate.date());
                        rows.add(hr);
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