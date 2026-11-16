public with sharing class GetRequiredDocumentsAction {
    @InvocableMethod(
        label='Get Required Documents'
        description='Lists documents the verified customer still needs to provide (open document requests). Use for "what documents are still required" and "have you received my documents".'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Required_Documents', 'GetRequiredDocuments', requests);
    }
}