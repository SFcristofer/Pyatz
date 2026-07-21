@isTest
private class TechWorkOrderControllerTest {

    @TestSetup
    static void makeData() {
        // Data for tests
        Account acc = new Account(Name = 'Pyatz Account', BillingStreet = 'Calle 1', BillingCity = 'CDMX');
        insert acc;
        
        Opportunity opp = new Opportunity(Name = 'Opp Pyatz', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acc.Id);
        insert opp;
        
        Id standardPbId = Test.getStandardPricebookId();
        
        Product2 prod = new Product2(Name = 'Fumigacion Pyatz', IsActive = true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prod.Id, UnitPrice = 100, IsActive = true);
        insert pbe;
        
        Quote q = new Quote(Name = 'Test Quote Pyatz', OpportunityId = opp.Id, Pricebook2Id = standardPbId);
        insert q;
        
        QuoteLineItem qli = new QuoteLineItem(QuoteId = q.Id, Product2Id = prod.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100);
        insert qli;
        
        ServiceTerritory st = new ServiceTerritory(Name = 'Territorio Central', IsActive = true, OperatingHoursId = createOperatingHours().Id);
        insert st;
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' OR Name='Usuario Estándar' LIMIT 1];
        User u = new User(Alias = 'standt', Email='standarduser@pyatz.test', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='tecpyatz' + Datetime.now().getTime() + '@pyatz.test');
        insert u;
        
        ServiceResource sr = new ServiceResource(Name = 'Tecnico Pyatz', ResourceType = 'T', IsActive = true, RelatedRecordId = u.Id);
        insert sr;
        
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, ServiceTerritoryId = st.Id, Subject = 'Test WO Pyatz');
        insert wo;
        
        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = wo.Id, EarliestStartTime = Datetime.now(), DueDate = Datetime.now().addDays(1), Status = 'Ninguno');
        insert sa;
        
        Form_Template__c ft = new Form_Template__c(Name = 'Plantilla Test', Tipo_Reporte__c = 'Mantenimiento');
        insert ft;
        
        Zona_Servicio_Pyatz__c z = new Zona_Servicio_Pyatz__c(Name = 'Zona Pyatz', Cuenta__c = acc.Id);
        insert z;
        
        Plantilla_de_Zona__c pz = new Plantilla_de_Zona__c(Zona__c = z.Id, Plantilla__c = ft.Id);
        insert pz;
    }
    
    static OperatingHours createOperatingHours() {
        OperatingHours oh = new OperatingHours(Name = 'Horario Pyatz', TimeZone = 'America/Mexico_City');
        insert oh;
        return oh;
    }

    @isTest
    static void testGetCatalogues() {
        Test.startTest();
        List<Map<String, String>> resources = TechWorkOrderController.getServiceResources();
        System.assert(resources.size() > 0, 'Debe retornar recursos');
        
        List<Map<String, String>> territories = TechWorkOrderController.getServiceTerritories();
        System.assert(territories.size() > 0, 'Debe retornar territorios');
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Zona_Servicio_Pyatz__c> zonas = TechWorkOrderController.getAccountZonesData(acc.Id, 'Pyatz', '', '', '', '');
        System.assert(zonas.size() > 0, 'Debe retornar zonas filtradas');
        
        List<Map<String, String>> wos = TechWorkOrderController.getRecentWorkOrders(acc.Id);
        System.assert(wos.size() > 0, 'Debe retornar ODTs recientes');
        
        Map<String, Object> tData = TechWorkOrderController.getWorkOrderTemplateData(null);
        System.assertEquals(null, tData);
        Test.stopTest();
    }
    
    @isTest
    static void testGetInitialWorkOrderData() {
        Quote q = [SELECT Id, OpportunityId FROM Quote LIMIT 1];
        
        Test.startTest();
        Map<String, Object> data = TechWorkOrderController.getInitialWorkOrderData(q.OpportunityId, q.Id, null);
        Test.stopTest();
        
        System.assertNotEquals(null, data);
        System.assertEquals(q.Id, data.get('quoteId'));
        System.assert(data.containsKey('tratamientos'));
    }

    @isTest
    static void testSaveWorkOrders() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        QuoteLineItem qli = [SELECT Id, Product2Id FROM QuoteLineItem LIMIT 1];
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory LIMIT 1];
        ServiceResource sr = [SELECT Id FROM ServiceResource LIMIT 1];
        
        Map<String, Object> payload = new Map<String, Object>{
            'existingWorkOrderId' => '',
            'quoteId' => q.Id,
            'serviceContractId' => '',
            'accountId' => acc.Id,
            'territoryId' => st.Id,
            'notes' => 'Notas de prueba Pyatz',
            'folio' => 'Q-9999',
            'priority' => 'High',
            'executionAddress' => 'Calle Falsa 123',
            'contactPerson' => 'Homero',
            'sedesList' => new List<Object>{
                new Map<String, Object>{
                    'tratamientos' => new List<Object>{
                        new Map<String, Object>{
                            'id' => qli.Id,
                            'name' => 'Fumigacion Pyatz',
                            'quantity' => 1,
                            'zonas' => 'Zona Pyatz',
                            'schedulingRows' => new List<Object>{
                                new Map<String, Object>{
                                    'saId' => '',
                                    'date' => String.valueOf(Date.today()),
                                    'startTime' => '08:00:00.000',
                                    'duration' => 60,
                                    'status' => 'Ninguno',
                                    'notes' => 'Nota SA',
                                    'travelTime' => 30,
                                    'locked' => false,
                                    'tecnicoId' => sr.Id,
                                    'tecnicosIds' => new List<Object>{ sr.Id }
                                }
                            }
                        }
                    }
                }
            }
        };
        
        String jsonPayload = JSON.serialize(payload);
        
        Test.startTest();
        String resultId = TechWorkOrderController.saveWorkOrders(jsonPayload);
        Test.stopTest();
        
        System.assertNotEquals(null, resultId, 'Debe devolver el ID de la WorkOrder');
        WorkOrder insertedWO = [SELECT Id, Subject FROM WorkOrder WHERE Id = :resultId];
        System.assert(insertedWO.Subject.contains('Q-9999'));
        
        List<ServiceAppointment> sas = [SELECT Id, Status FROM ServiceAppointment WHERE ParentRecordId = :resultId];
        System.assert(sas.size() > 0, 'Debe crear ServiceAppointments');
        
        List<Revision_Cita_Servicio__c> revs = [SELECT Id, Status__c FROM Revision_Cita_Servicio__c WHERE Cita_Servicio__c IN :sas];
        System.assert(revs.size() > 0, 'Debe crear Revisiones');
    }
}
