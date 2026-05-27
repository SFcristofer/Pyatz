@isTest
private class LevantamientoServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Lev Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Lev Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Quote q = new Quote(
            Name = 'Lev Quote', OpportunityId = opp.Id, Pricebook2Id = pb.Id, Status = 'Draft'
        );
        insert q;
    }

    @isTest
    static void testSaveSurveyData_newRecords() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        Map<String, Object> row = new Map<String, Object>{
            'nivel' => 'Planta Baja',
            'area' => 'Cocina',
            'zona' => 'Masculino',
            'obs' => 'Test obs'
        };
        rows.add(row);
        String json = JSON.serialize(rows);
        Test.startTest();
        LevantamientoService.saveSurveyData(opp.Id, 'BIOENZIMÁTICO', json, null);
        Test.stopTest();
        List<Levantamiento_Tecnico__c> levs = [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :opp.Id];
        System.assertEquals(1, levs.size());
    }

    @isTest
    static void testSaveSurveyData_null() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        LevantamientoService.saveSurveyData(opp.Id, 'TEST', null, null);
        Test.stopTest();
        List<Levantamiento_Tecnico__c> levs = [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :opp.Id];
        System.assertEquals(0, levs.size());
    }

    @isTest
    static void testSaveSurveyData_updateExisting() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Levantamiento_Tecnico__c existing = new Levantamiento_Tecnico__c(
            Oportunidad__c = opp.Id, Tipo_Servicio__c = 'VACTOR'
        );
        insert existing;
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{'id' => existing.Id, 'nivel' => 'PB'}
        };
        Test.startTest();
        LevantamientoService.saveSurveyData(opp.Id, 'VACTOR', JSON.serialize(rows), null);
        Test.stopTest();
        List<Levantamiento_Tecnico__c> result = [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :opp.Id AND Tipo_Servicio__c = 'VACTOR'];
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testSaveSurveyData_deleteOrphans() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Levantamiento_Tecnico__c orphan = new Levantamiento_Tecnico__c(
            Oportunidad__c = opp.Id, Tipo_Servicio__c = 'LIMPIEZA'
        );
        insert orphan;
        // Save empty → orphan should be deleted
        Test.startTest();
        LevantamientoService.saveSurveyData(opp.Id, 'LIMPIEZA', '[]', null);
        Test.stopTest();
        List<Levantamiento_Tecnico__c> remaining = [SELECT Id FROM Levantamiento_Tecnico__c WHERE Id = :orphan.Id];
        System.assertEquals(0, remaining.size());
    }

    @isTest
    static void testGetLevantamientoDetails_fromOpp() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        insert new Levantamiento_Tecnico__c(Oportunidad__c = opp.Id, Tipo_Servicio__c = 'TEST');
        Test.startTest();
        List<Levantamiento_Tecnico__c> result = LevantamientoService.getLevantamientoDetails(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetLevantamientoDetails_fromQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        insert new Levantamiento_Tecnico__c(Oportunidad__c = opp.Id, Tipo_Servicio__c = 'TEST_Q');
        Test.startTest();
        List<Levantamiento_Tecnico__c> result = LevantamientoService.getLevantamientoDetails(q.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }
}
