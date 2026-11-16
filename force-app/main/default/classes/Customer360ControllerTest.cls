@IsTest
private class Customer360ControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test 360 Household', Customer_Type__c = 'Individual', BillingCity = 'Guntur');
        insert acc;
        Contact con = new Contact(AccountId = acc.Id, FirstName = 'Test', LastName = 'Customer', Phone = '9999999999', Email = 'test360@example.com');
        insert con;
        Asset ast = new Asset(Name = 'TEST-AST-001', AccountId = acc.Id, Description = 'Test TV', Status = 'Installed', SerialNumber = 'SN12345', InstallDate = Date.today().addDays(-100));
        insert ast;
        insert new AssetWarranty(AssetId = ast.Id, StartDate = Date.today().addDays(-100), EndDate = Date.today().addYears(1));

        Case c = new Case(Subject = 'Test Issue', AccountId = acc.Id, AssetId = ast.Id, Status = 'New', Priority = 'Medium', Service_Category__c = 'Television', Origin = 'Phone');
        insert c;

        WorkType wt = new WorkType(Name = 'Test Repair Type', EstimatedDuration = 60, DurationType = 'Minutes');
        insert wt;
        WorkOrder wo = new WorkOrder(Subject = 'Test WO', AssetId = ast.Id, CaseId = c.Id, WorkTypeId = wt.Id, Status = 'Completed', Priority = 'Medium');
        insert wo;

        OperatingHours oh = new OperatingHours(Name = 'Test OH 360', TimeZone = 'Asia/Kolkata');
        insert oh;
        ServiceTerritory st = new ServiceTerritory(Name = 'Test Territory 360', IsActive = true, OperatingHoursId = oh.Id);
        insert st;
        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = wo.Id, Subject = 'Test SA', ServiceTerritoryId = st.Id);
        insert sa;
    }

    @IsTest
    static void testSearchCustomers_matches() {
        Test.startTest();
        List<Customer360Controller.SearchResult> results = Customer360Controller.searchCustomers('Test 360');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one matching account');
        System.assertEquals('Test 360 Household', results[0].name);
    }

    @IsTest
    static void testSearchCustomers_blankReturnsEmpty() {
        Test.startTest();
        List<Customer360Controller.SearchResult> results = Customer360Controller.searchCustomers('a');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Single-character search should return no results');
    }

    @IsTest
    static void testGetCustomer360_fullData() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test 360 Household' LIMIT 1];

        Test.startTest();
        Customer360Controller.Customer360Data data = Customer360Controller.getCustomer360(acc.Id);
        Test.stopTest();

        System.assertEquals('Test 360 Household', data.accountName);
        System.assertEquals('Individual', data.customerType);
        System.assertEquals('Test Customer', data.primaryContactName);
        System.assertEquals(1, data.totalAssets);
        System.assertEquals(1, data.assets.size());
        System.assertEquals(true, data.assets[0].underWarranty);
        System.assertEquals(1, data.assets[0].serviceCount);
        System.assertEquals(1, data.cases.size());
        System.assertEquals(1, data.openCases);
        System.assertEquals(1, data.workOrders.size());
        System.assertEquals(1, data.completedServices);
        System.assertEquals(1, data.appointments.size());
    }

    @IsTest
    static void testGetCustomer360_nullIdReturnsEmptyShell() {
        Test.startTest();
        Customer360Controller.Customer360Data data = Customer360Controller.getCustomer360(null);
        Test.stopTest();

        System.assertEquals(null, data.accountId);
        System.assertEquals(0, data.assets.size());
        System.assertEquals(0, data.cases.size());
    }
}