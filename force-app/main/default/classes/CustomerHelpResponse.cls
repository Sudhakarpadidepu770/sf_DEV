/** Uniform output for every data action so new intents need no new agent plumbing. */
public with sharing class CustomerHelpResponse {
    @InvocableVariable(label='Success') public Boolean success;
    @InvocableVariable(label='Error Code' description='NOT_VERIFIED or TEMPORARY_FAILURE when success is false.')
    public String errorCode;
    @InvocableVariable(label='Agent Guidance' description='Instruction for the agent. Never read aloud.')
    public String agentGuidance;
    @InvocableVariable(label='Data Source' description='Salesforce, or External: <system>. Say so when the source is external.')
    public String dataSource;
    @InvocableVariable(label='Record Count') public Integer recordCount;
    @InvocableVariable(label='Records') public List<CustomerHelpRecord> records;

    public static CustomerHelpResponse ok(String dataSource, List<CustomerHelpRecord> rows) {
        CustomerHelpResponse r = new CustomerHelpResponse();
        r.success = true;
        r.dataSource = dataSource;
        r.records = rows;
        r.recordCount = rows.size();
        r.agentGuidance = rows.isEmpty()
            ? 'Nothing was found. Say: I couldn\'t find that information in your Salesforce record. Do not guess.'
            : 'Summarise in short, natural sentences. Never read IDs. If more than one record, ask which the customer means before giving details.';
        return r;
    }

    public static CustomerHelpResponse failure(String errorCode, String guidance) {
        CustomerHelpResponse r = new CustomerHelpResponse();
        r.success = false;
        r.errorCode = errorCode;
        r.agentGuidance = guidance;
        r.recordCount = 0;
        r.records = new List<CustomerHelpRecord>();
        return r;
    }
}