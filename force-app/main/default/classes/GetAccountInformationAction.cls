public with sharing class GetAccountInformationAction {
    @InvocableMethod(
        label='Get Account Information'
        description='Gets account name, masked account number, type and opening date for the verified customer.'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Account_Information', 'GetAccountInformation', requests);
    }
}