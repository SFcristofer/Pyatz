@isTest
private class TechWorkOrderControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(
            Name = 'TWO Account', BillingStreet = '123 Main St',
            BillingCity = 'CDMX', BillingState = 'CDMX',
            BillingPostalCode = '06600', BillingCountry = 'Mexico'
        );
        insert acc;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'TWO Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Quote q = new Quote(
            Name = 'TWO Quote', OpportunityId = opp.Id, Pricebook2Id = pb.Id,
            Status = 'Draft', AccountId = acc.Id
        );
        insert q;
        Product2 prod = new Product2(Name = 'TWO Product', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id, Product2Id = prod.Id, UnitPrice = 100, IsActive = true
        );
        insert pbe;
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100
        );
        insert qli;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New', Subject = 'Legacy WO');
        insert wo;
    }

    @isTest
    static void testGetInitialWorkOrderData_withQuoteId() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Map<String, Object> result = TechWorkOrderController.getInitialWorkOrderData(null, q.Id, null);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(q.Id, result.get('quoteId'));
        System.assertNotEquals(null, result.get('tratamientos'));
        System.assertNotEquals(null, result.get('cliente'));
    }

    @isTest
    static void testGetInitialWorkOrderData_noSyncingQuote() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        try {
            TechWorkOrderController.getInitialWorkOrderData(opp.Id, null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetServiceResources_empty() {
        Test.startTest();
        List<Map<String, String>> result = TechWorkOrderController.getServiceResources();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetServiceTerritories_empty() {
        Test.startTest();
        List<Map<String, String>> result = TechWorkOrderController.getServiceTerritories();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetAccountZonesData_noFilters() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Zona_Servicio_Pyatz__c> result = TechWorkOrderController.getAccountZonesData(
            acc.Id, null, null, null, null, null
        );
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetAccountZonesData_withSearchTerm() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Zona_Servicio_Pyatz__c zona = new Zona_Servicio_Pyatz__c(
            Name = 'Cocina Central', Cuenta__c = acc.Id
        );
        insert zona;
        Test.startTest();
        List<Zona_Servicio_Pyatz__c> resultMatch = TechWorkOrderController.getAccountZonesData(
            acc.Id, 'Cocina', null, null, null, null
        );
        List<Zona_Servicio_Pyatz__c> resultNoMatch = TechWorkOrderController.getAccountZonesData(
            acc.Id, 'XYZNOTFOUND', null, null, null, null
        );
        Test.stopTest();
        System.assertEquals(1, resultMatch.size());
        System.assertEquals(0, resultNoMatch.size());
    }

    @isTest
    static void testGetRecentWorkOrders() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Map<String, String>> result = TechWorkOrderController.getRecentWorkOrders(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.size() >= 1);
    }

    @isTest
    static void testSaveWorkOrders_createNew() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];

        Map<String, Object> row = new Map<String, Object>{
            'saId' => null,
            'date' => String.valueOf(Date.today().addDays(10)),
            'startTime' => '09:00:00.000',
            'duration' => 60.0,
            'notes' => 'Test row note',
            'arrivalMargin' => 0,
            'locked' => false,
            'tecnicoId' => null
        };
        Map<String, Object> tratamiento = new Map<String, Object>{
            'id' => String.valueOf(qli.Id),
            'name' => 'Test Fumigation',
            'zonas' => 'Kitchen',
            'levantamientoId' => null,
            'schedulingRows' => new List<Object>{ row }
        };
        Map<String, Object> payload = new Map<String, Object>{
            'quoteId' => String.valueOf(q.Id),
            'existingWorkOrderId' => null,
            'serviceContractId' => null,
            'accountId' => String.valueOf(acc.Id),
            'territoryId' => null,
            'notes' => 'Integration test notes',
            'folio' => 'Q-TEST-001',
            'priority' => 'Medium',
            'executionAddress' => null,
            'contactPerson' => 'Test Contact Person',
            'sedesList' => new List<Object>{
                new Map<String, Object>{
                    'tratamientos' => new List<Object>{ tratamiento }
                }
            }
        };

        Test.startTest();
        String woId = TechWorkOrderController.saveWorkOrders(JSON.serialize(payload));
        Test.stopTest();

        System.assertNotEquals(null, woId);
        WorkOrder created = [SELECT Id, Status, Subject, Priority FROM WorkOrder WHERE Id = :woId LIMIT 1];
        System.assertEquals('New', created.Status);
        System.assert(created.Subject.contains('Q-TEST-001'));
        System.assertEquals('Medium', created.Priority);

        List<ServiceAppointment> sas = [SELECT Id, Status FROM ServiceAppointment WHERE ParentRecordId = :woId];
        System.assertEquals(1, sas.size());
        System.assertEquals('Programado', sas[0].Status);
    }

    @isTest
    static void testSaveWorkOrders_withHighPriority() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];

        Map<String, Object> row = new Map<String, Object>{
            'saId' => null,
            'date' => String.valueOf(Date.today().addDays(5)),
            'startTime' => '10:30:00.000',
            'duration' => 90.0,
            'notes' => '',
            'arrivalMargin' => 0,
            'locked' => false,
            'tecnicoId' => null
        };
        Map<String, Object> payload = new Map<String, Object>{
            'quoteId' => String.valueOf(q.Id),
            'existingWorkOrderId' => null,
            'serviceContractId' => null,
            'accountId' => String.valueOf(acc.Id),
            'territoryId' => null,
            'notes' => '',
            'folio' => 'Q-HIGH-001',
            'priority' => 'High',
            'executionAddress' => 'Calle Alternativa 456',
            'contactPerson' => 'Gerente',
            'sedesList' => new List<Object>{
                new Map<String, Object>{
                    'tratamientos' => new List<Object>{
                        new Map<String, Object>{
                            'id' => String.valueOf(qli.Id),
                            'name' => 'Limpieza',
                            'zonas' => 'Almacen',
                            'levantamientoId' => null,
                            'schedulingRows' => new List<Object>{ row }
                        }
                    }
                }
            }
        };

        Test.startTest();
        String woId = TechWorkOrderController.saveWorkOrders(JSON.serialize(payload));
        Test.stopTest();

        System.assertNotEquals(null, woId);
        WorkOrder created = [SELECT Priority, Street FROM WorkOrder WHERE Id = :woId LIMIT 1];
        System.assertEquals('High', created.Priority);
        System.assertEquals('Calle Alternativa 456', created.Street);
    }

    @isTest
    static void testGetWorkOrderTemplateData() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Test.startTest();
        Map<String, Object> result = TechWorkOrderController.getWorkOrderTemplateData(wo.Id);
        Test.stopTest();
        System.assertEquals(null, result);
    }
}
