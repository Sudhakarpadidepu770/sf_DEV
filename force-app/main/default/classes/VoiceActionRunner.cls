/** Common wrapper: verify -> fetch -> map errors to safe guidance -> log. All thin @InvocableMethod classes delegate here. */
public with sharing class VoiceActionRunner {
    public static final String GUIDE_NOT_VERIFIED =
        'The customer is not verified. Disclose nothing. Say: I need to verify your identity before I can provide those details. Then start verification.';
    public static final String GUIDE_FAILURE =
        'Do not mention errors or systems. Say: I\'m having trouble retrieving that information right now. Would you like me to connect you with a customer service representative?';

    public static List<VoiceActionResponse> run(String intentKey, String actionName, List<VoiceActionRequest> requests) {
        List<VoiceActionResponse> out = new List<VoiceActionResponse>();
        for (VoiceActionRequest r : requests) {
            out.add(runOne(intentKey, actionName, r));
        }
        VoiceLog.flush();
        return out;
    }

    private static VoiceActionResponse runOne(String intentKey, String actionName, VoiceActionRequest r) {
        try {
            VoiceActionResponse resp = String.isNotBlank(r.accountId)
                ? VoiceDataService.fetchForAccount(intentKey, (Id) r.accountId, r.recordHint)
                : VoiceDataService.fetch(intentKey, r.sessionId, r.recordHint);
            VoiceLog.record(actionName, r.sessionId, null, resp.recordCount > 0 ? 'FOUND' : 'EMPTY', null);
            return resp;
        } catch (VoiceIdentityService.VoiceAuthException e) {
            VoiceLog.record(actionName, r.sessionId, null, 'NOT_VERIFIED', null);
            return VoiceActionResponse.failure('NOT_VERIFIED', GUIDE_NOT_VERIFIED);
        } catch (Exception e) {
            VoiceLog.record(actionName, r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return VoiceActionResponse.failure('TEMPORARY_FAILURE', GUIDE_FAILURE);
        }
    }
}