/** No-OTP identification: matches the caller ID to the Account whose Phone equals it. See CustomerHelpIdentityService.identifyByCallerId. */
public with sharing class CustomerHelpIdentifyCallerAction {
    public class Request {
        @InvocableVariable(required=true label='Session Id' description='Session identifier from the session variable.')
        public String sessionId;
        @InvocableVariable(required=true label='Caller Phone' description='Caller ID of the incoming call, from the session variable. Never taken from what the customer says.')
        public String phoneNumber;
    }

    public class Response {
        @InvocableVariable(label='Identified') public Boolean identified;
        @InvocableVariable(label='Customer Name') public String customerName;
        @InvocableVariable(label='Agent Guidance') public String agentGuidance;
    }

    @InvocableMethod(
        label='Identify Caller'
        description='Identifies the customer from the caller ID. Use once at the start of every call, before any customer data is requested.'
        category='Customer Help'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            resp.identified = false;
            try {
                CustomerHelpIdentityService.CheckResult c = CustomerHelpIdentityService.identifyByCallerId(r.sessionId, r.phoneNumber);
                resp.identified = c.verified;
                resp.customerName = c.customerName;
                resp.agentGuidance = c.verified
                    ? 'Identified. Greet the customer by name and ask how you can help.'
                    : 'Could not match the phone number to a customer record. Say so simply, share nothing, and offer to connect a customer service representative. Do not ask for another number.';
            } catch (Exception e) {
                CustomerHelpLog.record('IdentifyCaller', r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
                resp.agentGuidance = CustomerHelpRunner.GUIDE_FAILURE;
            }
            out.add(resp);
        }
        CustomerHelpLog.flush();
        return out;
    }
}