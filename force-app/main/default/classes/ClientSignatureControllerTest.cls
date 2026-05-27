@isTest
private class ClientSignatureControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Sig Test Account');
        insert acc;
    }

    @isTest
    static void testSaveSignaturePair_withThumb() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy data'));
        Test.startTest();
        ClientSignatureController.saveSignaturePair(
            acc.Id, base64Data, base64Data, base64Data,
            'SignClean_test.png', 'Firma_test.png', 'Juan Perez'
        );
        Test.stopTest();
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :acc.Id];
        System.assert(links.size() >= 2);
    }

    @isTest
    static void testSaveSignaturePair_noThumb() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('data'));
        Test.startTest();
        ClientSignatureController.saveSignaturePair(
            acc.Id, base64Data, base64Data, null,
            'SignClean_x.png', 'Firma_x.png', 'Ana Lopez'
        );
        Test.stopTest();
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title IN ('SignClean_x.png','Firma_x.png')];
        System.assertEquals(2, cvs.size());
    }

    @isTest
    static void testGetSignatureContent() {
        ContentVersion cv = new ContentVersion(
            Title = 'TestCV', PathOnClient = 'TestCV.txt',
            VersionData = Blob.valueOf('content'), IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id FROM ContentVersion WHERE Title = 'TestCV' LIMIT 1];
        Test.startTest();
        String result = ClientSignatureController.getSignatureContent(cv.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetSignatures_empty() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = ClientSignatureController.getSignatures(acc.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetSignatures_withData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('img'));
        ClientSignatureController.saveSignaturePair(
            acc.Id, b64, b64, b64,
            'SignClean_ABC.png', 'Firma_ABC.png', 'Signer'
        );
        Test.startTest();
        List<Map<String, Object>> result = ClientSignatureController.getSignatures(acc.Id);
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testDeleteSignature() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('del'));
        ClientSignatureController.saveSignaturePair(
            acc.Id, b64, b64, null,
            'SignClean_DEL.png', 'Firma_DEL.png', 'Del User'
        );
        ContentVersion infoCV = [SELECT Id FROM ContentVersion WHERE Title = 'Firma_DEL.png' LIMIT 1];
        ContentVersion cleanCV = [SELECT Id FROM ContentVersion WHERE Title = 'SignClean_DEL.png' LIMIT 1];
        Test.startTest();
        ClientSignatureController.deleteSignature(infoCV.Id, cleanCV.Id);
        Test.stopTest();
        List<ContentVersion> remaining = [SELECT Id FROM ContentVersion WHERE Title IN ('Firma_DEL.png','SignClean_DEL.png') AND IsLatest = true];
        System.assertEquals(0, remaining.size());
    }
}
