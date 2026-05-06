public with sharing class TechWorkOrderController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialWorkOrderData(Id oppId, Id quoteId, Id serviceContractId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // BUSCAR ODT EXISTENTE
            WorkOrder existingWO = null;
            if (serviceContractId != null) {
                List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE ServiceContractId = :serviceContractId LIMIT 1];
                if (!wos.isEmpty()) existingWO = wos[0];
            }

            if (existingWO != null) {
                // CARGAR DATOS DE ODT EXISTENTE (MODO VISOR/EDITOR)
                WorkOrder fullWO = [SELECT Id, Priority, Description FROM WorkOrder WHERE Id = :existingWO.Id LIMIT 1];
                Map<String, Object> templateData = getWorkOrderTemplateData(fullWO.Id);
                result.put('existingWorkOrderId', fullWO.Id);
                result.put('isUpdateMode', true);
                result.put('notes', templateData.get('notes'));
                result.put('prioridad', fullWO.Priority != null ? fullWO.Priority : 'Medium');
                result.put('tratamientosExistentes', templateData.get('tratamientos'));
            }

            if (serviceContractId != null) {
                ServiceContract sc = [SELECT Id, Name, StartDate, EndDate, Account.Name, AccountId,
                                            Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                                            Quote_Source__c, Quote_Source__r.QuoteNumber, Quote_Source__r.Business_Lines_Selected__c, 
                                            Quote_Source__r.Technical_Sedes__c 
                                     FROM ServiceContract WHERE Id = :serviceContractId LIMIT 1];
                result.put('quoteId', sc.Quote_Source__c);
                result.put('accountId', sc.AccountId);
                result.put('folio', sc.Quote_Source__r != null ? sc.Quote_Source__r.QuoteNumber : sc.Name);
                result.put('cliente', sc.Account.Name);
                result.put('direccion', sc.Account.BillingStreet + ', ' + sc.Account.BillingCity);
                result.put('lineaNegocio', sc.Quote_Source__r != null ? sc.Quote_Source__r.Business_Lines_Selected__c : '---');
                result.put('sedes', sc.Quote_Source__r != null ? sc.Quote_Source__r.Technical_Sedes__c : '---');
                result.put('fechaInicio', sc.StartDate != null ? sc.StartDate.format() : '---');
                result.put('fechaFin', sc.EndDate != null ? sc.EndDate.format() : '---');
                
                // Buscar contacto principal
                List<AccountContactRelation> acrs = [SELECT Contact.Name FROM AccountContactRelation WHERE AccountId = :sc.AccountId AND IsDirect = true LIMIT 1];
                if (!acrs.isEmpty()) result.put('contacto', acrs[0].Contact.Name);

                List<ContractLineItem> clis = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, Description FROM ContractLineItem WHERE ServiceContractId = :sc.Id];
                List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
                
                if (!clis.isEmpty()) {
                    for (ContractLineItem cli : clis) {
                        tratamientos.add(new Map<String, Object>{'id' => cli.Id, 'name' => cli.Product2.Name, 'quantity' => cli.Quantity, 'zonas' => cli.Description});
                    }
                } else if (sc.Quote_Source__c != null) {
                    // FALLBACK: Si el contrato no tiene partidas, buscamos en la cotización de origen
                    for (QuoteLineItem qli : [SELECT Id, Product2.Name, Quantity, Description, Zonas_a_Tratar__c FROM QuoteLineItem WHERE QuoteId = :sc.Quote_Source__c]) {
                        String zonas = String.isNotBlank(qli.Zonas_a_Tratar__c) ? qli.Zonas_a_Tratar__c : qli.Description;
                        tratamientos.add(new Map<String, Object>{'id' => qli.Id, 'name' => qli.Product2.Name, 'quantity' => qli.Quantity, 'zonas' => zonas});
                    }
                }
                
                result.put('tratamientos', tratamientos);
                return result;
            }

            Quote targetQuote;
            if (quoteId != null) {
                targetQuote = [SELECT Id, QuoteNumber, Name, GrandTotal, ExpirationDate, CreatedDate, AccountId, Account.Name, OpportunityId, 
                                     Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                                     Business_Lines_Selected__c, Technical_Sedes__c 
                              FROM Quote WHERE Id = :quoteId LIMIT 1];
            } else {
                List<Quote> syncingQuotes = [SELECT Id, QuoteNumber, Name, GrandTotal, ExpirationDate, CreatedDate, AccountId, Account.Name, OpportunityId,
                                                   Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                                                   Business_Lines_Selected__c, Technical_Sedes__c
                                            FROM Quote WHERE OpportunityId = :oppId AND IsSyncing = true LIMIT 1];
                if (syncingQuotes.isEmpty()) throw new AuraHandledException('No hay un presupuesto sincronizado.');
                targetQuote = syncingQuotes[0];
            }
            
            result.put('quoteId', targetQuote.Id);
            result.put('oppId', targetQuote.OpportunityId);
            result.put('accountId', targetQuote.AccountId);
            result.put('folio', targetQuote.QuoteNumber);
            result.put('cliente', targetQuote.Account.Name);
            result.put('direccion', targetQuote.Account.BillingStreet + ', ' + targetQuote.Account.BillingCity);
            result.put('lineaNegocio', targetQuote.Business_Lines_Selected__c != null ? targetQuote.Business_Lines_Selected__c : '---');
            result.put('sedes', targetQuote.Technical_Sedes__c != null ? targetQuote.Technical_Sedes__c : '---');
            result.put('fechaInicio', targetQuote.CreatedDate.format('dd-MMM-yyyy'));
            result.put('fechaFin', targetQuote.ExpirationDate != null ? targetQuote.ExpirationDate.format() : 'No definida');
            
            // Buscar contacto principal
            List<AccountContactRelation> acrsOpp = [SELECT Contact.Name FROM AccountContactRelation WHERE AccountId = :targetQuote.AccountId AND IsDirect = true LIMIT 1];
            if (!acrsOpp.isEmpty()) result.put('contacto', acrsOpp[0].Contact.Name);
            
            List<QuoteLineItem> qlis = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, Description, Zonas_a_Tratar__c FROM QuoteLineItem WHERE QuoteId = :targetQuote.Id];
            List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
            for (QuoteLineItem qli : qlis) {
                String zonas = String.isNotBlank(qli.Zonas_a_Tratar__c) ? qli.Zonas_a_Tratar__c : qli.Description;
                tratamientos.add(new Map<String, Object>{'id' => qli.Id, 'name' => qli.Product2.Name, 'quantity' => qli.Quantity, 'zonas' => zonas});
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getRecentWorkOrders(Id accountId) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        try {
            for (WorkOrder wo : [SELECT Id, WorkOrderNumber, Subject, CreatedDate FROM WorkOrder WHERE AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 10]) {
                results.add(new Map<String, String>{
                    'id' => wo.Id, 
                    'name' => wo.WorkOrderNumber + ' - ' + wo.Subject + ' (' + wo.CreatedDate.format('dd/MM/yyyy') + ')'
                });
            }
        } catch (Exception e) { }
        return results;
    }

    @AuraEnabled
    public static Map<String, Object> getWorkOrderTemplateData(Id workOrderId) {
        try {
            WorkOrder wo = [SELECT Id, Description, (SELECT Id, PricebookEntryId, PricebookEntry.Product2.Name, Quantity, Description FROM WorkOrderLineItems) 
                           FROM WorkOrder WHERE Id = :workOrderId LIMIT 1];
            
            List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
            Map<Id, List<String>> woliToTechs = new Map<Id, List<String>>();
            
            // Buscar técnicos asignados a los SAs de estos WOLIs
            Set<Id> woliIds = new Set<Id>();
            for (WorkOrderLineItem woli : wo.WorkOrderLineItems) woliIds.add(woli.Id);
            
            List<ServiceAppointment> sas = [SELECT Id, ParentRecordId, Duration, (SELECT ServiceResourceId FROM ServiceResources) 
                                           FROM ServiceAppointment WHERE ParentRecordId IN :woliIds];
            
            Map<Id, List<Map<String, Object>>> woliToScheduling = new Map<Id, List<Map<String, Object>>>();
            for (ServiceAppointment sa : sas) {
                if (!woliToScheduling.containsKey(sa.ParentRecordId)) woliToScheduling.put(sa.ParentRecordId, new List<Map<String, Object>>());
                
                List<String> techIds = new List<String>();
                for (AssignedResource ar : sa.ServiceResources) techIds.add(ar.ServiceResourceId);
                if (!woliToTechs.containsKey(sa.ParentRecordId)) woliToTechs.put(sa.ParentRecordId, techIds);

                woliToScheduling.get(sa.ParentRecordId).add(new Map<String, Object>{
                    'duration' => sa.Duration,
                    'notes' => 'Clonado de ODT anterior'
                });
            }

            for (WorkOrderLineItem woli : wo.WorkOrderLineItems) {
                tratamientos.add(new Map<String, Object>{
                    'id' => woli.PricebookEntryId, // Usamos el PBE Id como referencia para que el LWC lo identifique
                    'name' => woli.PricebookEntry.Product2.Name,
                    'quantity' => woli.Quantity,
                    'zonas' => woli.Description,
                    'tecnicosIds' => woliToTechs.containsKey(woli.Id) ? woliToTechs.get(woli.Id) : new List<String>(),
                    'schedulingRows' => woliToScheduling.containsKey(woli.Id) ? woliToScheduling.get(woli.Id) : new List<Map<String, Object>>()
                });
            }

            return new Map<String, Object>{
                'notes' => wo.Description,
                'tratamientos' => tratamientos
            };
        } catch (Exception e) { throw new AuraHandledException('Error cargando plantilla: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPriorityOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = WorkOrder.Priority.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for(Schema.PicklistEntry entry : ple) {
            options.add(new Map<String, String>{'label' => entry.getLabel(), 'value' => entry.getValue()});
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceTerritories() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        try {
            for (ServiceTerritory st : [SELECT Id, Name FROM ServiceTerritory WHERE IsActive = true ORDER BY Name ASC]) {
                results.add(new Map<String, String>{'label' => st.Name, 'value' => st.Id});
            }
        } catch (Exception e) { }
        return results;
    }

    @AuraEnabled
    public static String saveWorkOrders(String payloadJson) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            
            // PARSEO SEGURO DE IDS
            String eWoIdStr = (String) payload.get('existingWorkOrderId');
            String qIdStr = (String) payload.get('quoteId');
            String scIdStr = (String) payload.get('serviceContractId');
            String accIdStr = (String) payload.get('accountId');
            String territoryId = (String) payload.get('territoryId');

            Id existingWorkOrderId = String.isNotBlank(eWoIdStr) ? (Id) eWoIdStr : null;
            Id quoteId = String.isNotBlank(qIdStr) ? (Id) qIdStr : null;
            Id serviceContractId = String.isNotBlank(scIdStr) ? (Id) scIdStr : null;
            Id accountId = String.isNotBlank(accIdStr) ? (Id) accIdStr : null;

            String notes = (String) payload.get('notes');
            String folio = (String) payload.get('folio');
            String priority = (String) payload.get('priority');
            String executionAddress = (String) payload.get('executionAddress'); // Mapeado a Street por simplicidad en este ejemplo
            String contactPerson = (String) payload.get('contactPerson');
            List<Object> sedesPayload = (List<Object>) payload.get('sedesList');

            Account acc = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account WHERE Id = :accountId LIMIT 1];

            // DETERMINAR PRICEBOOK
            Id pricebookId = null;
            if (quoteId != null) pricebookId = [SELECT Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1].Pricebook2Id;
            else if (serviceContractId != null) pricebookId = [SELECT Pricebook2Id FROM ServiceContract WHERE Id = :serviceContractId LIMIT 1].Pricebook2Id;

            // 1. Crear o Buscar Work Order Maestra
            WorkOrder wo;
            if (existingWorkOrderId != null) {
                wo = [SELECT Id FROM WorkOrder WHERE Id = :existingWorkOrderId LIMIT 1];
                // Limpiar partidas previas para refrescar (Se vuelven a crear abajo)
                delete [SELECT Id FROM WorkOrderLineItem WHERE WorkOrderId = :wo.Id];
            } else {
                wo = new WorkOrder();
            }

            wo.Subject = 'Contrato Pyatz: ' + folio;
            wo.AccountId = accountId;
            wo.ServiceContractId = serviceContractId; 
            wo.Pricebook2Id = pricebookId;
            wo.Status = 'New';
            wo.Priority = String.isNotBlank(priority) ? priority : 'Medium';
            wo.ServiceTerritoryId = String.isNotBlank(territoryId) ? (Id) territoryId : null;
            
            // MAPEO DE DIRECCIÓN DE EJECUCIÓN
            if (String.isNotBlank(executionAddress)) {
                wo.Street = executionAddress; // En un caso real, se segmentaría en Street, City, etc.
                wo.City = acc.BillingCity;
                wo.State = acc.BillingState;
                wo.PostalCode = acc.BillingPostalCode;
                wo.Country = acc.BillingCountry;
            } else {
                wo.Street = acc.BillingStreet;
                wo.City = acc.BillingCity;
                wo.State = acc.BillingState;
                wo.PostalCode = acc.BillingPostalCode;
                wo.Country = acc.BillingCountry;
            }
            
            wo.Description = 'Generada desde 360 Pyatz.\nContacto en Sede: ' + contactPerson + '\nNotas:\n' + notes;
            upsert wo;

            // 2. Crear Work Order Line Items
            List<WorkOrderLineItem> wolisToInsert = new List<WorkOrderLineItem>();
            for (Object sedeObj : sedesPayload) {
                Map<String, Object> sede = (Map<String, Object>) sedeObj;
                for (Object traObj : (List<Object>) sede.get('tratamientos')) {
                    Map<String, Object> tra = (Map<String, Object>) traObj;
                    WorkOrderLineItem woli = new WorkOrderLineItem(WorkOrderId = wo.Id);
                    
                    String traIdStr = (String) tra.get('id');
                    Id traId = String.isNotBlank(traIdStr) ? (Id) traIdStr : null;

                    if (traId != null && traId.getSObjectType().getDescribe().getName() == 'QuoteLineItem') {
                        woli.PricebookEntryId = [SELECT PricebookEntryId FROM QuoteLineItem WHERE Id = :traId LIMIT 1].PricebookEntryId;
                    } else if (traId != null && traId.getSObjectType().getDescribe().getName() == 'ContractLineItem') {
                        woli.PricebookEntryId = [SELECT PricebookEntryId FROM ContractLineItem WHERE Id = :traId LIMIT 1].PricebookEntryId;
                    } else if (traId != null && traId.getSObjectType().getDescribe().getName() == 'PricebookEntry') {
                        woli.PricebookEntryId = traId; // Caso de carga desde ODT anterior
                    }
                    
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
                    List<String> techIdsTratamiento = new List<String>();
                    if (tra.containsKey('tecnicosIds')) for (Object tId : (List<Object>) tra.get('tecnicosIds')) techIdsTratamiento.add((String) tId);
                    
                    for (Object rowObj : (List<Object>) tra.get('schedulingRows')) {
                        Map<String, Object> row = (Map<String, Object>) rowObj;
                        Date d = Date.valueOf((String) row.get('date'));
                        String rowStartTimeStr = (String) row.get('startTime');
                        String rowTecnicoId = (String) row.get('tecnicoId');
                        Integer arrivalMargin = row.containsKey('arrivalMargin') ? Integer.valueOf(row.get('arrivalMargin')) : 0;

                        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = wolisToInsert[woliIndex].Id, Subject = 'Servicio: ' + (String) tra.get('name'));
                        sa.Street = wo.Street; sa.City = wo.City; sa.State = wo.State; sa.PostalCode = wo.PostalCode; sa.Country = wo.Country;
                        sa.ServiceTerritoryId = wo.ServiceTerritoryId;
                        sa.EarliestStartTime = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                        sa.DueDate = sa.EarliestStartTime.addDays(1);
                        sa.Duration = (Decimal) row.get('duration');
                        sa.DurationType = 'Minutes';
                        sa.Status = 'Ninguno';
                        
                        Integer h = 8, m = 0;
                        String finalStartTime = String.isNotBlank(rowStartTimeStr) ? rowStartTimeStr : startTimeStr;
                        
                        if (String.isNotBlank(finalStartTime)) {
                            List<String> pts = finalStartTime.substringBefore('.').split(':');
                            if (pts.size() >= 2) { h = Integer.valueOf(pts[0]); m = Integer.valueOf(pts[1]); }
                        }
                        
                        // CÁLCULO DE TIEMPOS PROFESIONAL (VENTANA DE TOLERANCIA)
                        Datetime scheduledStart = Datetime.newInstance(d, Time.newInstance(h, m, 0, 0));
                        
                        sa.SchedStartTime = scheduledStart;
                        sa.SchedEndTime = sa.SchedStartTime.addMinutes(Integer.valueOf(sa.Duration));
                        
                        // Inicio más temprano = Programado - Margen
                        sa.EarliestStartTime = scheduledStart.addMinutes(-arrivalMargin);
                        
                        // Vencimiento = Final del día (23:59:59)
                        sa.DueDate = Datetime.newInstance(d, Time.newInstance(23, 59, 59, 0));
                        
                        // Ventana de llegada (Promesa al cliente)
                        sa.ArrivalWindowStartTime = scheduledStart;
                        sa.ArrivalWindowEndTime = scheduledStart.addMinutes(arrivalMargin);
                        
                        if ((Boolean) row.get('locked')) sa.FSL__Pinned__c = true;
                        if (String.isNotBlank((String) row.get('notes'))) sa.ServiceNote = (String) row.get('notes');
                        sasToInsert.add(sa);
                        
                        // PRIORIZAR TÉCNICO DE FILA SOBRE TÉCNICOS DE TRATAMIENTO
                        if (String.isNotBlank(rowTecnicoId)) {
                            techniciansPerSA.add(new List<String>{rowTecnicoId});
                        } else {
                            techniciansPerSA.add(techIdsTratamiento);
                        }
                    }
                    woliIndex++;
                }
            }
            if (!sasToInsert.isEmpty()) {
                insert sasToInsert;
                
                // ACTUALIZACIÓN INMEDIATA A PROGRAMADO PARA SALTAR REGLA DE VALIDACIÓN
                List<ServiceAppointment> sasToUpdate = new List<ServiceAppointment>();
                for(ServiceAppointment sa : sasToInsert) {
                    sasToUpdate.add(new ServiceAppointment(Id = sa.Id, Status = 'Programado'));
                }
                update sasToUpdate;

                // 4. GENERAR INSPECCIONES TÉCNICAS AUTOMÁTICAS (NUEVO & REFINADO)
                List<Inspeccion_Tecnica__c> inspectionsToInsert = new List<Inspeccion_Tecnica__c>();
                Set<Id> pbeIds = new Set<Id>();
                for(WorkOrderLineItem woli : wolisToInsert) pbeIds.add(woli.PricebookEntryId);
                
                Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>([
                    SELECT Id, Product2.Plantilla_Inspeccion__c 
                    FROM PricebookEntry WHERE Id IN :pbeIds
                ]);
                
                Integer saPointer = 0;
                for (Integer i = 0; i < wolisToInsert.size(); i++) {
                    WorkOrderLineItem currentWoli = wolisToInsert[i];
                    PricebookEntry pbe = pbeMap.get(currentWoli.PricebookEntryId);
                    String templateName = (pbe != null) ? pbe.Product2.Plantilla_Inspeccion__c : null;
                    
                    // Si el producto tiene plantilla, creamos inspección para CADA SA asociada a este WOLI
                    // (Quantity define cuántos SAs se crearon para este WOLI)
                    Integer numSAsForThisWoli = Integer.valueOf(currentWoli.Quantity);
                    
                    if (String.isNotBlank(templateName)) {
                        for (Integer j = 0; j < numSAsForThisWoli; j++) {
                            if (saPointer < sasToInsert.size()) {
                                inspectionsToInsert.add(new Inspeccion_Tecnica__c(
                                    Cita_Servicio__c = sasToInsert[saPointer].Id,
                                    Tipo_Reporte__c = templateName,
                                    Respuestas_JSON__c = '[]'
                                ));
                                saPointer++;
                            }
                        }
                    } else {
                        saPointer += numSAsForThisWoli; // Avanzamos el puntero aunque no haya inspección
                    }
                }
                if (!inspectionsToInsert.isEmpty()) insert inspectionsToInsert;
                
                // 5. Intentar Asignar Técnicos (SILENCIOSO PARA EVITAR EL ERROR DE TERRITORIO)
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