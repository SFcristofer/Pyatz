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
        Id pbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = pbId, IsActive = true);
        Quote q = new Quote(
            Name = 'Lev Quote', OpportunityId = opp.Id, Pricebook2Id = pbId, Status = 'Draft'
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
            'obs' => 'Test obs',
            'Nivel__c' => 'Test Nivel Dynamic',
            've' => 10,
            'vp' => 5.5,
            'c10l' => 1,
            'c20l' => 2,
            'c25l' => 3,
            'piso' => 4,
            'mueble' => 5,
            'pared' => 6,
            'escamoche' => 'Sí',
            'azolves' => 'No',
            'foto' => 'URL',
            'residuos' => 'Nada',
            'instala' => 'Bien',
            'coladeras' => 1,
            'tapon' => 2,
            'tarja' => 3,
            'tinas' => 4,
            'tgrasa' => 5,
            'modelo' => 'M1',
            'st1' => 1.5,
            'ovalines' => 2
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
    static void testSaveSurveyData_otherTypes() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // VACTOR
        List<Map<String, Object>> vactorRows = new List<Map<String, Object>>{
            new Map<String, Object>{'largo' => 1, 'ancho' => 2, 'prof' => 3, 'material' => 'M', 'dificultad' => 'D', 'descripcion' => 'Desc', 'medida' => 'Med', 'servicio' => 'Srv', 'distancia' => 'Dist', 'permDelegacion' => 'P1', 'permPlaza' => 'P2', 'alcance' => 'Alc', 'mtLineal' => 5}
        };
        LevantamientoService.saveSurveyData(opp.Id, 'VACTOR', JSON.serialize(vactorRows), null);

        // GRASAS
        List<Map<String, Object>> grasasRows = new List<Map<String, Object>>{
            new Map<String, Object>{'sp' => 1, 'ent' => 2, 'frecuencia' => 'F', 'estado' => 'E', 'modelo' => 'M', 'instala' => 'I', 'foto' => 'F', 'tornillo' => 1, 'sello' => 1, 'mampara' => 1, 'canastilla' => 1, 'retSalida' => 1}
        };
        LevantamientoService.saveSurveyData(opp.Id, 'GRASAS', JSON.serialize(grasasRows), null);

        // INTIMA
        List<Map<String, Object>> intimaRows = new List<Map<String, Object>>{
            new Map<String, Object>{'tornillo' => 1, 'sello' => 2, 'mampara' => 3, 'canastilla' => 4, 'retSalida' => 5, 'wc' => 6, 'instala' => 'I', 'foto' => 'F', 'frecuencia' => 'F', 'dias' => 'D'}
        };
        LevantamientoService.saveSurveyData(opp.Id, 'INTIMA', JSON.serialize(intimaRows), null);

        // DESAZOLVE MECANICO
        List<Map<String, Object>> desazolveRows = new List<Map<String, Object>>{
            new Map<String, Object>{'wc' => 1, 'mingitorios' => 2, 'mtLineal' => 3, 'tarjas' => 4, 'cuartoHumado' => 5, 'arm' => 6, 'ovalines' => 7, 'coladeras' => 8, 'tapon' => 9, 'sp' => 10, 'ent' => 11, 'instala' => 'I', 'foto' => 'F'}
        };
        LevantamientoService.saveSurveyData(opp.Id, 'DESAZOLVE MECANICO', JSON.serialize(desazolveRows), null);

        // AROMATIZANTES
        List<Map<String, Object>> aromaRows = new List<Map<String, Object>>{
            new Map<String, Object>{'wc' => 1, 'instala' => 'I', 'foto' => 'F', 'arm' => 2}
        };
        LevantamientoService.saveSurveyData(opp.Id, 'AROMATIZANTES', JSON.serialize(aromaRows), null);

        List<Levantamiento_Tecnico__c> levs = [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :opp.Id];
        System.assert(levs.size() > 0);
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