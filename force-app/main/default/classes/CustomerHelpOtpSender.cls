/**
 * Sends the one-time code through an SMS gateway via Named Credential SMS_Gateway.
 * Queueable so the callout never follows DML in the same transaction.
 * The plain code exists only in this async job's state and is never persisted or logged.
 */
public with sharing class CustomerHelpOtpSender implements Queueable, Database.AllowsCallouts {
    private final String toPhone;
    private final String code;

    public CustomerHelpOtpSender(String toPhone, String code) {
        this.toPhone = toPhone;
        this.code = code;
    }

    public void execute(QueueableContext ctx) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:SMS_Gateway/v1/messages');
        req.setMethod('POST');
        req.setTimeout(8000);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'to' => toPhone,
            'body' => 'Your verification code is ' + code + '. It expires in ' + (CustomerHelpIdentityService.CODE_TTL_SECONDS / 60) + ' minutes.'
        }));
        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() >= 300) {
                CustomerHelpLog.record('SendOtp', null, null, 'ERROR', 'SMS gateway status ' + res.getStatusCode());
            }
        } catch (Exception e) {
            CustomerHelpLog.record('SendOtp', null, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
        }
        CustomerHelpLog.flush();
    }
}