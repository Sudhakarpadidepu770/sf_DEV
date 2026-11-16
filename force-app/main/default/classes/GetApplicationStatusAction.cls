public with sharing class GetApplicationStatusAction {
    @InvocableMethod(
        label='Get Application Status'
        description='Gets the verified customer\'s application: number, status, created date, last activity, and next step. Use for "what happened to my application", "have you received my documents", "when did I submit".'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Application_Status', 'GetApplicationStatus', requests);
    }
}