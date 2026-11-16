/** Shared input for all data actions. sessionId MUST be bound to the session variable, never collected from the customer. */
public with sharing class VoiceActionRequest {
    @InvocableVariable(required=false label='Session Id' description='Voice session identifier from the session context variable. Do not ask the customer for it.')
    public String sessionId;

    @InvocableVariable(label='Account Id' description='Employee agent only: the Account chosen by the signed-in employee. Leave empty for voice sessions.')
    public String accountId;

    @InvocableVariable(label='Record Hint' description='Optional identifier the customer spoke, such as a case or request number. Leave empty otherwise.')
    public String recordHint;
}