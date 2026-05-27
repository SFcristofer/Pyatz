@isTest
private class GeoPhotoControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'GeoPhoto Account');
        insert acc;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New');
        insert wo;
    }

    @isTest
    static void testGetWorkOrderInfo_workOrder() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Test.startTest();
        Map<String, String> result = GeoPhotoController.getWorkOrderInfo(wo.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('techName'));
    }

    @isTest
    static void testGetGeoPhotos_empty() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = GeoPhotoController.getGeoPhotos(wo.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testSaveGeoPhoto() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('photo data'));
        String b64Thumb = EncodingUtil.base64Encode(Blob.valueOf('thumb'));
        Test.startTest();
        GeoPhotoController.saveGeoPhoto(wo.Id, b64, b64Thumb, 'GeoFoto_20240101_120000.jpg',
            19.4326, -99.1332, 10);
        Test.stopTest();
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :wo.Id];
        System.assert(links.size() >= 1);
    }

    @isTest
    static void testSaveGeoPhoto_noThumb() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('data'));
        Test.startTest();
        GeoPhotoController.saveGeoPhoto(wo.Id, b64, null, 'GeoFoto_20240102_100000.jpg',
            null, null, null);
        Test.stopTest();
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :wo.Id];
        System.assert(links.size() >= 1);
    }

    @isTest
    static void testGetGeoPhotos_withData() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('photo'));
        GeoPhotoController.saveGeoPhoto(wo.Id, b64, b64, 'GeoFoto_20240103_090000.jpg', null, null, null);
        Test.startTest();
        List<Map<String, Object>> result = GeoPhotoController.getGeoPhotos(wo.Id);
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testGetPhotoContent() {
        ContentVersion cv = new ContentVersion(
            Title = 'GeoFoto_test.jpg', PathOnClient = 'GeoFoto_test.jpg',
            VersionData = Blob.valueOf('img'), IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Title = 'GeoFoto_test.jpg' LIMIT 1];
        Test.startTest();
        String result = GeoPhotoController.getPhotoContent(cv.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testDeleteGeoPhoto() {
        ContentVersion cv = new ContentVersion(
            Title = 'GeoFoto_del.jpg', PathOnClient = 'GeoFoto_del.jpg',
            VersionData = Blob.valueOf('del'), IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Title = 'GeoFoto_del.jpg' LIMIT 1];
        Test.startTest();
        GeoPhotoController.deleteGeoPhoto(cv.Id);
        Test.stopTest();
        List<ContentVersion> remaining = [SELECT Id FROM ContentVersion WHERE Title = 'GeoFoto_del.jpg' AND IsLatest = true];
        System.assertEquals(0, remaining.size());
    }
}
