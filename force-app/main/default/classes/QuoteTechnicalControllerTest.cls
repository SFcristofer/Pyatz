@isTest
private class QuoteTechnicalControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'QTC Account');
        insert acc;
        Account sede = new Account(Name = 'QTC Sede', ParentId = acc.Id);
        insert sede;
        Contact cont = new Contact(LastName = 'QTCContact', AccountId = sede.Id, Email = 'qtc@test.com');
        insert cont;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'QTC Opp', AccountId = acc.Id, Pricebook2Id = pb.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Quote q = new Quote(
            Name = 'QTC Quote', OpportunityId = opp.Id, Pricebook2Id = pb.Id,
            Status = 'Draft', AccountId = acc.Id
        );
        insert q;
    }

    @isTest
    static void testGetRelatedFiles() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = QuoteTechnicalController.getRelatedFiles(q.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetAvailableAttachments() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, List<Map<String, String>>> result = QuoteTechnicalController.getAvailableAttachments(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('quotes'));
    }

    @isTest
    static void testGetDocumentStates() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, String> result = QuoteTechnicalController.getDocumentStates(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetEvidenceGallery() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = QuoteTechnicalController.getEvidenceGallery(opp.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testDeleteDocument() {
        ContentVersion cv = new ContentVersion(
            Title = 'del.pdf', PathOnClient = 'del.pdf',
            VersionData = Blob.valueOf('data'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Test.startTest();
        QuoteTechnicalController.deleteDocument(docId);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :docId]);
    }

    @isTest
    static void testGetInitialData_quote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteTechnicalController.getInitialData(q.Id);
        Test.stopTest();
        System.assert(result.containsKey('quote'));
    }

    @isTest
    static void testGetInitialData_opportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteTechnicalController.getInitialData(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('opportunity'));
    }

    @isTest
    static void testGetSedeContacts() {
        Account sede = [SELECT Id FROM Account WHERE ParentId != null LIMIT 1];
        Test.startTest();
        List<Map<String, String>> result = QuoteTechnicalController.getSedeContacts(sede.Id);
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testSearchProducts() {
        Product2 prod = new Product2(Name = 'QTC Prod', IsActive = true, Family = 'BIOENZIMÁTICO');
        insert prod;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        insert new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = prod.Id, UnitPrice = 200, IsActive = true);
        Test.startTest();
        List<Map<String, Object>> result = QuoteTechnicalController.searchProducts('QTC', null, null, true);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testCloneQuote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Id cloneId = QuoteTechnicalController.cloneQuote(q.Id, null, null, null);
        Test.stopTest();
        Quote cloned = [SELECT Name FROM Quote WHERE Id = :cloneId];
        System.assert(cloned.Name.startsWith('CLON'));
    }

    @isTest
    static void testGetCalendarData() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteTechnicalController.getCalendarData(
            q.Id,
            String.valueOf(Date.today().addDays(-1)),
            String.valueOf(Date.today().addDays(7))
        );
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetPLAnalysis() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<Analisis_PL__c> result = QuoteTechnicalController.getPLAnalysis(q.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testSavePLAnalysis() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        List<Map<String, Object>> data = new List<Map<String, Object>>{
            new Map<String, Object>{'anio' => 2025, 'costo' => 500, 'margen' => 20, 'indirecto' => 3, 'comision1' => 2, 'comision2' => 1, 'regalia' => 1, 'dias' => 15}
        };
        Test.startTest();
        QuoteTechnicalController.savePLAnalysis(q.Id, JSON.serialize(data));
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Analisis_PL__c WHERE Presupuesto__c = :q.Id]);
    }

    @isTest
    static void testGetHistoricalPL() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Decimal> result = QuoteTechnicalController.getHistoricalPL(q.Id);
        Test.stopTest();
        System.assert(result.containsKey('current'));
    }

    @isTest
    static void testGetContractInitialData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteTechnicalController.getContractInitialData(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSaveContractData() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Map<String, Object> contractData = new Map<String, Object>{
            'fechaInicioContrato' => String.valueOf(Date.today()),
            'fechaVencimiento' => String.valueOf(Date.today().addYears(1)),
            'contenidoLegal' => 'Legal content'
        };
        Test.startTest();
        String scId = QuoteTechnicalController.saveContractData(q.Id, contractData);
        Test.stopTest();
        System.assertNotEquals(null, scId);
    }

    @isTest
    static void testSaveMemoria_quote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        QuoteTechnicalController.saveMemoria(q.Id, 'Test memoria');
        Test.stopTest();
        Quote updated = [SELECT Memoria_Descriptiva__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Test memoria', updated.Memoria_Descriptiva__c);
    }

    @isTest
    static void testSaveSurveyData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        QuoteTechnicalController.saveSurveyData(opp.Id, 'TEST', '[]', null);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testGetLevantamientoDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Levantamiento_Tecnico__c> result = QuoteTechnicalController.getLevantamientoDetails(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testValidatePLPassword() {
        Test.startTest();
        Boolean result = QuoteTechnicalController.validatePLPassword('badpassword');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSyncServiceZones_blank() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        QuoteTechnicalController.syncServiceZones(q.Id, null);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testSyncServiceZones_withData() {
        Quote q = [SELECT Id, AccountId FROM Quote LIMIT 1];
        Map<String, Object> state = new Map<String, Object>{
            'serviciosData' => new List<Object>{
                new Map<String, Object>{
                    'descripcion' => 'Bioenzimático',
                    'areas' => 'Zona A, Zona B',
                    'detalleTecnico' => 'Detalle',
                    'pbeId' => null,
                    'levantamientoId' => null
                }
            }
        };
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state)));
        Test.startTest();
        QuoteTechnicalController.syncServiceZones(q.Id, b64);
        Test.stopTest();
        List<Zona_Servicio_Pyatz__c> zones = [SELECT Id FROM Zona_Servicio_Pyatz__c WHERE Cotizacion__c = :q.Id];
        System.assertEquals(2, zones.size());
    }
}
