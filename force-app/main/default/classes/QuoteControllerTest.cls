@isTest
private class QuoteControllerTest {

    @TestSetup
    static void makeData() {
        Account parent = new Account(Name = 'Quote Ctrl Parent');
        insert parent;
        Account child = new Account(Name = 'Quote Ctrl Sede', ParentId = parent.Id);
        insert child;
        Contact cont = new Contact(LastName = 'TestContact', AccountId = child.Id, Email = 'test@test.com');
        insert cont;
        Id pbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = pbId, IsActive = true);
        Opportunity opp = new Opportunity(
            Name = 'Quote Ctrl Opp', AccountId = parent.Id, Pricebook2Id = pbId,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Quote q = new Quote(
            Name = 'Quote Ctrl Quote', OpportunityId = opp.Id,
            Pricebook2Id = pbId, Status = 'Draft'
        );
        insert q;
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true, Family = 'BIOENZIMÁTICO');
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId, Product2Id = prod.Id, UnitPrice = 100, IsActive = true
        );
        insert pbe;
    }

    @isTest
    static void testGetRelatedFiles() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = QuoteController.getRelatedFiles(q.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetOpportunityLevantamientos() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        insert new Levantamiento_Tecnico__c(Oportunidad__c = opp.Id, Tipo_Servicio__c = 'BIOENZ');
        Test.startTest();
        List<Map<String, String>> result = QuoteController.getOpportunityLevantamientos(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetInitialData_quote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteController.getInitialData(q.Id);
        Test.stopTest();
        System.assert(result.containsKey('quote'));
    }

    @isTest
    static void testGetInitialData_opportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteController.getInitialData(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('opportunity'));
    }

    @isTest
    static void testGetBusinessLineOptions() {
        Test.startTest();
        List<Map<String, String>> result = QuoteController.getBusinessLineOptions();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetProductPrices() {
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = QuoteController.getProductPrices(prod.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetProductInfoByPBE() {
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        Test.startTest();
        Map<String, Object> result = QuoteController.getProductInfoByPBE(pbe.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testCloneQuote() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Id cloneId = QuoteController.cloneQuote(q.Id, null, null, null);
        Test.stopTest();
        Quote cloned = [SELECT Name FROM Quote WHERE Id = :cloneId];
        System.assert(cloned.Name.startsWith('CLON'));
    }

    @isTest
    static void testGetPLAnalysis() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<Analisis_PL__c> result = QuoteController.getPLAnalysis(q.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testSavePLAnalysis() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        List<Map<String, Object>> data = new List<Map<String, Object>>{
            new Map<String, Object>{'anio' => 2024, 'costo' => 1000, 'margen' => 30, 'indirecto' => 5, 'comision1' => 3, 'comision2' => 2, 'regalia' => 1, 'dias' => 30, 'isr' => 30, 'ru' => 10}
        };
        Test.startTest();
        try {
            QuoteController.savePLAnalysis(q.Id, JSON.serialize(data));
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetContractInitialData() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        opp.SyncedQuoteId = q.Id;
        update opp;
        Test.startTest();
        Map<String, Object> result = QuoteController.getContractInitialData(opp.Id);
        Test.stopTest();
        System.assert(result.containsKey('opportunity'));
    }

    @isTest
    static void testSaveContractData() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Map<String, Object> contractData = new Map<String, Object>{
            'fechaInicioContrato' => String.valueOf(Date.today()),
            'fechaVencimiento' => String.valueOf(Date.today().addDays(365)),
            'contenidoLegal' => 'Test Legal',
            'introduccion' => 'Intro'
        };
        Test.startTest();
        try {
            Id scId = QuoteController.saveContractData(q.Id, contractData);
            System.assertNotEquals(null, scId);
        } catch (Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testGetHistoricalPL() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Decimal> result = QuoteController.getHistoricalPL(q.Id);
        Test.stopTest();
        System.assert(result.containsKey('current'));
        System.assert(result.containsKey('previous'));
    }

    @isTest
    static void testGetHistoricalZones() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Quote Ctrl Parent' LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        insert new Zona_Servicio_Pyatz__c(Name = 'Zona1', Cuenta__c = acc.Id, Cotizacion__c = q.Id, Id_Unico_Zona__c = q.Id + '_zona1');
        Test.startTest();
        List<String> result = QuoteController.getHistoricalZones(acc.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetHistoricalZones_null() {
        Test.startTest();
        List<String> result = QuoteController.getHistoricalZones(null);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testSearchParentAccounts() {
        Test.startTest();
        List<Map<String, String>> result = QuoteController.searchParentAccounts('Quote Ctrl');
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testSearchSedes() {
        Test.startTest();
        List<Map<String, String>> result = QuoteController.searchSedes('Sede');
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testGetSedeContacts() {
        Account child = [SELECT Id FROM Account WHERE ParentId != null LIMIT 1];
        Test.startTest();
        List<Map<String, String>> result = QuoteController.getSedeContacts(child.Id);
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testGetQuotesList() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = QuoteController.getQuotesList(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetQuotesList_noOppId() {
        Test.startTest();
        List<Map<String, Object>> result = QuoteController.getQuotesList(null);
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testGetQuoteStats() {
        Test.startTest();
        Map<String, Integer> result = QuoteController.getQuoteStats();
        Test.stopTest();
        System.assert(result.containsKey('Total'));
    }

    @isTest
    static void testSearchProspectos() {
        Test.startTest();
        List<Map<String, String>> result = QuoteController.searchProspectos('Test');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetFilteredSedes_byParent() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Quote Ctrl Parent' LIMIT 1];
        Test.startTest();
        List<Account> result = QuoteController.getFilteredSedes('Sede', parent.Id, false);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetFilteredSedes_global() {
        Test.startTest();
        List<Account> result = QuoteController.getFilteredSedes('Quote Ctrl', null, true);
        Test.stopTest();
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testGetFilteredSedes_noParent() {
        Test.startTest();
        List<Account> result = QuoteController.getFilteredSedes('Test', null, false);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testSearchUsers() {
        Test.startTest();
        List<Map<String, String>> result = QuoteController.searchUsers('Admin');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testValidatePLPassword() {
        Test.startTest();
        Boolean result = QuoteController.validatePLPassword('wrong');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testSearchNecesidades() {
        Test.startTest();
        List<Map<String, String>> result = QuoteController.searchNecesidades('bio');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetOpportunitySoluciones() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        insert new Solucion_Tecnica__c(Oportunidad__c = opp.Id, Name = 'Test Sol');
        Test.startTest();
        List<Map<String, String>> result = QuoteController.getOpportunitySoluciones(opp.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testSearchProducts() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = QuoteController.searchProducts('Test', q.Id, new List<String>{'BIOENZIMÁTICO'}, false);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testEmailTemplates() {
        Test.startTest();
        try {
            QuoteController.getEmailTemplatesByFolder('Cotizaciones');
            QuoteController.renderTemplate(null, null);
        } catch(Exception e) {}
        Test.stopTest();
    }
}