/** Common wrapper: verify -> fetch -> map errors to safe guidance -> log. All thin @InvocableMethod classes delegate here. */
public with sharing class CustomerHelpRunner {
    public static final String GUIDE_NOT_VERIFIED =
        'The customer is not verified. Disclose nothing. Say: I need to verify your identity before I can provide those details. Then start verification.';
    public static final String GUIDE_FAILURE =
        'Do not mention errors or systems. Say: I\'m having trouble retrieving that information right now. Would you like me to connect you with a customer service representative?';

    public static List<CustomerHelpResponse> run(String intentKey, String actionName, List<CustomerHelpRequest> requests) {
        List<CustomerHelpResponse> out = new List<CustomerHelpResponse>();
        for (CustomerHelpRequest r : requests) {
            out.add(runOne(intentKey, actionName, r));
        }
        CustomerHelpLog.flush();
        return out;
    }

    private static CustomerHelpResponse runOne(String intentKey, String actionName, CustomerHelpRequest r) {
        try {
            CustomerHelpResponse resp = String.isNotBlank(r.accountId)
                ? CustomerHelpDataService.fetchForAccount(intentKey, (Id) r.accountId, r.recordHint, r.spokenStyle == true)
                : CustomerHelpDataService.fetch(intentKey, r.sessionId, r.recordHint);
            CustomerHelpLog.record(actionName, r.sessionId, null, resp.recordCount > 0 ? 'FOUND' : 'EMPTY', null);
            return resp;
        } catch (CustomerHelpIdentityService.CustomerHelpAuthException e) {
            CustomerHelpLog.record(actionName, r.sessionId, null, 'NOT_VERIFIED', null);
            return CustomerHelpResponse.failure('NOT_VERIFIED', GUIDE_NOT_VERIFIED);
        } catch (Exception e) {
            CustomerHelpLog.record(actionName, r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return CustomerHelpResponse.failure('TEMPORARY_FAILURE', GUIDE_FAILURE);
        }
    }
}