/**
 * Agentforce action: returns the completed-service history for a given Asset (appliance/equipment).
 * Input: assetName (required, e.g. "TV-GNT-001").
 * Output: one ServiceHistoryRow per completed Work Order against that Asset, newest first, capped at 25.
 */
public with sharing class FS_GetAssetServiceHistoryAction {

    public class Request {
        @InvocableVariable(required=true label='Asset Name' description='e.g. TV-GNT-001.')
        public String assetName;
    }

    public class ServiceHistoryRow {
        @InvocableVariable public String workOrderNumber;
        @InvocableVariable public String workType;
        @InvocableVariable public String status;
        @InvocableVariable public String completedDate;
    }

    public class Result {
        @InvocableVariable(label='Service History')
        public List<ServiceHistoryRow> serviceHistory = new List<ServiceHistoryRow>();
    }

    @InvocableMethod(
        label='Get Asset Service History'
        description='Returns the Work Order service history for a given Asset, most recent first.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<ServiceHistoryRow> rows = res.serviceHistory;
            try {
                if (String.isNotBlank(r.assetName)) {
                    for (WorkOrder wo : [
                        SELECT WorkOrderNumber, WorkType.Name, Status, LastModifiedDate
                        FROM WorkOrder
                        WHERE Asset.Name = :r.assetName
                        WITH USER_MODE
                        ORDER BY LastModifiedDate DESC
                        LIMIT 25
                    ]) {
                        ServiceHistoryRow sh = new ServiceHistoryRow();
                        sh.workOrderNumber = wo.WorkOrderNumber;
                        sh.workType = wo.WorkType != null ? wo.WorkType.Name : null;
                        sh.status = wo.Status;
                        sh.completedDate = wo.Status == 'Completed' ? String.valueOf(wo.LastModifiedDate.date()) : null;
                        rows.add(sh);
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