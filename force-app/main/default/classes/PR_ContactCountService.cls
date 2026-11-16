public class PR_ContactCountService {
    
    public static void updateContactCount(Set<Id> accountIds) {

        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> contactCountMap =
            new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) totalCount
            FROM Contact
            WHERE AccountId IN :accountIds
            GROUP BY AccountId
        ]) {

            contactCountMap.put(
                (Id) ar.get('AccountId'),
                (Integer) ar.get('totalCount')
            );
        }

        List<Account> accountsToUpdate = new List<Account>();

        for (Id accountId : accountIds) {

            Integer totalCount = contactCountMap.containsKey(accountId)
                ? contactCountMap.get(accountId)
                : 0;

            accountsToUpdate.add(new Account(
                Id = accountId,
                Total_Contacts__c = totalCount
            ));
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

}