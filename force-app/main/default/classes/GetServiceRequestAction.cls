public with sharing class GetServiceRequestAction {
    @InvocableMethod(
        label='Get Service Request'
        description='Gets status, created date and stage of the customer\'s service requests. Pass the request number as Record Hint if the customer gave one.'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Service_Request', 'GetServiceRequest', requests);
    }
}