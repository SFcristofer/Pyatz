@isTest
private class OperationsServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Ops Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Ops Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        Task t1 = new Task(Subject = 'Test Task', WhatId = opp.Id, Status = 'Open', Description = 'Task desc');
        insert t1;
        Task t2 = new Task(Subject = 'Test Call', WhatId = opp.Id, Status = 'Completed', TaskSubtype = 'Call');
        insert t2;
        Task t3 = new Task(Subject = 'Test Email Task', WhatId = opp.Id, Status = 'Completed', TaskSubtype = 'Email');
        insert t3;

        Event e = new Event(Subject = 'Test Event', WhatId = opp.Id, StartDateTime = Datetime.now(), EndDateTime = Datetime.now().addHours(1), Description = 'Event desc');
        insert e;

        EmailMessage em = new EmailMessage(Subject = 'Test Email', RelatedToId = opp.Id, HtmlBody = '<b>Hello</b>', TextBody = 'Hello', FromAddress = 'test@test.com', ToAddress = 'test2@test.com', Status = '3');
        insert em;

        ContentVersion cv = new ContentVersion(Title = 'Test PDF', PathOnClient = 'test.pdf', VersionData = Blob.valueOf('Test Content'), IsMajorVersion = true);
        insert cv;
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink(ContentDocumentId = conDocId, LinkedEntityId = opp.Id, ShareType = 'V');
        insert cdl;

        ContentVersion cv2 = new ContentVersion(Title = 'Test Image', PathOnClient = 'test.png', VersionData = Blob.valueOf('Image Content'), IsMajorVersion = true);
        insert cv2;
        Id conDocId2 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv2.Id].ContentDocumentId;
        ContentDocumentLink cdl2 = new ContentDocumentLink(ContentDocumentId = conDocId2, LinkedEntityId = em.Id, ShareType = 'V');
        insert cdl2;
    }

    @isTest
    static void testGetTacticalHistory_null() {
        Test.startTest();
        List<Map<String, Object>> result = OperationsService.getTacticalHistory(null);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetTacticalHistory_withData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        insert new Levantamiento_Tecnico__c(Oportunidad__c = opp.Id, Tipo_Servicio__c = 'TEST');
        
        // Also save a note to test 'SNOTE' branch
        OperationsService.saveNote(opp.Id, 'Test Note', 'Note content');

        Test.startTest();
        List<Map<String, Object>> result = OperationsService.getTacticalHistory(opp.Id);
        Test.stopTest();
        System.assert(result.size() >= 5);
    }

    @isTest
    static void testUpdateTaskActivity() {
        Task t = [SELECT Id, Description FROM Task WHERE Subject = 'Test Task' LIMIT 1];
        Test.startTest();
        OperationsService.updateTaskActivity(t.Id, 'Completed', 'Observation text');
        Test.stopTest();
        Task updated = [SELECT Status, Description FROM Task WHERE Id = :t.Id];
        System.assertEquals('Completed', updated.Status);
        System.assert(updated.Description.contains('Observation text'));
    }

    @isTest
    static void testUpdateTaskActivity_noObs() {
        Task t = [SELECT Id FROM Task WHERE Subject = 'Test Task' LIMIT 1];
        Test.startTest();
        OperationsService.updateTaskActivity(t.Id, null, null);
        Test.stopTest();
        Task updated = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Open', updated.Status);
    }

    @isTest
    static void testSaveStageTracking() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        OperationsService.saveStageTracking(opp.Id, 'Etapa1', 'SubEtapa1', 'Completado');
        Test.stopTest();
        List<Seguimiento_Etapas_Pyatz__c> results = [SELECT Id FROM Seguimiento_Etapas_Pyatz__c WHERE Oportunidad__c = :opp.Id];
        System.assertEquals(1, results.size());
    }

    @isTest
    static void testSaveStageTracking_upsert() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        OperationsService.saveStageTracking(opp.Id, 'Etapa1', 'SubEtapa1', 'Pendiente');
        Test.startTest();
        OperationsService.saveStageTracking(opp.Id, 'Etapa1', 'SubEtapa1', 'Completado');
        Test.stopTest();
        Integer count = [SELECT COUNT() FROM Seguimiento_Etapas_Pyatz__c WHERE Oportunidad__c = :opp.Id];
        System.assertEquals(1, count);
    }

    @isTest
    static void testSaveNote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Id noteId = OperationsService.saveNote(opp.Id, 'Test Note', 'Note content here');
        Test.stopTest();
        System.assertNotEquals(null, noteId);
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id AND ContentDocument.Title = 'Test Note'];
        System.assert(links.size() >= 1);
    }

    @isTest
    static void testGetEmailDetails() {
        EmailMessage em = [SELECT Id FROM EmailMessage LIMIT 1];
        Test.startTest();
        Map<String, Object> details = OperationsService.getEmailDetails(em.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, details);
        System.assertEquals('Test Email', details.get('subject'));
        List<Map<String, Object>> attachments = (List<Map<String, Object>>)details.get('attachments');
        System.assert(attachments.size() >= 1);
    }
}