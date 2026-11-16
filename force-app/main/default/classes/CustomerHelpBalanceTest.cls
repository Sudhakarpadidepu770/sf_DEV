@IsTest
private class CustomerHelpBalanceTest {
    private class BankMock implements HttpCalloutMock {
        private final Integer status;
        BankMock(Integer status) {
            this.status = status;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(status);
            r.setBody('{"outstandingBalance":1250.4,"availableBalance":300,"currency":"USD","asOf":"2026-09-18T10:00:00Z"}');
            return r;
        }
    }

    @TestSetup
    static void seed() {
        insert new Account(Name = 'Acme', AccountNumber = 'AC-99887766');
    }

    private static List<CustomerHelpRequest> setup(String sessionId) {
        Account a = [SELECT Id FROM Account WHERE Name = 'Acme' LIMIT 1]; // committed in @TestSetup: no DML before the callout
        CustomerHelpIdentityService.storeVerified(sessionId, a.Id);
        CustomerHelpRequest r = new CustomerHelpRequest();
        r.sessionId = sessionId;
        return new List<CustomerHelpRequest>{ r };
    }

    @IsTest
    static void labelsExternalSourceAndUsesSpokenDate() {
        List<CustomerHelpRequest> reqs = setup('B1');
        Test.setMock(HttpCalloutMock.class, new BankMock(200));
        Test.startTest();
        CustomerHelpResponse resp = GetOutstandingBalanceAction.run(reqs)[0];
        Test.stopTest();
        System.assert(resp.success);
        System.assert(resp.dataSource.startsWith('External'));
        System.assert(resp.records[0].details.contains('Outstanding balance'));
        System.assert(!resp.records[0].primaryDate.contains('2026-'), 'no ISO date');
    }

    @IsTest
    static void upstreamFailureBecomesSafeGuidance() {
        List<CustomerHelpRequest> reqs = setup('B2');
        Test.setMock(HttpCalloutMock.class, new BankMock(500));
        Test.startTest();
        CustomerHelpResponse resp = GetOutstandingBalanceAction.run(reqs)[0];
        Test.stopTest();
        System.assertEquals('TEMPORARY_FAILURE', resp.errorCode);
        System.assert(!resp.agentGuidance.contains('500'));
    }

    @IsTest
    static void unverifiedSessionNeverCallsOut() {
        CustomerHelpRequest r = new CustomerHelpRequest();
        r.sessionId = 'nobody';
        CustomerHelpResponse resp = GetOutstandingBalanceAction.run(new List<CustomerHelpRequest>{ r })[0];
        System.assertEquals('NOT_VERIFIED', resp.errorCode);
    }
}