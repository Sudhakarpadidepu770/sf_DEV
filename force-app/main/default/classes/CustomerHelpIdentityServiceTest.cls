@IsTest
private class CustomerHelpIdentityServiceTest {
    private class SmsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(202);
            return r;
        }
    }

    @TestSetup
    static void setup() {
        insert new Account(Name = 'Tia Tester', Phone = '+1 (555) 010-1234');
    }

    @IsTest
    static void happyPathVerifiesSession() {
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        CustomerHelpIdentityService.start('S1', '555-010-1234');

        CustomerHelpIdentityService.CheckResult res = CustomerHelpIdentityService.check('S1', CustomerHelpIdentityService.capturedCode);
        System.assert(res.verified);
        System.assertEquals('Tia Tester', res.customerName);
        System.assertNotEquals(null, CustomerHelpIdentityService.requireVerifiedAccount('S1'));
    }

    @IsTest
    static void spokenDigitsWithSpacesAreAccepted() {
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        CustomerHelpIdentityService.start('S2', '5550101234');
        List<String> chars = new List<String>();
        for (Integer i = 0; i < 6; i++) {
            chars.add(CustomerHelpIdentityService.capturedCode.substring(i, i + 1));
        }
        System.assert(CustomerHelpIdentityService.check('S2', String.join(chars, ' ')).verified);
    }

    @IsTest
    static void threeBadCodesLockTheSession() {
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        CustomerHelpIdentityService.start('S3', '5550101234');
        String wrong = CustomerHelpIdentityService.capturedCode == '000000' ? '111111' : '000000';
        CustomerHelpIdentityService.CheckResult r;
        for (Integer i = 0; i < CustomerHelpIdentityService.MAX_ATTEMPTS; i++) {
            r = CustomerHelpIdentityService.check('S3', wrong);
        }
        System.assert(r.locked);
        // even the right code no longer works after lockout
        System.assert(!CustomerHelpIdentityService.check('S3', CustomerHelpIdentityService.capturedCode).verified);
        try {
            CustomerHelpIdentityService.requireVerifiedAccount('S3');
            System.assert(false, 'should not be verified');
        } catch (CustomerHelpIdentityService.CustomerHelpAuthException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void unknownNumberSilentlyDoesNothing() {
        CustomerHelpIdentityService.StartResult r = CustomerHelpIdentityService.start('S4', '999-999-9999');
        System.assert(r.accepted);
        System.assertEquals(null, CustomerHelpIdentityService.capturedCode);
    }

    @IsTest
    static void sendsAreRateLimited() {
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        for (Integer i = 0; i < CustomerHelpIdentityService.MAX_SENDS_PER_HOUR; i++) {
            CustomerHelpIdentityService.start('R' + i, '5550101234');
        }
        System.assert(CustomerHelpIdentityService.start('R9', '5550101234').rateLimited);
    }

    @IsTest
    static void unverifiedSessionIsRejected() {
        try {
            CustomerHelpIdentityService.requireVerifiedAccount('nope');
            System.assert(false);
        } catch (CustomerHelpIdentityService.CustomerHelpAuthException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void callerIdIdentifiesWithoutCode() {
        CustomerHelpIdentityService.CheckResult r = CustomerHelpIdentityService.identifyByCallerId('C1', '+1 555 010 1234');
        System.assert(r.verified);
        System.assertEquals('Tia Tester', r.customerName);
        System.assertNotEquals(null, CustomerHelpIdentityService.requireVerifiedAccount('C1'));
    }

    @IsTest
    static void unknownCallerIdIsNotIdentified() {
        System.assert(!CustomerHelpIdentityService.identifyByCallerId('C2', '999-999-9999').verified);
        try {
            CustomerHelpIdentityService.requireVerifiedAccount('C2');
            System.assert(false);
        } catch (CustomerHelpIdentityService.CustomerHelpAuthException e) {
            System.assert(true);
        }
    }
}