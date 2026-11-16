/**
 * Example external (non-Salesforce) lookup: Salesforce -> Named Credential -> ESB -> Core Banking.
 * Pattern to copy for BPM/SAP: one service class per system, Named Credential for auth, short timeout,
 * correlation id, typed result, no raw payload leaves this class.
 */
public with sharing class CustomerHelpBalanceService {
    public class ExternalException extends Exception {}

    public class BalanceResult {
        public Decimal outstanding;
        public Decimal available;
        public String currencyCode;
        public Datetime asOf;
    }

    public static BalanceResult fetch(String accountNumber) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Core_Banking_API/v1/accounts/' + EncodingUtil.urlEncode(accountNumber, 'UTF-8') + '/balance');
        req.setMethod('GET');
        req.setTimeout(8000);
        req.setHeader('Accept', 'application/json');
        req.setHeader('X-Correlation-Id', EncodingUtil.convertToHex(Crypto.generateAesKey(128)));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ExternalException('Core banking status ' + res.getStatusCode());
        }
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        BalanceResult b = new BalanceResult();
        b.outstanding = toDecimal(m.get('outstandingBalance'));
        b.available = toDecimal(m.get('availableBalance'));
        b.currencyCode = (String) m.get('currency');
        if (m.get('asOf') != null) {
            b.asOf = (Datetime) JSON.deserialize('"' + String.valueOf(m.get('asOf')) + '"', Datetime.class);
        }
        return b;
    }

    private static Decimal toDecimal(Object o) {
        return o == null ? null : Decimal.valueOf(String.valueOf(o));
    }
}