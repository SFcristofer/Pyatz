@isTest
private class FileServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'File Service Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'File Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testGetRelatedFiles_empty() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = FileService.getRelatedFiles(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetRelatedFiles_withPdf() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'test.pdf', PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('pdf content'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = opp.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        Test.startTest();
        List<Map<String, Object>> result = FileService.getRelatedFiles(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetAvailableAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, List<Map<String, String>>> result = FileService.getAvailableAttachments(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('quotes'));
        System.assert(result.containsKey('surveys'));
        System.assert(result.containsKey('files'));
    }

    @isTest
    static void testGetDocumentStates_empty() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, String> result = FileService.getDocumentStates(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetDocumentStates_withTaggedFile() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = '[CL_CONTRATO] - Contrato.pdf',
            PathOnClient = 'Contrato.pdf',
            VersionData = Blob.valueOf('content'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = opp.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        Test.startTest();
        Map<String, String> result = FileService.getDocumentStates(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('CL_CONTRATO'));
    }

    @isTest
    static void testGetEvidenceGallery_empty() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = FileService.getEvidenceGallery(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetEvidenceGallery_withImage() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = '[FOTO_1] - Evidencia',
            PathOnClient = 'img.jpg',
            VersionData = Blob.valueOf('img'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = opp.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        Test.startTest();
        List<Map<String, Object>> result = FileService.getEvidenceGallery(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetChecklist_empty() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = FileService.getChecklist(opp.Id, 'General');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetChecklist_null() {
        Test.startTest();
        List<Map<String, Object>> result = FileService.getChecklist(null, 'General');
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testRenameAndLinkFile() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'documento.pdf', PathOnClient = 'documento.pdf',
            VersionData = Blob.valueOf('data'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = opp.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        Test.startTest();
        FileService.renameAndLinkFile(docId, 'CL_TEST');
        Test.stopTest();
        ContentDocument doc = [SELECT Title FROM ContentDocument WHERE Id = :docId];
        System.assert(doc.Title.contains('CL_TEST'));
    }

    @isTest
    static void testDeleteDocument() {
        ContentVersion cv = new ContentVersion(
            Title = 'todelete.pdf', PathOnClient = 'todelete.pdf',
            VersionData = Blob.valueOf('del'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Test.startTest();
        FileService.deleteDocument(docId);
        Test.stopTest();
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :docId];
        System.assertEquals(0, docs.size());
    }
}