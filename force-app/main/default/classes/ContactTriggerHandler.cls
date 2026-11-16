public class ContactTriggerHandler extends TriggerHandler {

    protected override void afterInsert() {

        Set<Id> accountIds = new Set<Id>();

        for (Contact con : (List<Contact>) Trigger.new) {
            if (con.AccountId != null) {
                accountIds.add(con.AccountId);
            }
        }

        PR_ContactCountService.updateContactCount(accountIds);
    }

    protected override void afterDelete() {

        Set<Id> accountIds = new Set<Id>();

        for (Contact con : (List<Contact>) Trigger.old) {
            if (con.AccountId != null) {
                accountIds.add(con.AccountId);
            }
        }

        PR_ContactCountService.updateContactCount(accountIds);
    }

    protected override void afterUndelete() {

        Set<Id> accountIds = new Set<Id>();

        for (Contact con : (List<Contact>) Trigger.new) {
            if (con.AccountId != null) {
                accountIds.add(con.AccountId);
            }
        }

        PR_ContactCountService.updateContactCount(accountIds);
    }

    protected override void afterUpdate() {

        Set<Id> accountIds = new Set<Id>();

        for (Contact con : (List<Contact>) Trigger.new) {

            Contact oldCon = (Contact) Trigger.oldMap.get(con.Id);

            if (con.AccountId != oldCon.AccountId) {

                if (con.AccountId != null) {
                    accountIds.add(con.AccountId);
                }

                if (oldCon.AccountId != null) {
                    accountIds.add(oldCon.AccountId);
                }
            }
        }

        PR_ContactCountService.updateContactCount(accountIds);
    }
}