/** Standard objects (Account, Case, Opportunity, Task) via the CustomerHelpDataSources registry; Account_Status__c is the one custom field. */
@IsTest
private class CustomerHelpDataServiceTest {
    private static Id verify(String sessionId, Id accountId) {
        CustomerHelpIdentityService.storeVerified(sessionId, accountId);
        return accountId;
    }

    private static List<CustomerHelpRequest> req(String sessionId) {
        CustomerHelpRequest r = new CustomerHelpRequest();
        r.sessionId = sessionId;
        return new List<CustomerHelpRequest>{ r };
    }

    @IsTest
    static void returnsOnlyTheVerifiedCustomersOpenCases() {
        Account mine = new Account(Name = 'Mine');
        Account other = new Account(Name = 'Other');
        insert new List<Account>{ mine, other };
        insert new List<Case>{
            new Case(Subject = 'My open case', AccountId = mine.Id, Status = 'New'),
            new Case(Subject = 'Someone elses case', AccountId = other.Id, Status = 'New')
        };
        verify('D1', mine.Id);

        List<CustomerHelpResponse> res = GetOpenCasesAction.run(req('D1'));

        System.assert(res[0].success);
        System.assertEquals(1, res[0].recordCount);
        System.assert(res[0].records[0].details.contains('My open case'));
        System.assert(!res[0].records[0].details.contains('Someone elses'));
        System.assertEquals('Salesforce', res[0].dataSource);
        System.assertEquals('received and waiting to be picked up', res[0].records[0].status);
    }

    @IsTest
    static void applicationStatusUsesOpportunityStageAndNextStep() {
        Account a = new Account(Name = 'Applicant');
        insert a;
        insert new Opportunity(Name = 'APP-1001', AccountId = a.Id, StageName = 'Qualification',
            CloseDate = Date.today().addDays(30), NextStep = 'Upload proof of address');
        verify('D5', a.Id);

        CustomerHelpResponse resp = GetApplicationStatusAction.run(req('D5'))[0];

        System.assertEquals(1, resp.recordCount);
        System.assertEquals('currently being processed', resp.records[0].status);
        System.assert(resp.records[0].details.contains('Upload proof of address'));
        System.assertEquals('today', resp.records[0].primaryDate);
    }

    @IsTest
    static void requiredDocumentsComeFromOpenDocumentTasks() {
        Account a = new Account(Name = 'Docs');
        insert a;
        insert new List<Task>{
            new Task(Subject = 'Document: proof of income', WhatId = a.Id, Status = 'Not Started'),
            new Task(Subject = 'Document: ID copy', WhatId = a.Id, Status = 'Completed'),
            new Task(Subject = 'Call customer', WhatId = a.Id, Status = 'Not Started')
        };
        verify('D6', a.Id);
        CustomerHelpResponse resp = GetRequiredDocumentsAction.run(req('D6'))[0];
        System.assertEquals(1, resp.recordCount);
        System.assert(resp.records[0].details.contains('proof of income'));
    }

    @IsTest
    static void lastInteractionIgnoresAgentAuditTasks() {
        Account a = new Account(Name = 'Chatty');
        insert a;
        insert new List<Task>{
            new Task(Subject = 'Branch visit', WhatId = a.Id, Status = 'Completed'),
            new Task(Subject = CustomerHelpLog.SUBJECT_PREFIX + 'GetOpenCases - FOUND', WhatId = a.Id, Status = 'Completed')
        };
        verify('D7', a.Id);
        CustomerHelpResponse resp = GetLastInteractionAction.run(req('D7'))[0];
        System.assertEquals(1, resp.recordCount);
        System.assert(resp.records[0].details.contains('Branch visit'));
    }

    @IsTest
    static void unverifiedSessionGetsNoData() {
        List<CustomerHelpResponse> res = GetOpenCasesAction.run(req('unknown'));
        System.assert(!res[0].success);
        System.assertEquals('NOT_VERIFIED', res[0].errorCode);
        System.assertEquals(0, res[0].recordCount);
    }

    @IsTest
    static void emptyResultIsExplicitNotInvented() {
        Account c = new Account(Name = 'NoCases');
        insert c;
        verify('D2', c.Id);
        List<CustomerHelpResponse> res = GetOpenCasesAction.run(req('D2'));
        System.assert(res[0].success);
        System.assertEquals(0, res[0].recordCount);
        System.assert(res[0].agentGuidance.contains('couldn\'t find'));
    }

    @IsTest
    static void accountNumberIsMasked() {
        Account c = new Account(Name = 'Masked', AccountNumber = 'AC-99887766', Account_Status__c = 'Suspended');
        insert c;
        verify('D8', c.Id);
        CustomerHelpResponse resp = GetAccountInformationAction.run(req('D8'))[0];
        System.assert(resp.records[0].details.contains('ending in 7 7 6 6'));
        System.assert(!resp.records[0].details.contains('99887766'));
        System.assertEquals('temporarily suspended', resp.records[0].status);
    }

    @IsTest
    static void unknownOrInactiveIntentFailsSafely() {
        Account c = new Account(Name = 'X');
        insert c;
        verify('D3', c.Id);
        for (String intent : new List<String>{ 'No_Such_Intent', 'Work_Orders' }) {
            CustomerHelpResponse resp = CustomerHelpRunner.run(intent, 'Test', req('D3'))[0];
            System.assertEquals('TEMPORARY_FAILURE', resp.errorCode);
            System.assert(!resp.agentGuidance.contains(intent), 'no technical details leak');
        }
    }
}