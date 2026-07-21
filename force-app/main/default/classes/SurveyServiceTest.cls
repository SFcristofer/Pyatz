@isTest
private class SurveyServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Survey Svc Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Survey Svc Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(
            Oportunidad__c = opp.Id, Tipo_Servicio__c = 'TEST'
        );
        insert lev;
    }

    @isTest
    static void testGetOpportunitySolutions_empty() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = SurveyService.getOpportunitySolutions(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetOpportunitySolutions_withData() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        insert new Solucion_Tecnica__c(
            Levantamiento_Tecnico__c = lev.Id,
            Name = 'Sol Test',
            Descripcion_Detallada__c = 'desc'
        );
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = SurveyService.getOpportunitySolutions(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testSaveSolucion_insert() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        Test.startTest();
        Id solId = SurveyService.saveSolucion(lev.Id, null, 'New Solution', 'Tech desc', 'Obs');
        Test.stopTest();
        Solucion_Tecnica__c sol = [SELECT Name FROM Solucion_Tecnica__c WHERE Id = :solId];
        System.assertEquals('New Solution', sol.Name);
    }

    @isTest
    static void testSaveSolucion_update() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        Id firstId = SurveyService.saveSolucion(lev.Id, null, 'Original', 'desc1', 'obs1');
        Test.startTest();
        SurveyService.saveSolucion(lev.Id, firstId, 'Updated', 'desc2', 'obs2');
        Test.stopTest();
        Solucion_Tecnica__c sol = [SELECT Name FROM Solucion_Tecnica__c WHERE Id = :firstId];
        System.assertEquals('Updated', sol.Name);
    }

    @isTest
    static void testDeleteSolucion() {
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        Id solId = SurveyService.saveSolucion(lev.Id, null, 'ToDelete', 'desc', 'obs');
        Test.startTest();
        SurveyService.deleteSolucion(solId);
        Test.stopTest();
        List<Solucion_Tecnica__c> remaining = [SELECT Id FROM Solucion_Tecnica__c WHERE Id = :solId];
        System.assertEquals(0, remaining.size());
    }

    @isTest
    static void testGetInspectionQuestions() {
        Test.startTest();
        List<Map<String, Object>> result = SurveyService.getInspectionQuestions('BIOENZIMÁTICO');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSaveInspectionResult() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = opp.Id, Status = 'None', Subject = 'SA Test');
        insert sa;
        
        Inspeccion_Tecnica__c it = new Inspeccion_Tecnica__c(Cita_Servicio__c = sa.Id, Tipo_Reporte__c = 'TEST');
        insert it;
        
        Test.startTest();
        SurveyService.saveInspectionResult(sa.Id, '{"key":"val"}', 'No deficiencies');
        Test.stopTest();
        
        Inspeccion_Tecnica__c updated = [SELECT Respuestas_JSON__c, Deficiencias_Detectadas__c FROM Inspeccion_Tecnica__c WHERE Id = :it.Id];
        System.assertEquals('{"key":"val"}', updated.Respuestas_JSON__c);
        System.assertEquals('No deficiencies', updated.Deficiencias_Detectadas__c);
    }
    
    @isTest
    static void testSaveInspectionResult_error() {
        Boolean err = false;
        Test.startTest();
        try {
            SurveyService.saveInspectionResult(null, '{"key":"val"}', 'No deficiencies');
        } catch (Exception e) {
            err = true;
        }
        Test.stopTest();
        System.assert(err);
    }

    @isTest
    static void testGetInspectionData_null() {
        Map<String, Object> res = SurveyService.getInspectionData(null);
        System.assertEquals(0, res.size());
    }

    @isTest
    static void testGetInspectionData_withData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = opp.Id, Status = 'None', Subject = 'SA Test');
        insert sa;
        
        Levantamiento_Tecnico__c lev = [SELECT Id FROM Levantamiento_Tecnico__c LIMIT 1];
        
        Inspeccion_Tecnica__c it = new Inspeccion_Tecnica__c(Cita_Servicio__c = sa.Id, Levantamiento_Tecnico__c = lev.Id, Respuestas_JSON__c = '{"key":"val"}');
        insert it;
        
        Test.startTest();
        Map<String, Object> result = SurveyService.getInspectionData(sa.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals('{"key":"val"}', result.get('existingData'));
        System.assertEquals('TEST', result.get('reportType'));
    }

    @isTest
    static void testTagLatestPhotos() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        ContentVersion cv = new ContentVersion(
            Title = 'photo.jpg', PathOnClient = 'photo.jpg',
            VersionData = Blob.valueOf('img'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = acc.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        Test.startTest();
        SurveyService.tagLatestPhotos(acc.Id, 'FOTO');
        Test.stopTest();
        ContentVersion updated = [SELECT Title FROM ContentVersion WHERE Id = :cv.Id];
        System.assert(updated.Title.contains('[FOTO]'));
    }
}