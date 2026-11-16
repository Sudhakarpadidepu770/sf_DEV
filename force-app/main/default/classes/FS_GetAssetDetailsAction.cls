/**
 * Agentforce action: retrieves details for a customer's Asset (appliance/equipment), including warranty status.
 * Input: assetName (required, e.g. "TV-GNT-001" or a partial match on the description like "Samsung").
 * Output: matching AssetDetail rows, capped at 10.
 */
public with sharing class FS_GetAssetDetailsAction {

    public class Request {
        @InvocableVariable(required=true label='Asset Name' description='Asset name or partial name, e.g. "TV-GNT-001" or "TV-GNT".')
        public String assetName;
    }

    public class AssetDetail {
        @InvocableVariable public String assetName;
        @InvocableVariable public String product;
        @InvocableVariable public String customerName;
        @InvocableVariable public String status;
        @InvocableVariable public String serialNumber;
        @InvocableVariable public String installDate;
        @InvocableVariable public String warrantyEndDate;
        @InvocableVariable public Boolean underWarranty;
    }

    public class Result {
        @InvocableVariable(label='Assets')
        public List<AssetDetail> assetDetails = new List<AssetDetail>();
    }

    @InvocableMethod(
        label='Get Asset Details'
        description='Returns details (product, customer, warranty status) for a customer asset matched by name or description.'
        category='Field Service'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            Result res = new Result();
            List<AssetDetail> rows = res.assetDetails;
            try {
                if (String.isNotBlank(r.assetName)) {
                    String likeTerm = '%' + r.assetName + '%';
                    Map<Id, AssetWarranty> warrantyByAsset = new Map<Id, AssetWarranty>();
                    List<Asset> assets = [
                        SELECT Name, Description, Status, SerialNumber, InstallDate, Account.Name
                        FROM Asset
                        WHERE Name LIKE :likeTerm
                        WITH USER_MODE
                        LIMIT 10
                    ];
                    Set<Id> assetIds = new Set<Id>();
                    for (Asset a : assets) assetIds.add(a.Id);
                    for (AssetWarranty w : [SELECT AssetId, EndDate FROM AssetWarranty WHERE AssetId IN :assetIds WITH USER_MODE]) {
                        warrantyByAsset.put(w.AssetId, w);
                    }
                    for (Asset a : assets) {
                        AssetDetail ad = new AssetDetail();
                        ad.assetName = a.Name;
                        ad.product = a.Description;
                        ad.customerName = a.Account != null ? a.Account.Name : null;
                        ad.status = a.Status;
                        ad.serialNumber = a.SerialNumber;
                        ad.installDate = a.InstallDate != null ? String.valueOf(a.InstallDate) : null;
                        AssetWarranty w = warrantyByAsset.get(a.Id);
                        if (w != null && w.EndDate != null) {
                            ad.warrantyEndDate = String.valueOf(w.EndDate);
                            ad.underWarranty = w.EndDate >= Date.today();
                        } else {
                            ad.underWarranty = false;
                        }
                        rows.add(ad);
                    }
                }
            } catch (Exception e) {
                // Sanitized: never leak internal error text to the agent/user.
            }
            out.add(res);
        }
        return out;
    }
}