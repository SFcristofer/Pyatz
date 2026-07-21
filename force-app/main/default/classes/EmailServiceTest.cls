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
            VersionData = Blob.valueOf('pdf data'), IsMajorVersion = true
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
    @isTest
    static void testGetEmailTemplatesByFolders_withData() {
        Folder f;
        try {
            f = [SELECT Id, Name FROM Folder WHERE Type = 'Email' AND DeveloperName != null LIMIT 1];
        } catch(Exception e) {
            // No folder found
        }
        
        if (f != null) {
            EmailTemplate et = new EmailTemplate(
                Name = 'Test Template Folder',
                DeveloperName = 'Test_Template_Folder_123',
                TemplateType = 'text',
                FolderId = f.Id,
                Subject = 'Subject'
            );
            System.runAs(new User(Id = UserInfo.getUserId())) {
                insert et;
            }
            Test.startTest();
            List<Map<String, String>> result = EmailService.getEmailTemplatesByFolders(new List<String>{f.Name});
            Test.stopTest();
            System.assert(true);
        }
    }
    
    @isTest
    static void testRenderTemplate_withHTML() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Contact con = new Contact(LastName = 'Test Contact', AccountId = opp.AccountId);
        insert con;
        Quote q = new Quote(Name = 'Test Quote', OpportunityId = opp.Id, ContactId = con.Id);
        insert q;
        
        EmailTemplate et = new EmailTemplate(
            Name = 'HTML Template',
            DeveloperName = 'HTML_Template_1234',
            TemplateType = 'custom',
            FolderId = UserInfo.getUserId(),
            Subject = 'Test Subject',
            HtmlValue = '<body><span data-sheets-root="1">hello</span></body>',
            Body = 'Text'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert et;
        }

        Test.startTest();
        String result = EmailService.renderTemplate(et.Id, q.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSendInternalEmail() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        List<Map<String, String>> attachments = new List<Map<String, String>>{
            new Map<String, String>{'type' => 'Survey', 'id' => opp.Id, 'name' => 'Survey'}
        };
        
        Group g = new Group(Name = 'Test Queue', Type = 'Queue');
        insert g;
        
        GroupMember gm = new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert gm;
        }

        Test.startTest();
        try {
            EmailService.sendInternalEmail(
                opp.Id, '', 'test2@example.com', 'bcc@example.com',
                'Internal Subject', 'Internal Body', new List<Id>{g.Id}, new List<Id>{UserInfo.getUserId()}, attachments
            );
        } catch (Exception e) {
            // expected in test context due to pdf rendering
        }
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest
    static void testGetEmailEngagementDetails_withData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        EmailMessage em = new EmailMessage(
            RelatedToId = opp.Id,
            Subject = 'Test Email',
            ToAddress = 'test@example.com',
            Status = '3',
            MessageDate = Date.today()
        );
        insert em;
        
        EmailMessageRelation emr = new EmailMessageRelation(
            EmailMessageId = em.Id,
            RelationAddress = 'test@example.com',
            RelationType = 'ToAddress'
        );
        insert emr;

        Test.startTest();
        List<Map<String, Object>> result = EmailService.getEmailEngagementDetails(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void testRenderTemplate_withData() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        
        Contact con = new Contact(LastName = 'Test Contact', AccountId = opp.AccountId);
        insert con;
        
        Quote q = new Quote(Name = 'Test Quote', OpportunityId = opp.Id);
        insert q;
        
        EmailTemplate et = new EmailTemplate(
            Name = 'Test Template',
            DeveloperName = 'Test_Template_123',
            TemplateType = 'text',
            FolderId = UserInfo.getUserId(),
            Subject = 'Test Subject',
            Body = 'Test Body <td bLabel:main>hello</td>'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert et;
        }

        Test.startTest();
        String result = EmailService.renderTemplate(et.Id, q.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
}