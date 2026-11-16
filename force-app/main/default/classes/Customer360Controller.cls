/**
 * Backs the Customer 360 View app: one consolidated read of a customer's Account, Assets
 * (with warranty status), Cases, Work Orders, and Service Appointments (with assigned technician).
 * Read-only, with sharing, AccessLevel.USER_MODE throughout.
 */
public with sharing class Customer360Controller {

    public class AssetRow {
        @AuraEnabled public Id assetId;
        @AuraEnabled public String assetName;
        @AuraEnabled public String product;
        @AuraEnabled public String status;
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String installDate;
        @AuraEnabled public String warrantyEndDate;
        @AuraEnabled public Boolean underWarranty;
        @AuraEnabled public Integer serviceCount;
    }

    public class CaseRow {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String serviceCategory;
        @AuraEnabled public String assetName;
        @AuraEnabled public String createdDate;
    }

    public class WorkOrderRow {
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String priority;
        @AuraEnabled public String workType;
        @AuraEnabled public String assetName;
        @AuraEnabled public String caseNumber;
    }

    public class AppointmentRow {
        @AuraEnabled public Id appointmentId;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public String schedStartTime;
        @AuraEnabled public String territory;
        @AuraEnabled public String technicianName;
        @AuraEnabled public String assetName;
        @AuraEnabled public String workOrderNumber;
    }

    public class Customer360Data {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String customerType;
        @AuraEnabled public String phone;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String primaryContactName;
        @AuraEnabled public String primaryContactPhone;
        @AuraEnabled public String primaryContactEmail;
        @AuraEnabled public Integer totalAssets;
        @AuraEnabled public Integer openCases;
        @AuraEnabled public Integer completedServices;
        @AuraEnabled public Integer upcomingAppointments;
        @AuraEnabled public List<AssetRow> assets;
        @AuraEnabled public List<CaseRow> cases;
        @AuraEnabled public List<WorkOrderRow> workOrders;
        @AuraEnabled public List<AppointmentRow> appointments;
    }

    public class SearchResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String customerType;
        @AuraEnabled public String billingCity;
    }

    @AuraEnabled(cacheable=true)
    public static List<SearchResult> searchCustomers(String searchTerm) {
        List<SearchResult> out = new List<SearchResult>();
        try {
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                return out;
            }
            String likeTerm = '%' + searchTerm + '%';
            for (Account a : [
                SELECT Id, Name, Customer_Type__c, BillingCity
                FROM Account
                WHERE Name LIKE :likeTerm
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 15
            ]) {
                SearchResult sr = new SearchResult();
                sr.accountId = a.Id;
                sr.name = a.Name;
                sr.customerType = a.Customer_Type__c;
                sr.billingCity = a.BillingCity;
                out.add(sr);
            }
        } catch (Exception e) {
            // Sanitized: never leak internal error text to the UI.
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static Customer360Data getCustomer360(Id accountId) {
        Customer360Data data = new Customer360Data();
        data.assets = new List<AssetRow>();
        data.cases = new List<CaseRow>();
        data.workOrders = new List<WorkOrderRow>();
        data.appointments = new List<AppointmentRow>();
        data.totalAssets = 0;
        data.openCases = 0;
        data.completedServices = 0;
        data.upcomingAppointments = 0;

        if (accountId == null) {
            return data;
        }

        List<Account> accts = [
            SELECT Id, Name, Customer_Type__c, Phone, BillingCity
            FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1
        ];
        if (accts.isEmpty()) {
            return data;
        }
        Account acc = accts[0];
        data.accountId = acc.Id;
        data.accountName = acc.Name;
        data.customerType = acc.Customer_Type__c;
        data.phone = acc.Phone;
        data.billingCity = acc.BillingCity;

        List<Contact> contacts = [
            SELECT Name, Phone, Email FROM Contact WHERE AccountId = :accountId WITH USER_MODE ORDER BY CreatedDate ASC LIMIT 1
        ];
        if (!contacts.isEmpty()) {
            data.primaryContactName = contacts[0].Name;
            data.primaryContactPhone = contacts[0].Phone;
            data.primaryContactEmail = contacts[0].Email;
        }

        // ---------- Assets + Warranty + per-asset service count ----------
        List<Asset> assetRecords = [
            SELECT Id, Name, Description, Status, SerialNumber, InstallDate
            FROM Asset WHERE AccountId = :accountId WITH USER_MODE ORDER BY Name ASC
        ];
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : assetRecords) assetIds.add(a.Id);

        Map<Id, AssetWarranty> warrantyByAsset = new Map<Id, AssetWarranty>();
        if (!assetIds.isEmpty()) {
            for (AssetWarranty w : [SELECT AssetId, EndDate FROM AssetWarranty WHERE AssetId IN :assetIds WITH USER_MODE]) {
                warrantyByAsset.put(w.AssetId, w);
            }
        }
        Map<Id, Integer> serviceCountByAsset = new Map<Id, Integer>();
        if (!assetIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT AssetId aid, COUNT(Id) c FROM WorkOrder WHERE AssetId IN :assetIds WITH USER_MODE GROUP BY AssetId
            ]) {
                serviceCountByAsset.put((Id) ar.get('aid'), (Integer) ar.get('c'));
            }
        }

        data.totalAssets = assetRecords.size();
        for (Asset a : assetRecords) {
            AssetRow row = new AssetRow();
            row.assetId = a.Id;
            row.assetName = a.Name;
            row.product = a.Description;
            row.status = a.Status;
            row.serialNumber = a.SerialNumber;
            row.installDate = a.InstallDate != null ? String.valueOf(a.InstallDate) : null;
            AssetWarranty w = warrantyByAsset.get(a.Id);
            if (w != null && w.EndDate != null) {
                row.warrantyEndDate = String.valueOf(w.EndDate);
                row.underWarranty = w.EndDate >= Date.today();
            } else {
                row.underWarranty = false;
            }
            row.serviceCount = serviceCountByAsset.containsKey(a.Id) ? serviceCountByAsset.get(a.Id) : 0;
            data.assets.add(row);
        }

        // ---------- Cases ----------
        // Wrapped defensively: Platform-license users (e.g. FS_Technician) cannot be granted Case
        // access at all (a hard Salesforce license restriction), so WITH USER_MODE would throw for
        // them — degrade to an empty case list instead of breaking the whole 360 view.
        try {
            List<Case> caseRecords = [
                SELECT CaseNumber, Subject, Status, Priority, Service_Category__c, Asset.Name, CreatedDate
                FROM Case WHERE AccountId = :accountId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
            ];
            for (Case c : caseRecords) {
                CaseRow row = new CaseRow();
                row.caseId = c.Id;
                row.caseNumber = c.CaseNumber;
                row.subject = c.Subject;
                row.status = c.Status;
                row.priority = c.Priority;
                row.serviceCategory = c.Service_Category__c;
                row.assetName = c.Asset != null ? c.Asset.Name : null;
                row.createdDate = String.valueOf(c.CreatedDate.date());
                data.cases.add(row);
                if (c.Status != 'Closed') data.openCases++;
            }
        } catch (Exception e) {
            // No Case access for this user — leave data.cases empty rather than failing the request.
        }

        // ---------- Work Orders (via Asset.AccountId — WorkOrder.AccountId isn't populated by the intake Flow) ----------
        List<WorkOrder> woRecords = [
            SELECT WorkOrderNumber, Subject, Status, Priority, WorkType.Name, Asset.Name, Case.CaseNumber
            FROM WorkOrder WHERE Asset.AccountId = :accountId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50
        ];
        Set<Id> workOrderIds = new Set<Id>();
        for (WorkOrder wo : woRecords) {
            workOrderIds.add(wo.Id);
            WorkOrderRow row = new WorkOrderRow();
            row.workOrderId = wo.Id;
            row.workOrderNumber = wo.WorkOrderNumber;
            row.subject = wo.Subject;
            row.status = wo.Status;
            row.priority = wo.Priority;
            row.workType = wo.WorkType != null ? wo.WorkType.Name : null;
            row.assetName = wo.Asset != null ? wo.Asset.Name : null;
            row.caseNumber = wo.Case != null ? wo.Case.CaseNumber : null;
            data.workOrders.add(row);
            if (wo.Status == 'Completed') data.completedServices++;
        }

        // ---------- Service Appointments (via the Work Orders collected above) ----------
        if (!workOrderIds.isEmpty()) {
            Map<Id, String> woNumberById = new Map<Id, String>();
            Map<Id, String> assetNameByWoId = new Map<Id, String>();
            for (WorkOrder wo : woRecords) {
                woNumberById.put(wo.Id, wo.WorkOrderNumber);
                assetNameByWoId.put(wo.Id, wo.Asset != null ? wo.Asset.Name : null);
            }

            List<ServiceAppointment> appts = [
                SELECT Subject, Status, SchedStartTime, ServiceTerritory.Name, ParentRecordId
                FROM ServiceAppointment
                WHERE ParentRecordId IN :workOrderIds
                WITH USER_MODE
                ORDER BY SchedStartTime DESC NULLS LAST
                LIMIT 50
            ];
            Set<Id> apptIds = new Set<Id>();
            for (ServiceAppointment sa : appts) apptIds.add(sa.Id);

            Map<Id, String> techByAppt = new Map<Id, String>();
            if (!apptIds.isEmpty()) {
                for (AssignedResource ar : [
                    SELECT ServiceAppointmentId, ServiceResource.Name FROM AssignedResource
                    WHERE ServiceAppointmentId IN :apptIds WITH USER_MODE
                ]) {
                    techByAppt.put(ar.ServiceAppointmentId, ar.ServiceResource.Name);
                }
            }

            DateTime now = DateTime.now();
            for (ServiceAppointment sa : appts) {
                AppointmentRow row = new AppointmentRow();
                row.appointmentId = sa.Id;
                row.subject = sa.Subject;
                row.status = sa.Status;
                row.schedStartTime = sa.SchedStartTime != null ? String.valueOf(sa.SchedStartTime) : null;
                row.territory = sa.ServiceTerritory != null ? sa.ServiceTerritory.Name : null;
                row.technicianName = techByAppt.get(sa.Id);
                row.assetName = assetNameByWoId.get(sa.ParentRecordId);
                row.workOrderNumber = woNumberById.get(sa.ParentRecordId);
                data.appointments.add(row);
                if (sa.SchedStartTime != null && sa.SchedStartTime >= now && sa.Status != 'Completed' && sa.Status != 'Canceled') {
                    data.upcomingAppointments++;
                }
            }
        }

        return data;
    }
}