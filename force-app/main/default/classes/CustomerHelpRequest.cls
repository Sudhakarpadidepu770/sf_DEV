/** Shared input for all data actions. sessionId MUST be bound to the session variable, never collected from the customer. */
public with sharing class CustomerHelpRequest {
    @InvocableVariable(required=false label='Session Id' description='Session identifier from the session context variable. Do not ask the customer for it.')
    public String sessionId;

    @InvocableVariable(label='Account Id' description='Employee agent only: the Account chosen by the signed-in employee. Leave empty for voice sessions.')
    public String accountId;

    @InvocableVariable(label='Response Style' description='Voice agent only: true to get spoken wording, masked numbers and customer-friendly statuses. Leave empty for the employee agent.')
    public Boolean spokenStyle;

    @InvocableVariable(label='Record Hint' description='Optional identifier the customer spoke, such as a case or request number. Leave empty otherwise.')
    public String recordHint;
}