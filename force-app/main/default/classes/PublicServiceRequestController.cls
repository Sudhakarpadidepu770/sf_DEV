public with sharing class PublicServiceRequestController {

    public class ServiceRequestInput {
        @AuraEnabled public String customerName;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String address;
        @AuraEnabled public String serviceCategory;
        @AuraEnabled public String product;
        @AuraEnabled public String problemDescription;
        @AuraEnabled public String preferredDate;
        @AuraEnabled public String preferredTimeWindow;
        @AuraEnabled public String priority;
    }

    public class ServiceRequestResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String message;
    }

    private static final Set<String> ALLOWED_CATEGORIES = new Set<String>{
        'Television', 'Air Conditioner', 'Refrigerator', 'Washing Machine', 'Laptop',
        'Printer', 'Microwave', 'Electrical', 'Installation', 'Maintenance'
    };
    private static final Set<String> ALLOWED_TIME_WINDOWS = new Set<String>{
        'Morning (9 AM - 12 PM)', 'Afternoon (12 PM - 4 PM)', 'Evening (4 PM - 7 PM)'
    };
    private static final Set<String> ALLOWED_PRIORITIES = new Set<String>{'High', 'Medium', 'Low'};
    private static final Set<String> ALLOWED_FILE_EXTENSIONS = new Set<String>{'.jpg', '.jpeg', '.png', '.pdf'};
    private static final Integer MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024;

    /**
     * Public, unauthenticated entry point for the "Request a Service" guest site form.
     * Only ever inserts a Case with an explicit field allowlist under AccessLevel.USER_MODE —
     * never returns the internal record Id in a way that grants further access, and never
     * exposes a SOQL query surface to the client.
     */
    @AuraEnabled
    public static ServiceRequestResult submitServiceRequest(ServiceRequestInput input) {
        ServiceRequestResult result = new ServiceRequestResult();
        result.success = false;
        try {
            if (input == null || String.isBlank(input.customerName) || String.isBlank(input.problemDescription)
                || String.isBlank(input.serviceCategory) || (String.isBlank(input.mobile) && String.isBlank(input.email))) {
                result.message = 'Please complete all required fields: name, at least one contact method, service type, and problem description.';
                return result;
            }
            if (!ALLOWED_CATEGORIES.contains(input.serviceCategory)) {
                result.message = 'Please choose a valid service type.';
                return result;
            }

            String priority = ALLOWED_PRIORITIES.contains(input.priority) ? input.priority : 'Medium';
            String timeWindow = ALLOWED_TIME_WINDOWS.contains(input.preferredTimeWindow) ? input.preferredTimeWindow : null;

            Date preferredDate = null;
            if (String.isNotBlank(input.preferredDate)) {
                try {
                    preferredDate = Date.valueOf(input.preferredDate);
                } catch (Exception parseEx) {
                    // Ignore an unparseable date rather than failing the whole request.
                }
            }

            String subject = input.serviceCategory + (String.isNotBlank(input.product) ? ' - ' + input.product.left(80) : '');
            String description = 'Problem: ' + input.problemDescription.left(2000)
                + (String.isNotBlank(input.address) ? '\nAddress: ' + input.address.left(500) : '')
                + (String.isNotBlank(input.product) ? '\nProduct: ' + input.product.left(255) : '');

            Case c = new Case(
                Subject = subject.left(255),
                Description = description,
                Origin = 'Web',
                Priority = priority,
                Service_Category__c = input.serviceCategory,
                Preferred_Service_Date__c = preferredDate,
                Preferred_Time_Window__c = timeWindow,
                SuppliedName = input.customerName.left(80),
                SuppliedEmail = String.isNotBlank(input.email) ? input.email.left(80) : null,
                SuppliedPhone = String.isNotBlank(input.mobile) ? input.mobile.left(40) : null
            );
            Database.insert(c, AccessLevel.USER_MODE);

            Case inserted = [SELECT Id, CaseNumber FROM Case WHERE Id = :c.Id WITH USER_MODE];
            result.success = true;
            result.caseId = inserted.Id;
            result.caseNumber = inserted.CaseNumber;
            result.message = 'Thank you! Your service request has been received.';
        } catch (Exception e) {
            result.message = 'We could not submit your request right now. Please try again in a few minutes.';
        }
        return result;
    }

    /**
     * Optional second step: attach a photo of the appliance to the Case just created above.
     * Extension/size validated server-side (never trust client-side checks alone). FirstPublishLocationId
     * relies on the guest owning (and therefore being able to read) the Case it just created — a caseId
     * belonging to any other record will simply fail the insert under AccessLevel.USER_MODE.
     */
    @AuraEnabled
    public static String attachPhotoToCase(String caseId, String fileName, String base64Data) {
        try {
            if (String.isBlank(caseId) || String.isBlank(fileName) || String.isBlank(base64Data)) {
                return 'Missing file information.';
            }
            String lowerName = fileName.toLowerCase();
            Boolean validExtension = false;
            for (String ext : ALLOWED_FILE_EXTENSIONS) {
                if (lowerName.endsWith(ext)) {
                    validExtension = true;
                    break;
                }
            }
            if (!validExtension) {
                return 'Only JPG, PNG, or PDF files are allowed.';
            }

            Blob fileBlob;
            try {
                fileBlob = EncodingUtil.base64Decode(base64Data);
            } catch (Exception decodeEx) {
                return 'The uploaded file could not be read.';
            }
            if (fileBlob.size() > MAX_FILE_SIZE_BYTES) {
                return 'File is too large. Maximum size is 5 MB.';
            }

            ContentVersion cv = new ContentVersion(
                PathOnClient = fileName.left(255),
                Title = fileName.left(255),
                VersionData = fileBlob,
                FirstPublishLocationId = caseId
            );
            Database.insert(cv, AccessLevel.USER_MODE);
            return 'OK';
        } catch (Exception e) {
            return 'We could not attach your photo right now.';
        }
    }
}