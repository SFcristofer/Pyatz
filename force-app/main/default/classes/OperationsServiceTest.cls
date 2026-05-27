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
        Task t = new Task(Subject = 'Test Task', WhatId = opp.Id, Status = 'Open');
        insert t;
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
        Test.startTest();
        List<Map<String, Object>> result = OperationsService.getTacticalHistory(opp.Id);
        Test.stopTest();
        System.assert(result.size() >= 2);
    }

    @isTest
    static void testUpdateTaskActivity() {
        Task t = [SELECT Id FROM Task LIMIT 1];
        Test.startTest();
        OperationsService.updateTaskActivity(t.Id, 'Completed', 'Observation text');
        Test.stopTest();
        Task updated = [SELECT Status, Description FROM Task WHERE Id = :t.Id];
        System.assertEquals('Completed', updated.Status);
        System.assert(updated.Description.contains('Observation text'));
    }

    @isTest
    static void testUpdateTaskActivity_noObs() {
        Task t = [SELECT Id FROM Task LIMIT 1];
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
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id];
        System.assert(links.size() >= 1);
    }
}
