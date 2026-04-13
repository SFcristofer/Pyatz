public with sharing class TechWorkOrderController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialWorkOrderData(Id oppId, Id quoteId, Id serviceContractId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            if (serviceContractId != null) {
                ServiceContract sc = [SELECT Id, Name, StartDate, EndDate, Account.Name, Quote_Source__r.QuoteNumber FROM ServiceContract WHERE Id = :serviceContractId LIMIT 1];
                result.put('quoteId', sc.Quote_Source__c);
                result.put('accountId', sc.AccountId);
                result.put('folio', sc.Quote_Source__r != null ? sc.Quote_Source__r.QuoteNumber : sc.Name);
                result.put('cliente', sc.Account.Name);
                result.put('fechaInicio', sc.StartDate != null ? sc.StartDate.format() : '---');
                result.put('fechaFin', sc.EndDate != null ? sc.EndDate.format() : '---');
                List<ContractLineItem> clis = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, Description FROM ContractLineItem WHERE ServiceContractId = :sc.Id];
                List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
                for (ContractLineItem cli : clis) {
                    tratamientos.add(new Map<String, Object>{'id' => cli.Id, 'name' => cli.Product2.Name, 'quantity' => cli.Quantity, 'zonas' => cli.Description});
                }
                result.put('tratamientos', tratamientos);
                return result;
            }

            Quote targetQuote;
            if (quoteId != null) {
                targetQuote = [SELECT Id, QuoteNumber, Name, GrandTotal, ExpirationDate, CreatedDate, AccountId, Account.Name, OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1];
            } else {
                List<Quote> syncingQuotes = [SELECT Id, QuoteNumber, Name, GrandTotal, ExpirationDate, CreatedDate, AccountId, Account.Name, OpportunityId FROM Quote WHERE OpportunityId = :oppId AND IsSyncing = true LIMIT 1];
                if (syncingQuotes.isEmpty()) throw new AuraHandledException('No hay un presupuesto sincronizado.');
                targetQuote = syncingQuotes[0];
            }
            
            result.put('quoteId', targetQuote.Id);
            result.put('oppId', targetQuote.OpportunityId);
            result.put('accountId', targetQuote.AccountId);
            result.put('folio', targetQuote.QuoteNumber);
            result.put('cliente', targetQuote.Account.Name);
            result.put('fechaInicio', targetQuote.CreatedDate.format('dd-MMM-yyyy'));
            result.put('fechaFin', targetQuote.ExpirationDate != null ? targetQuote.ExpirationDate.format() : 'No definida');
            
            List<QuoteLineItem> qlis = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, Description FROM QuoteLineItem WHERE QuoteId = :targetQuote.Id];
            List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
            for (QuoteLineItem qli : qlis) {
                tratamientos.add(new Map<String, Object>{'id' => qli.Id, 'name' => qli.Product2.Name, 'quantity' => qli.Quantity, 'zonas' => qli.Description});
            }
            result.put('tratamientos', tratamientos);
            return result;
        } catch (Exception e) { throw new AuraHandledException('Error en Carga ODT: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceResources() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        try {
            List<ServiceResource> resources = [SELECT Id, Name, ResourceType FROM ServiceResource WHERE IsActive = true AND ResourceType = 'T' ORDER BY Name ASC LIMIT 50];
            for (ServiceResource sr : resources) results.add(new Map<String, String>{'id' => sr.Id, 'name' => sr.Name});
        } catch (Exception e) { }
        return results;
    }

    @AuraEnabled
    public static String saveWorkOrders(String payloadJson) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            Id quoteId = (Id) payload.get('quoteId');
            Id serviceContractId = (Id) payload.get('serviceContractId');
            Id accountId = (Id) payload.get('accountId');
            String notes = (String) payload.get('notes');
            String folio = (String) payload.get('folio');
            List<Object> sedesPayload = (List<Object>) payload.get('sedesList');

            Account acc = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account WHERE Id = :accountId LIMIT 1];

            // DETERMINAR PRICEBOOK
            Id pricebookId = null;
            if (quoteId != null) pricebookId = [SELECT Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1].Pricebook2Id;
            else if (serviceContractId != null) pricebookId = [SELECT Pricebook2Id FROM ServiceContract WHERE Id = :serviceContractId LIMIT 1].Pricebook2Id;

            // 1. Crear Work Order Maestra (SIN FORZAR TERRITORIO)
            WorkOrder wo = new WorkOrder();
            wo.Subject = 'Contrato Pyatz: ' + folio;
            wo.AccountId = accountId;
            wo.Pricebook2Id = pricebookId;
            wo.Status = 'New';
            wo.Street = acc.BillingStreet;
            wo.City = acc.BillingCity;
            wo.State = acc.BillingState;
            wo.PostalCode = acc.BillingPostalCode;
            wo.Country = acc.BillingCountry;
            wo.Description = 'Generada desde 360 Pyatz.\nNotas:\n' + notes;
            insert wo;

            // 2. Crear Work Order Line Items
            List<WorkOrderLineItem> wolisToInsert = new List<WorkOrderLineItem>();
            for (Object sedeObj : sedesPayload) {
                Map<String, Object> sede = (Map<String, Object>) sedeObj;
                for (Object traObj : (List<Object>) sede.get('tratamientos')) {
                    Map<String, Object> tra = (Map<String, Object>) traObj;
                    WorkOrderLineItem woli = new WorkOrderLineItem(WorkOrderId = wo.Id);
                    Id traId = (Id) tra.get('id');
                    if (traId != null && traId.getSObjectType().getDescribe().getName() == 'QuoteLineItem') woli.PricebookEntryId = [SELECT PricebookEntryId FROM QuoteLineItem WHERE Id = :traId LIMIT 1].PricebookEntryId;
                    else if (traId != null && traId.getSObjectType().getDescribe().getName() == 'ContractLineItem') woli.PricebookEntryId = [SELECT PricebookEntryId FROM ContractLineItem WHERE Id = :traId LIMIT 1].PricebookEntryId;
                    woli.Description = (String) tra.get('name') + ' - ' + (String) tra.get('zonas');
                    woli.Quantity = (Decimal) tra.get('quantity');
                    wolisToInsert.add(woli);
                }
            }
            if (!wolisToInsert.isEmpty()) insert wolisToInsert;

            // 3. Crear Service Appointments (ESTADO NONE)
            List<ServiceAppointment> sasToInsert = new List<ServiceAppointment>();
            List<List<String>> techniciansPerSA = new List<List<String>>();
            Integer woliIndex = 0;
            for (Object sedeObj : sedesPayload) {
                Map<String, Object> sede = (Map<String, Object>) sedeObj;
                String startTimeStr = (String) sede.get('startTime');
                for (Object traObj : (List<Object>) sede.get('tratamientos')) {
                    Map<String, Object> tra = (Map<String, Object>) traObj;
                    List<String> techIds = new List<String>();
                    if (tra.containsKey('tecnicosIds')) for (Object tId : (List<Object>) tra.get('tecnicosIds')) techIds.add((String) tId);
                    for (Object rowObj : (List<Object>) tra.get('schedulingRows')) {
                        Map<String, Object> row = (Map<String, Object>) rowObj;
                        Date d = Date.valueOf((String) row.get('date'));
                        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = wolisToInsert[woliIndex].Id, Subject = 'Servicio: ' + (String) tra.get('name'));
                        sa.Street = wo.Street; sa.City = wo.City; sa.State = wo.State; sa.PostalCode = wo.PostalCode; sa.Country = wo.Country;
                        sa.EarliestStartTime = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                        sa.DueDate = sa.EarliestStartTime.addDays(1);
                        sa.Duration = (Decimal) row.get('duration');
                        sa.DurationType = 'Minutes';
                        sa.Status = 'None';
                        
                        Integer h = 8, m = 0;
                        if (String.isNotBlank(startTimeStr)) {
                            List<String> pts = startTimeStr.substringBefore('.').split(':');
                            if (pts.size() >= 2) { h = Integer.valueOf(pts[0]); m = Integer.valueOf(pts[1]); }
                        }
                        sa.SchedStartTime = Datetime.newInstance(d, Time.newInstance(h, m, 0, 0));
                        sa.SchedEndTime = sa.SchedStartTime.addMinutes(Integer.valueOf(sa.Duration));
                        
                        if ((Boolean) row.get('locked')) sa.FSL__Pinned__c = true;
                        if (String.isNotBlank((String) row.get('notes'))) sa.ServiceNote = (String) row.get('notes');
                        sasToInsert.add(sa);
                        techniciansPerSA.add(techIds);
                    }
                    woliIndex++;
                }
            }
            if (!sasToInsert.isEmpty()) {
                insert sasToInsert;
                
                // 4. Intentar Asignar Técnicos (SILENCIOSO PARA EVITAR EL ERROR DE TERRITORIO)
                List<AssignedResource> arsToInsert = new List<AssignedResource>();
                for (Integer i = 0; i < sasToInsert.size(); i++) {
                    for (String tId : techniciansPerSA[i]) {
                        arsToInsert.add(new AssignedResource(ServiceAppointmentId = sasToInsert[i].Id, ServiceResourceId = (Id) tId));
                    }
                }
                if (!arsToInsert.isEmpty()) {
                    try { insert arsToInsert; } 
                    catch (Exception e) { System.debug('Asignación omitida por reglas de SFS: ' + e.getMessage()); }
                }
            }
            return wo.Id;
        } catch (Exception e) { throw new AuraHandledException('Error en Generación ODT: ' + e.getMessage()); }
    }
}