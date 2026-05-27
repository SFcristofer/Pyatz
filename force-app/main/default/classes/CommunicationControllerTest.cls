@isTest
private class CommunicationControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Comm Ctrl Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Comm Ctrl Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Quote q = new Quote(Name = 'Comm Quote', OpportunityId = opp.Id, Pricebook2Id = pb.Id, Status = 'Draft', AccountId = acc.Id);
        insert q;
    }

    @isTest
    static void testGetRelatedFiles() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = CommunicationController.getRelatedFiles(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetDocumentStates() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, String> result = CommunicationController.getDocumentStates(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetEvidenceGallery() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = CommunicationController.getEvidenceGallery(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testRenameUploadedFile() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'comm_file.pdf', PathOnClient = 'comm_file.pdf',
            VersionData = Blob.valueOf('pdf'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = docId, LinkedEntityId = opp.Id, ShareType = 'V', Visibility = 'AllUsers');
        Test.startTest();
        CommunicationController.renameUploadedFile(docId, 'CL_COMM');
        Test.stopTest();
        ContentDocument doc = [SELECT Title FROM ContentDocument WHERE Id = :docId];
        System.assert(doc.Title.contains('[CL_COMM]'));
    }

    @isTest
    static void testDeleteDocument() {
        ContentVersion cv = new ContentVersion(
            Title = 'comm_del.pdf', PathOnClient = 'comm_del.pdf',
            VersionData = Blob.valueOf('del'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Test.startTest();
        CommunicationController.deleteDocument(docId);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId]);
    }

    @isTest
    static void testGetEmailEngagementDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = CommunicationController.getEmailEngagementDetails(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetAvailableAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, List<Map<String, String>>> result = CommunicationController.getAvailableAttachments(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('quotes'));
        System.assert(result.containsKey('surveys'));
    }

    @isTest
    static void testGetEmailTemplatesByFolders() {
        Test.startTest();
        List<Map<String, String>> result = CommunicationController.getEmailTemplatesByFolders(new List<String>{'Test Folder'});
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetContactsFromLatestQuoteSedes_noQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, String>> result = CommunicationController.getContactsFromLatestQuoteSedes(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }
}
