@IsTest
private class ContactTriggerHandlerTest {

    @IsTest
    static void testContactCountFramework() {

        // Create Accounts
        Account acc1 = new Account(Name = 'Account One');
        Account acc2 = new Account(Name = 'Account Two');
        insert new List<Account>{acc1, acc2};

        // Insert Contacts
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'Contact 1', AccountId = acc1.Id),
            new Contact(LastName = 'Contact 2', AccountId = acc1.Id),
            new Contact(LastName = 'Contact 3', AccountId = acc1.Id)
        };

        Test.startTest();

        insert contacts;

        // Verify Insert
        Account updatedAcc = [
            SELECT Total_Contacts__c
            FROM Account
            WHERE Id = :acc1.Id
        ];

        System.assertEquals(3, updatedAcc.Total_Contacts__c);

        // Delete Contact
        delete contacts[0];

        updatedAcc = [
            SELECT Total_Contacts__c
            FROM Account
            WHERE Id = :acc1.Id
        ];

        System.assertEquals(2, updatedAcc.Total_Contacts__c);

        // Reassign Contact
        contacts[1].AccountId = acc2.Id;
        update contacts[1];

        Account updatedAcc1 = [
            SELECT Total_Contacts__c
            FROM Account
            WHERE Id = :acc1.Id
        ];

        Account updatedAcc2 = [
            SELECT Total_Contacts__c
            FROM Account
            WHERE Id = :acc2.Id
        ];

        System.assertEquals(1, updatedAcc1.Total_Contacts__c);
        System.assertEquals(1, updatedAcc2.Total_Contacts__c);

        // Undelete Contact
        undelete contacts[0];

        updatedAcc1 = [
            SELECT Total_Contacts__c
            FROM Account
            WHERE Id = :acc1.Id
        ];

        System.assertEquals(2, updatedAcc1.Total_Contacts__c);

        Test.stopTest();
    }
}