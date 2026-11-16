public with sharing class VoiceVerifyCheckAction {
    public class Request {
        @InvocableVariable(required=true label='Session Id') public String sessionId;
        @InvocableVariable(required=true label='Code' description='The six digit code the customer read out.') public String code;
    }

    public class Response {
        @InvocableVariable(label='Verified') public Boolean verified;
        @InvocableVariable(label='Locked') public Boolean locked;
        @InvocableVariable(label='Attempts Left') public Integer attemptsLeft;
        @InvocableVariable(label='Customer Name') public String customerName;
        @InvocableVariable(label='Agent Guidance') public String agentGuidance;
    }

    @InvocableMethod(
        label='Check Verification Code'
        description='Checks the one-time code. On success the session becomes verified server-side; store Verified in the IsVerified variable.'
        category='Voice Customer Help'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            resp.verified = false;
            resp.locked = false;
            resp.attemptsLeft = 0;
            try {
                VoiceIdentityService.CheckResult c = VoiceIdentityService.check(r.sessionId, r.code);
                resp.verified = c.verified;
                resp.locked = c.locked;
                resp.attemptsLeft = c.attemptsLeft;
                resp.customerName = c.customerName;
                if (c.verified) {
                    resp.agentGuidance = 'Verified. Greet by name if present and ask how you can help.';
                } else if (c.locked) {
                    resp.agentGuidance = 'Locked after too many attempts. Say you cannot verify them and offer a representative.';
                } else {
                    resp.agentGuidance = 'Code did not match or expired. Say so simply and offer to try again if attempts remain.';
                }
            } catch (Exception e) {
                VoiceLog.record('VerifyCheck', r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
                resp.agentGuidance = VoiceActionRunner.GUIDE_FAILURE;
            }
            out.add(resp);
        }
        VoiceLog.flush();
        return out;
    }
}