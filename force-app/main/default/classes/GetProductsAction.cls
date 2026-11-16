public with sharing class GetProductsAction {
    @InvocableMethod(
        label='Get Products'
        description='Lists products/assets the verified customer holds.'
        category='Customer Help'
    )
    public static List<CustomerHelpResponse> run(List<CustomerHelpRequest> requests) {
        return CustomerHelpRunner.run('Products_Held', 'GetProducts', requests);
    }
}