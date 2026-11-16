public with sharing class CustomerHelpVerifyStartAction {
    public class Request {
        @InvocableVariable(required=true label='Session Id' description='Session identifier from the session context variable.')
        public String sessionId;
        @InvocableVariable(required=true label='Phone Number' description='Caller ID from the session, or the registered mobile number the customer states.')
        public String phoneNumber;
    }

    public class Response {
        @InvocableVariable(label='Code Sent Message') public String agentGuidance;
        @InvocableVariable(label='Rate Limited') public Boolean rateLimited;
    }

    @InvocableMethod(
        label='Start Customer Verification'
        description='Sends a one-time code to the mobile number registered in Salesforce. Use before any customer data is requested. Never confirms whether a customer exists.'
        category='Customer Help'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            try {
                CustomerHelpIdentityService.StartResult s = CustomerHelpIdentityService.start(r.sessionId, r.phoneNumber);
                resp.rateLimited = s.rateLimited;
                resp.agentGuidance = s.rateLimited
                    ? 'Too many attempts. Say you cannot send another code right now and offer a representative.'
                    : 'Say: If that number matches a customer record, a code has been sent to the registered mobile. Ask for the six digit code.';
            } catch (Exception e) {
                CustomerHelpLog.record('VerifyStart', r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
                resp.rateLimited = false;
                resp.agentGuidance = CustomerHelpRunner.GUIDE_FAILURE;
            }
            out.add(resp);
        }
        CustomerHelpLog.flush();
        return out;
    }
}