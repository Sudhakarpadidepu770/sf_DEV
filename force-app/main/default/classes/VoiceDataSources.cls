/**
 * Registry of what customers can ask about. Each entry = one "intent": standard object, the field that links it to
 * the customer Account, fields to return, status/date fields. Add a question = add one entry here (code-reviewed,
 * deployed) - nothing else in the retrieval path changes.
 *
 * Standard objects/fields only, except Account.Account_Status__c. Entries flagged active=false need the object enabled in Setup first.
 */
public with sharing class VoiceDataSources {
    public class Source {
        public String objectName;
        public String ownerLookup;      // field that equals the verified Account Id
        public String fields;           // comma separated, spoken in this order
        public String maskedFields;     // comma separated, spoken as "ending in ..."
        public String statusField;
        public String dateField;        // "when was it created/due/ends"
        public String orderField;       // sorted descending
        public String identifierField;  // matched against the customer's spoken reference
        public String extraFilter;      // fixed SOQL condition (code-controlled)
        public Integer maxRows = 5;
        public Boolean active = true;
        public Boolean systemMode = false; // Task access cannot be granted by permission set; still scoped to the verified Account and fixed fields
    }

    private static final Map<String, Source> REGISTRY = build();

    public static Source get(String intentKey) {
        return intentKey == null ? null : REGISTRY.get(intentKey);
    }

    private static Map<String, Source> build() {
        Map<String, Source> m = new Map<String, Source>();

        // Cases: open ones, and the full history for "service request" questions (Case is the standard service request).
        m.put('Open_Cases', src('Case', 'AccountId', 'CaseNumber, Subject, Status, Priority', null, 'Status', 'CreatedDate',
            'LastModifiedDate', 'CaseNumber', 'IsClosed = false', 5));
        m.put('Service_Request', src('Case', 'AccountId', 'CaseNumber, Subject, Status, Priority', null, 'Status', 'CreatedDate',
            'CreatedDate', 'CaseNumber', null, 5));

        // Application / onboarding: Opportunity (StageName = current stage, NextStep = next step).
        // If you use Financial Services Cloud, change objectName to LoanApplication and its status/date fields.
        m.put('Application_Status', src('Opportunity', 'AccountId', 'Name, StageName, NextStep, LastModifiedDate', null,
            'StageName', 'CreatedDate', 'CreatedDate', 'Name', null, 3));

        // Account_Status__c is the single custom field in this solution (Account has no standard status).
        m.put('Account_Information', src('Account', 'Id', 'Name, Account_Status__c, AccountNumber, Type', 'AccountNumber', 'Account_Status__c', 'CreatedDate',
            null, null, null, 1));
        m.put('Customer_Profile', src('Account', 'Id', 'Name, Phone', 'Phone', null, null, null, null, null, 1));
        m.put('Products_Held', src('Asset', 'AccountId', 'Name, Status, InstallDate, UsageEndDate', null, 'Status', 'InstallDate',
            'InstallDate', null, null, 5));

        // Convention: a required document is an open Task on the Account/Opportunity whose Subject starts with "Document".
        m.put('Required_Documents', sys(src('Task', 'AccountId', 'Subject, Status, ActivityDate', null, 'Status', 'ActivityDate',
            'ActivityDate', null, 'IsClosed = false AND Subject LIKE \'Document%\'', 5)));

        // Last interaction: latest Task, excluding this agent's own audit tasks. Description (internal notes) is never returned.
        m.put('Last_Interaction', sys(src('Task', 'AccountId', 'Subject, Status', null, null, 'CreatedDate', 'CreatedDate', null,
            'NOT Subject LIKE \'' + VoiceLog.SUBJECT_PREFIX + '%\'', 1)));

        // Optional - enable the object in Setup, then set active = true and add a thin action class.
        Source wo = src('WorkOrder', 'AccountId', 'WorkOrderNumber, Subject, Status, Priority', null, 'Status', 'CreatedDate',
            'CreatedDate', 'WorkOrderNumber', null, 5);
        wo.active = false;
        m.put('Work_Orders', wo);
        Source sc = src('ServiceContract', 'AccountId', 'Name, Status, EndDate', null, 'Status', 'EndDate', 'EndDate', null, null, 3);
        sc.active = false;
        m.put('Contract_Expiry', sc);
        return m;
    }

    private static Source sys(Source s) {
        s.systemMode = true;
        return s;
    }

    private static Source src(String obj, String owner, String fields, String masked, String status, String dateField,
        String orderField, String identifier, String filter, Integer maxRows) {
        Source s = new Source();
        s.objectName = obj;
        s.ownerLookup = owner;
        s.fields = fields;
        s.maskedFields = masked;
        s.statusField = status;
        s.dateField = dateField;
        s.orderField = orderField;
        s.identifierField = identifier;
        s.extraFilter = filter;
        s.maxRows = maxRows;
        return s;
    }
}