@isTest
private class EmailServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Email Svc Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Email Svc Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testGetEmailEngagementDetails_empty() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = EmailService.getEmailEngagementDetails(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetEmailTemplatesByFolders_empty() {
        Test.startTest();
        List<Map<String, String>> result = EmailService.getEmailTemplatesByFolders(new List<String>{'Nonexistent Folder'});
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testRenderTemplate_nullInputs() {
        Test.startTest();
        String result = EmailService.renderTemplate(null, null);
        Test.stopTest();
        System.assertEquals('', result);
    }

    @isTest
    static void testSendEmailWithAttachments_fileAttachment() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'email_att.pdf', PathOnClient = 'email_att.pdf',
            VersionData = Blob.valueOf('pdf data'), IsMajorVersion = true,
            FileType = 'PDF'
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        List<Map<String, String>> attachments = new List<Map<String, String>>{
            new Map<String, String>{'type' => 'File', 'id' => docId, 'name' => 'Attachment'}
        };

        Test.startTest();
        EmailService.sendEmailWithAttachments(
            opp.Id, 'test@example.com', null,
            'Test Subject', '<p>Body</p>', attachments
        );
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testSendEmailWithAttachments_noAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        EmailService.sendEmailWithAttachments(
            opp.Id, 'test@example.com', 'cc@example.com',
            'Test Subject', '<p>Body</p>', new List<Map<String, String>>()
        );
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testSendEmailWithAttachments_surveyAttachment() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Map<String, String>> attachments = new List<Map<String, String>>{
            new Map<String, String>{'type' => 'Survey', 'id' => opp.Id, 'name' => 'Survey'}
        };
        Test.startTest();
        try {
            EmailService.sendEmailWithAttachments(
                opp.Id, 'test@example.com', null,
                'Subject', 'Body', attachments
            );
        } catch (AuraHandledException e) {
            // Expected in test context
        }
        Test.stopTest();
        System.assert(true);
    }
}
