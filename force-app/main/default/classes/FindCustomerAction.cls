/**
 * Employee agent: finds customer Accounts by name, account number or phone. Runs in user mode, so an employee only
 * finds Accounts they are allowed to see.
 */
public with sharing class FindCustomerAction {
    public class Request {
        @InvocableVariable(required=true label='Search Text' description='Customer name (or part of it), account number, or phone number typed by the employee.')
        public String searchText;
        @InvocableVariable(label='Response Style' description='Voice agent only: return names and masked account numbers only.')
        public Boolean spokenStyle;
    }

    public class CustomerMatch {
        @InvocableVariable(label='Account Id') public String accountId;
        @InvocableVariable(label='Name') public String name;
        @InvocableVariable(label='Account Number') public String accountNumber;
        @InvocableVariable(label='Account Status') public String accountStatus;
        @InvocableVariable(label='Phone') public String phone;
    }

    public class Response {
        @InvocableVariable(label='Selected Account Id' description='Set only when exactly one customer matched; empty otherwise.') public String selectedAccountId;
        @InvocableVariable(label='Selected Customer Name') public String selectedName;
        @InvocableVariable(label='Match Count') public Integer matchCount;
        @InvocableVariable(label='Matches') public List<CustomerMatch> matches;
        @InvocableVariable(label='Agent Guidance') public String agentGuidance;
    }

    private static String maskTail(String v) {
        if (String.isBlank(v)) {
            return null;
        }
        String t = v.replaceAll('[^0-9A-Za-z]', '');
        return 'ending in ' + t.right(4);
    }

    @InvocableMethod(
        label='Find Customer'
        description='Searches accounts by customer name, account number or phone number and returns up to 5 matches.'
        category='Customer Help'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request r : requests) {
            Response resp = new Response();
            resp.matches = new List<CustomerMatch>();
            resp.matchCount = 0;
            try {
                String text = r.searchText == null ? '' : r.searchText.trim();
                if (text.length() < 2) {
                    resp.agentGuidance = 'Ask the employee for a customer name, account number or phone number.';
                } else {
                    String namePattern = '%' + text.replace('%', '').replace('_', '') + '%';
                    String digits = CustomerHelpPhone.normalize(text);
                    String phonePattern = (digits != null && digits.length() == 10)
                        ? '%' + digits.substring(0, 3) + '%' + digits.substring(3, 6) + '%' + digits.substring(6) : '__no_phone__';
                    for (Account a : [
                        SELECT Id, Name, AccountNumber, Phone, Account_Status__c FROM Account
                        WHERE Name LIKE :namePattern OR AccountNumber = :text OR Phone LIKE :phonePattern
                        WITH USER_MODE
                        ORDER BY Name LIMIT 5
                    ]) {
                        CustomerMatch m = new CustomerMatch();
                        m.accountId = a.Id;
                        m.name = a.Name;
                        m.accountNumber = r.spokenStyle == true ? maskTail(a.AccountNumber) : a.AccountNumber;
                        m.accountStatus = a.Account_Status__c;
                        m.phone = r.spokenStyle == true ? null : a.Phone;
                        resp.matches.add(m);
                    }
                    resp.matchCount = resp.matches.size();
                    if (resp.matchCount == 1) {
                        resp.selectedAccountId = resp.matches[0].accountId;
                        resp.selectedName = resp.matches[0].name;
                    }
                    resp.agentGuidance = resp.matchCount == 0
                        ? 'No customer matched. Say so and ask for another name, account number or phone number. Do not guess.'
                        : resp.matchCount == 1
                            ? 'One customer found. Confirm the name with the employee and continue.'
                            : 'Several customers matched. List their names and ask which one, or ask for the full account number; do not pick for them.';
                }
            } catch (Exception e) {
                CustomerHelpLog.record('FindCustomer', null, null, 'ERROR', e.getTypeName() + ': ' + e.getMessage());
                resp.agentGuidance = CustomerHelpRunner.GUIDE_FAILURE;
            }
            out.add(resp);
        }
        CustomerHelpLog.flush();
        return out;
    }
}