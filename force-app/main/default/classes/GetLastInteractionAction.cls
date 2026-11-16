public with sharing class GetLastInteractionAction {
    @InvocableMethod(
        label='Get Last Interaction'
        description='Gets the date and subject of the customer\'s most recent interaction. Never returns internal notes.'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Last_Interaction', 'GetLastInteraction', requests);
    }
}