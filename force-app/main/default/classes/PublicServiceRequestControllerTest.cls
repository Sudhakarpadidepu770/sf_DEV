@IsTest
private class PublicServiceRequestControllerTest {

    @IsTest
    static void testSubmitServiceRequest_success() {
        PublicServiceRequestController.ServiceRequestInput input = new PublicServiceRequestController.ServiceRequestInput();
        input.customerName = 'Raj Kumar';
        input.mobile = '9999999999';
        input.email = 'raj@example.com';
        input.address = 'Guntur';
        input.serviceCategory = 'Television';
        input.product = 'Samsung 55" Smart TV';
        input.problemDescription = 'TV is not switching ON.';
        input.preferredDate = String.valueOf(Date.today().addDays(1));
        input.preferredTimeWindow = 'Morning (9 AM - 12 PM)';
        input.priority = 'Medium';

        Test.startTest();
        PublicServiceRequestController.ServiceRequestResult result = PublicServiceRequestController.submitServiceRequest(input);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Expected a valid request to succeed');
        System.assertNotEquals(null, result.caseId, 'Expected a Case Id to be returned');
        System.assertNotEquals(null, result.caseNumber, 'Expected a Case Number to be returned');

        Case c = [SELECT Service_Category__c, Priority, Origin, SuppliedName, Preferred_Time_Window__c FROM Case WHERE Id = :result.caseId];
        System.assertEquals('Television', c.Service_Category__c);
        System.assertEquals('Medium', c.Priority);
        System.assertEquals('Web', c.Origin);
        System.assertEquals('Raj Kumar', c.SuppliedName);
        System.assertEquals('Morning (9 AM - 12 PM)', c.Preferred_Time_Window__c);
    }

    @IsTest
    static void testSubmitServiceRequest_missingRequiredFields() {
        PublicServiceRequestController.ServiceRequestInput input = new PublicServiceRequestController.ServiceRequestInput();
        input.customerName = 'Incomplete Request';
        // no contact info, no serviceCategory, no problemDescription

        Test.startTest();
        PublicServiceRequestController.ServiceRequestResult result = PublicServiceRequestController.submitServiceRequest(input);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected an incomplete request to be rejected');
        System.assertEquals(0, [SELECT COUNT() FROM Case], 'No Case should have been created');
    }

    @IsTest
    static void testSubmitServiceRequest_invalidCategoryRejected() {
        PublicServiceRequestController.ServiceRequestInput input = new PublicServiceRequestController.ServiceRequestInput();
        input.customerName = 'Bad Category';
        input.mobile = '9999999999';
        input.serviceCategory = 'Not A Real Category';
        input.problemDescription = 'test';

        Test.startTest();
        PublicServiceRequestController.ServiceRequestResult result = PublicServiceRequestController.submitServiceRequest(input);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected an unrecognized service category to be rejected');
        System.assertEquals(0, [SELECT COUNT() FROM Case], 'No Case should have been created');
    }

    @IsTest
    static void testAttachPhotoToCase_validImage() {
        Case c = new Case(Subject = 'Test Case For Attachment', Status = 'New', Origin = 'Web');
        insert c;

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('fake image bytes'));

        Test.startTest();
        String outcome = PublicServiceRequestController.attachPhotoToCase(c.Id, 'appliance.jpg', base64Data);
        Test.stopTest();

        System.assertEquals('OK', outcome);
        System.assertEquals(1, [SELECT COUNT() FROM ContentVersion WHERE PathOnClient = 'appliance.jpg']);
    }

    @IsTest
    static void testAttachPhotoToCase_rejectsDisallowedExtension() {
        Case c = new Case(Subject = 'Test Case For Attachment', Status = 'New', Origin = 'Web');
        insert c;

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('not really an executable'));

        Test.startTest();
        String outcome = PublicServiceRequestController.attachPhotoToCase(c.Id, 'malware.exe', base64Data);
        Test.stopTest();

        System.assertNotEquals('OK', outcome);
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE PathOnClient = 'malware.exe']);
    }

    @IsTest
    static void testAttachPhotoToCase_missingParams() {
        Test.startTest();
        String outcome = PublicServiceRequestController.attachPhotoToCase(null, null, null);
        Test.stopTest();

        System.assertEquals('Missing file information.', outcome);
    }
}