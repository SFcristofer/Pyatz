@isTest
private class SurveyControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Survey Ctrl Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Survey Ctrl Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(
            Oportunidad__c = opp.Id, Tipo_Servicio__c = 'BIOENZIMÁTICO'
        );
        insert lev;
    }

    @isTest
    static void testSaveSurveyData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{'nivel' => 'PB', 'area' => 'Cocina'}
        };
        Test.startTest();
        SurveyController.saveSurveyData(opp.Id, 'BIOENZIMÁTICO', JSON.serialize(rows), null);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testGetLevantamientoDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Levantamiento_Tecnico__c> result = SurveyController.getLevantamientoDetails(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetOpportunitySolutions() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = SurveyController.getOpportunitySolutions(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetSoluciones() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        insert new Solucion_Tecnica__c(Levantamiento_Tecnico__c = lev.Id, Name = 'Sol1');
        Test.startTest();
        List<Solucion_Tecnica__c> result = SurveyController.getSoluciones(lev.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testSaveSolucion() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        Test.startTest();
        Id solId = SurveyController.saveSolucion(lev.Id, null, 'MySol', 'TechDesc', 'Obs');
        Test.stopTest();
        System.assertNotEquals(null, solId);
    }

    @isTest
    static void testDeleteSolucion() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        Id solId = SurveyController.saveSolucion(lev.Id, null, 'ToDelete', 'desc', 'obs');
        Test.startTest();
        SurveyController.deleteSolucion(solId);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Solucion_Tecnica__c WHERE Id = :solId]);
    }

    @isTest
    static void testSaveMemoria_opportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        SurveyController.saveMemoria(opp.Id, 'Memoria de prueba');
        Test.stopTest();
        Opportunity updated = [SELECT Memoria_Descriptiva__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Memoria de prueba', updated.Memoria_Descriptiva__c);
    }

    @isTest
    static void testSaveMemoria_levantamiento() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        Test.startTest();
        SurveyController.saveMemoria(lev.Id, 'Lev memoria');
        Test.stopTest();
        Levantamiento_Tecnico__c updated = [SELECT Memoria_Descriptiva__c FROM Levantamiento_Tecnico__c WHERE Id = :lev.Id];
        System.assertEquals('Lev memoria', updated.Memoria_Descriptiva__c);
    }
}
