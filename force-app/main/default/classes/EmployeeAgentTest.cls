@IsTest
private class EmployeeAgentTest {
    @TestSetup
    static void setup() {
        Account a = new Account(Name = 'Priya Sharma', AccountNumber = 'AC-10000001', Phone = '(555) 010-1001', Account_Status__c = 'Active');
        Account b = new Account(Name = 'Priya Patel', AccountNumber = 'AC-10000009', Phone = '(555) 010-1009');
        insert new List<Account>{ a, b };
        insert new Case(Subject = 'Card not received', AccountId = a.Id, Status = 'New');
        insert new Opportunity(Name = 'APP-1', AccountId = a.Id, StageName = 'Qualification', CloseDate = Date.today().addDays(9), NextStep = 'Upload ID');
    }

    private static FindCustomerAction.Response find(String text) {
        FindCustomerAction.Request r = new FindCustomerAction.Request();
        r.searchText = text;
        return FindCustomerAction.run(new List<FindCustomerAction.Request>{ r })[0];
    }

    @IsTest
    static void findsByNameNumberAndPhone() {
        System.assertEquals(2, find('Priya').matchCount);
        System.assertEquals(1, find('AC-10000001').matchCount);
        System.assertEquals(1, find('555-010-1001').matchCount);
        System.assertEquals(0, find('Nobody Here').matchCount);
        System.assertEquals(0, find('x').matchCount);
    }

    @IsTest
    static void dataActionsWorkFromSelectedAccountWithoutSession() {
        Account a = [SELECT Id FROM Account WHERE AccountNumber = 'AC-10000001'];
        CustomerHelpRequest r = new CustomerHelpRequest();
        r.accountId = a.Id;
        List<CustomerHelpRequest> reqs = new List<CustomerHelpRequest>{ r };

        CustomerHelpResponse cases = GetOpenCasesAction.run(reqs)[0];
        System.assertEquals(1, cases.recordCount);
        CustomerHelpResponse app = GetApplicationStatusAction.run(reqs)[0];
        System.assertEquals('Qualification', app.records[0].status);
        System.assert(app.records[0].primaryDate.startsWith(Datetime.now().format('MMM d, yyyy')), 'written date, not spoken');
        CustomerHelpResponse acct = GetAccountInformationAction.run(reqs)[0];
        System.assert(acct.records[0].details.contains('AC-10000001'), 'employees see the full account number');
    }

    @IsTest
    static void neitherAccountNorSessionFailsSafely() {
        CustomerHelpResponse resp = GetOpenCasesAction.run(new List<CustomerHelpRequest>{ new CustomerHelpRequest() })[0];
        System.assert(!resp.success);
    }

    @IsTest
    static void spokenStyleGivesSpokenMaskedAnswers() {
        Account a = [SELECT Id FROM Account WHERE AccountNumber = 'AC-10000001'];
        CustomerHelpRequest r = new CustomerHelpRequest();
        r.accountId = a.Id;
        r.spokenStyle = true;
        List<CustomerHelpRequest> reqs = new List<CustomerHelpRequest>{ r };

        CustomerHelpResponse acct = GetAccountInformationAction.run(reqs)[0];
        System.assert(acct.records[0].details.contains('ending in 0 0 0 1'));
        System.assertEquals('today', acct.records[0].primaryDate);
        System.assertEquals('currently being processed', GetApplicationStatusAction.run(reqs)[0].records[0].status);

        FindCustomerAction.Request f = new FindCustomerAction.Request();
        f.searchText = 'Priya';
        f.spokenStyle = true;
        FindCustomerAction.Response found = FindCustomerAction.run(new List<FindCustomerAction.Request>{ f })[0];
        System.assertEquals(2, found.matchCount);
        System.assertEquals(null, found.matches[0].phone, 'voice lookup never returns phone numbers');
        System.assert(found.matches[0].accountNumber.startsWith('ending in'));
    }
}