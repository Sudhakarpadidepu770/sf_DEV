/** Creates the Case a human agent receives on escalation; the Omni-Channel routing Flow then routes it/the live session. */
public with sharing class CreateHandoffCaseAction {
    public class Request {
        @InvocableVariable(label='Session Id') public String sessionId;
        @InvocableVariable(label='Account Id' description='The customer the caller named, chosen by the customer lookup. Empty if none.') public String accountId;
        @InvocableVariable(required=true label='Reason' description='Short reason for escalation.') public String reason;
        @InvocableVariable(label='Conversation Summary' description='Brief summary of what the customer asked and what was done. Never include verification codes.')
        public String conversationSummary;
    }

    public class Response {
        @InvocableVariable(label='Case Id') public Id caseId;
        @InvocableVariable(label='Customer Verified') public Boolean customerVerified;
        @InvocableVariable(label='Success') public Boolean success;
    }

    @InvocableMethod(
        label='Create Handoff Case'
        description='Records the conversation context for a human representative before transferring. Works for unverified callers too.'
        category='Customer Help'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            resp.success = false;
            resp.customerVerified = false;
            try {
                Id accountId;
                if (String.isNotBlank(r.accountId)) {
                    accountId = (Id) r.accountId; // named by the caller; not verified
                } else {
                    try {
                        accountId = CustomerHelpIdentityService.requireVerifiedAccount(r.sessionId);
                        resp.customerVerified = true;
                    } catch (CustomerHelpIdentityService.CustomerHelpAuthException e) {
                        accountId = null;
                    }
                }
                Case c = new Case(
                    Subject = 'Voice agent escalation: ' + r.reason.left(100),
                    Description = (resp.customerVerified ? 'Customer verified by OTP.' : 'Customer NOT verified (account named by the caller).')
                        + '\n\n' + (r.conversationSummary == null ? '' : r.conversationSummary.left(30000)),
                    AccountId = accountId,
                    Origin = 'Phone',
                    Priority = 'Medium'
                );
                Database.insert(c, AccessLevel.USER_MODE);
                resp.caseId = c.Id;
                resp.success = true;
                CustomerHelpLog.record('CreateHandoffCase', r.sessionId, accountId, 'CREATED', null);
            } catch (Exception e) {
                CustomerHelpLog.record('CreateHandoffCase', r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
            }
            out.add(resp);
        }
        CustomerHelpLog.flush();
        return out;
    }
}