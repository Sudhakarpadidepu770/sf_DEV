public with sharing class GetOutstandingBalanceAction {
    @InvocableMethod(
        label='Get Outstanding Balance'
        description='Gets the customer\'s outstanding and available balance from the core banking system (external, not Salesforce). Requires a verified session.'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        List<CustomerHelpResponse> out = new List<CustomerHelpResponse>();
        for (CustomerHelpRequest r : requests) {
            out.add(runOne(r));
        }
        CustomerHelpLog.flush(); // after callouts
        return out;
    }

    private static CustomerHelpResponse runOne(CustomerHelpRequest r) {
        try {
            Id accountId = String.isNotBlank(r.accountId) ? (Id) r.accountId : CustomerHelpIdentityService.requireVerifiedAccount(r.sessionId);
            List<Account> cs = [SELECT AccountNumber FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
            String acct = cs.isEmpty() ? null : cs[0].AccountNumber;
            if (String.isBlank(acct)) {
                return CustomerHelpResponse.ok('Salesforce', new List<CustomerHelpRecord>());
            }
            CustomerHelpBalanceService.BalanceResult b = CustomerHelpBalanceService.fetch(acct);

            CustomerHelpRecord o = new CustomerHelpRecord();
            String cur = b.currencyCode == null ? '' : ' ' + b.currencyCode;
            List<String> parts = new List<String>();
            if (b.outstanding != null) {
                parts.add('Outstanding balance: ' + b.outstanding.setScale(2).format() + cur);
            }
            if (b.available != null) {
                parts.add('Available balance: ' + b.available.setScale(2).format() + cur);
            }
            o.title = 'Account balance';
            o.primaryDate = (String.isNotBlank(r.accountId) && r.spokenStyle != true) ? CustomerHelpDateFormatter.text(b.asOf) : CustomerHelpDateFormatter.speak(b.asOf);
            o.details = String.join(parts, '. ');
            CustomerHelpResponse resp = CustomerHelpResponse.ok('External: core banking system', new List<CustomerHelpRecord>{ o });
            resp.agentGuidance = 'This figure comes from the core banking system, not Salesforce. Say so, and mention it was last updated ' + o.primaryDate + '.';
            CustomerHelpLog.record('GetOutstandingBalance', r.sessionId, accountId, 'FOUND', null);
            return resp;
        } catch (CustomerHelpIdentityService.CustomerHelpAuthException e) {
            CustomerHelpLog.record('GetOutstandingBalance', r.sessionId, null, 'NOT_VERIFIED', null);
            return CustomerHelpResponse.failure('NOT_VERIFIED', CustomerHelpRunner.GUIDE_NOT_VERIFIED);
        } catch (Exception e) {
            CustomerHelpLog.record('GetOutstandingBalance', r.sessionId, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
            return CustomerHelpResponse.failure('TEMPORARY_FAILURE', CustomerHelpRunner.GUIDE_FAILURE);
        }
    }
}