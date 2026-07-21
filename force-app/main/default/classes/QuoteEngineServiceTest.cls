@isTest
private class QuoteEngineServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'QES Account');
        insert acc;
        Id pbId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(Id = pbId, IsActive = true);
        try { update stdPb; } catch (Exception e) {}
        Opportunity opp = new Opportunity(
            Name = 'QES Opp', AccountId = acc.Id, Pricebook2Id = pbId,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Product2 prod = new Product2(Name = 'QES Product', IsActive = true, Family = 'BIOENZIMÁTICO');
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId, Product2Id = prod.Id, UnitPrice = 500, IsActive = true
        );
        insert pbe;
    }

    @isTest
    static void testSaveTechnicalData_createNewQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{
            'opportunityId' => opp.Id,
            'name' => 'Test Quote QES',
            'status' => 'Draft',
            'lineItems' => null,
            'markersData' => null,
            'businessLines' => 'BIOENZIMÁTICO'
        };
        Test.startTest();
        Id quoteId = QuoteEngineService.saveTechnicalData(data);
        Test.stopTest();
        System.assertNotEquals(null, quoteId);
        Quote q = [SELECT Name FROM Quote WHERE Id = :quoteId];
        System.assertEquals('Test Quote QES', q.Name);
    }

    @isTest
    static void testSaveTechnicalData_updateExistingQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id pbId = Test.getStandardPricebookId();
        Quote existing = new Quote(Name = 'Existing', OpportunityId = opp.Id, Pricebook2Id = pbId, Status = 'Draft');
        insert existing;

        Map<String, Object> data = new Map<String, Object>{
            'quoteId' => existing.Id,
            'name' => 'Updated QES Quote',
            'status' => 'Pendiente',
            'lineItems' => null,
            'markersData' => null
        };
        Test.startTest();
        Id quoteId = QuoteEngineService.saveTechnicalData(data);
        Test.stopTest();
        Quote updated = [SELECT Name FROM Quote WHERE Id = :quoteId];
        System.assertEquals('Updated QES Quote', updated.Name);
    }

    @isTest
    static void testSaveTechnicalData_withLineItems() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id pbId = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        List<Map<String, Object>> items = new List<Map<String, Object>>{
            new Map<String, Object>{
                'pbeId' => pbe.Id, 'cantidad' => 1,
                'totalSinImpuestos' => 500,
                'detalleTecnico' => 'Detail', 'areas' => 'Zona A'
            }
        };
        Map<String, Object> data = new Map<String, Object>{
            'opportunityId' => opp.Id,
            'name' => 'Quote with Items',
            'status' => 'Draft',
            'lineItems' => JSON.serialize(items),
            'markersData' => null
        };
        Test.startTest();
        Id quoteId = QuoteEngineService.saveTechnicalData(data);
        Test.stopTest();
        List<QuoteLineItem> qlis = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId];
        System.assertEquals(1, qlis.size());
    }

    @isTest
    static void testSearchProducts_withBusinessLines() {
        Test.startTest();
        List<Map<String, Object>> result = QuoteEngineService.searchProducts('QES', null, new List<String>{'BIOENZIMÁTICO'}, false);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testSearchProducts_allowOtherLines() {
        Test.startTest();
        List<Map<String, Object>> result = QuoteEngineService.searchProducts('QES', null, null, true);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testSearchProducts_noResults() {
        Test.startTest();
        List<Map<String, Object>> result = QuoteEngineService.searchProducts('XXXXXXZZZZ', null, null, true);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testSaveTechnicalData_withMarkersData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> state = new Map<String, Object>{
            'serviciosData' => new List<Object>{
                new Map<String, Object>{
                    'descripcion' => 'Bioenz', 'areas' => 'Zona Test',
                    'detalleTecnico' => 'Det', 'pbeId' => null, 'levantamientoId' => null
                }
            }
        };
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state)));
        Map<String, Object> data = new Map<String, Object>{
            'opportunityId' => opp.Id,
            'name' => 'Quote Markers',
            'status' => 'Draft',
            'lineItems' => null,
            'markersData' => b64,
            'businessLines' => 'BIOENZIMÁTICO',
            'estrategiaVenta' => 'E1'
        };
        Test.startTest();
        Id quoteId = QuoteEngineService.saveTechnicalData(data);
        Test.stopTest();
        System.assertNotEquals(null, quoteId);
    }
}