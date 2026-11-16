public with sharing class GetCustomerProfileAction {
    @InvocableMethod(
        label='Get Customer Profile'
        description='Gets the verified customer\'s name and masked mobile number. Use for "what information do you have about me".'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Customer_Profile', 'GetCustomerProfile', requests);
    }
}