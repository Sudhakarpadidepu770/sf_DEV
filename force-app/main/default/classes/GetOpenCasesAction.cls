public with sharing class GetOpenCasesAction {
    @InvocableMethod(
        label='Get Open Cases'
        description='Lists the verified customer\'s open support cases with status, priority and dates. Use for "do I have any open cases".'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Open_Cases', 'GetOpenCases', requests);
    }
}