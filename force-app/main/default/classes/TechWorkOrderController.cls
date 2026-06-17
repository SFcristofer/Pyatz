public with sharing class TechWorkOrderController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialWorkOrderData(Id oppId, Id quoteId, Id serviceContractId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // 1. DETERMINAR DATOS DE ORIGEN (Quote o Opp)
            Quote targetQuote;
            if (quoteId != null) {
                targetQuote = [SELECT Id, QuoteNumber, Name, AccountId, Account.Name, OpportunityId, 
                                     Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                                     Business_Lines_Selected__c, Technical_Sedes__c, CreatedDate, ExpirationDate
                              FROM Quote WHERE Id = :quoteId LIMIT 1];
            } else {
                List<Quote> syncingQuotes = [SELECT Id, QuoteNumber, Name, AccountId, Account.Name, OpportunityId,
                                                   Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode,
                                                   Business_Lines_Selected__c, Technical_Sedes__c, CreatedDate, ExpirationDate
                                            FROM Quote WHERE OpportunityId = :oppId AND IsSyncing = true LIMIT 1];
                if (syncingQuotes.isEmpty()) throw new AuraHandledException('No hay un presupuesto sincronizado.');
                targetQuote = syncingQuotes[0];
            }

            // AUTO-RECUPERACIÓN DE CONTRATO SI NO SE PASÓ
            if (serviceContractId == null) {
                List<ServiceContract> scs = [SELECT Id FROM ServiceContract WHERE Quote_Source__c = :targetQuote.Id OR (AccountId = :targetQuote.AccountId AND Name LIKE :('%' + targetQuote.QuoteNumber + '%')) LIMIT 1];
                if (!scs.isEmpty()) serviceContractId = scs[0].Id;
            }

            // 2. CARGAR TRATAMIENTOS "COMERCIALES"
            List<Map<String, Object>> tratamientosComerciales = new List<Map<String, Object>>();
            if (serviceContractId != null) {
                for (ContractLineItem cli : [SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, Quantity, Description, Zonas_a_Tratar__c, Levantamiento_Tecnico__c 
                                            FROM ContractLineItem WHERE ServiceContractId = :serviceContractId]) {
                    String zonas = String.isNotBlank(cli.Zonas_a_Tratar__c) ? cli.Zonas_a_Tratar__c : cli.Description;
                    tratamientosComerciales.add(new Map<String, Object>{
                        'id' => cli.Id, 'name' => cli.Product2.Name, 'code' => cli.Product2.ProductCode, 'quantity' => cli.Quantity, 
                        'zonas' => zonas, 'levantamientoId' => cli.Levantamiento_Tecnico__c,
                        'productId' => cli.Product2Id
                    });
                }
            }
            if (tratamientosComerciales.isEmpty()) {
                for (QuoteLineItem qli : [SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, Quantity, Description, Zonas_a_Tratar__c, Levantamiento_Tecnico__c 
                                         FROM QuoteLineItem WHERE QuoteId = :targetQuote.Id]) {
                    String zonas = String.isNotBlank(qli.Zonas_a_Tratar__c) ? qli.Zonas_a_Tratar__c : qli.Description;
                    tratamientosComerciales.add(new Map<String, Object>{
                        'id' => qli.Id, 'name' => qli.Product2.Name, 'code' => qli.Product2.ProductCode, 'quantity' => qli.Quantity, 
                        'zonas' => zonas, 'levantamientoId' => qli.Levantamiento_Tecnico__c,
                        'productId' => qli.Product2Id
                    });
                }
            }

            // 3. BUSCAR ODT EXISTENTE
            WorkOrder existingWO = null;
            if (serviceContractId != null) {
                List<WorkOrder> wos = [SELECT Id, Priority, Description, ServiceTerritoryId FROM WorkOrder WHERE ServiceContractId = :serviceContractId LIMIT 1];
                if (!wos.isEmpty()) existingWO = wos[0];
            }
            if (existingWO == null) {
                String subjectSearch = '%' + targetQuote.QuoteNumber;
                List<WorkOrder> wos = [SELECT Id, Priority, Description, ServiceTerritoryId FROM WorkOrder WHERE Subject LIKE :subjectSearch AND AccountId = :targetQuote.AccountId ORDER BY CreatedDate DESC LIMIT 1];
                if (!wos.isEmpty()) existingWO = wos[0];
            }

            if (existingWO != null) {
                result.put('existingWorkOrderId', existingWO.Id);
                result.put('isUpdateMode', true);
                result.put('prioridad', existingWO.Priority != null ? existingWO.Priority : 'Medium');
                result.put('territoryId', existingWO.ServiceTerritoryId);
                result.put('notes', existingWO.Description);

                List<ServiceAppointment> sas = [SELECT Id, Duration, SchedStartTime, Status, ServiceNote, ArrivalWindowStartTime, ArrivalWindowEndTime, 
                                                FSL__Pinned__c, Producto_Relacionado__c, Subject, Zonas_a_Tratar__c,
                                                (SELECT ServiceResourceId FROM ServiceResources) 
                                               FROM ServiceAppointment WHERE ParentRecordId = :existingWO.Id ORDER BY SchedStartTime ASC];
                
                // Mapeo inteligente de citas existentes a tratamientos
                Map<Id, List<ServiceAppointment>> availableSAsByProduct = new Map<Id, List<ServiceAppointment>>();
                Map<String, List<ServiceAppointment>> availableSAsByName = new Map<String, List<ServiceAppointment>>();

                for (ServiceAppointment sa : sas) {
                    if (sa.Producto_Relacionado__c != null) {
                        if (!availableSAsByProduct.containsKey(sa.Producto_Relacionado__c)) availableSAsByProduct.put(sa.Producto_Relacionado__c, new List<ServiceAppointment>());
                        availableSAsByProduct.get(sa.Producto_Relacionado__c).add(sa);
                    } else if (String.isNotBlank(sa.Subject)) {
                        // PLAN B: Mapeo por nombre si el producto está vacío (para recuperar citas viejas)
                        String cleanName = sa.Subject.replace('Servicio: ', '').trim();
                        if (!availableSAsByName.containsKey(cleanName)) availableSAsByName.put(cleanName, new List<ServiceAppointment>());
                        availableSAsByName.get(cleanName).add(sa);
                    }
                }

                for (Map<String, Object> tra : tratamientosComerciales) {
                    Id pId = (Id)tra.get('productId');
                    String tName = (String)tra.get('name');
                    Integer qty = Integer.valueOf(tra.get('quantity'));
                    
                    // Prioridad 1: Match por Producto | Prioridad 2: Match por Nombre
                    List<ServiceAppointment> pool = new List<ServiceAppointment>();
                    if (availableSAsByProduct.containsKey(pId) && !availableSAsByProduct.get(pId).isEmpty()) {
                        pool = availableSAsByProduct.get(pId);
                    } else if (availableSAsByName.containsKey(tName) && !availableSAsByName.get(tName).isEmpty()) {
                        pool = availableSAsByName.get(tName);
                    }

                    if (!pool.isEmpty()) {
                        List<Map<String, Object>> rows = new List<Map<String, Object>>();
                        Set<String> techIds = new Set<String>();
                        String lastZonas = '';

                        Integer toConsume = Math.min(qty, pool.size());
                        for (Integer i = 0; i < toConsume; i++) {
                            ServiceAppointment sa = pool.remove(0);
                            String firstTechId = '';
                            for (AssignedResource ar : sa.ServiceResources) {
                                if (String.isBlank(firstTechId)) firstTechId = ar.ServiceResourceId;
                                techIds.add(ar.ServiceResourceId);
                            }
                            Integer margin = 0;
                            if (sa.ArrivalWindowStartTime != null && sa.ArrivalWindowEndTime != null) {
                                margin = Integer.valueOf((sa.ArrivalWindowEndTime.getTime() - sa.ArrivalWindowStartTime.getTime()) / (1000 * 60));
                            }
                            rows.add(new Map<String, Object>{
                                'saId' => sa.Id,
                                'date' => sa.SchedStartTime != null ? sa.SchedStartTime.format('yyyy-MM-dd') : '',
                                'startTime' => sa.SchedStartTime != null ? sa.SchedStartTime.format('HH:mm:ss.000') : '08:00:00.000',
                                'duration' => sa.Duration,
                                'status' => sa.Status,
                                'notes' => String.isNotBlank(sa.ServiceNote) ? sa.ServiceNote : '',
                                'arrivalMargin' => margin,
                                'locked' => sa.FSL__Pinned__c,
                                'tecnicoId' => firstTechId,
                                'tecnicosIds' => new List<String>(techIds)
                            });
                            // Solo sobreescribimos zonas si la cita trae algo útil (no vacío o default)
                            if (String.isNotBlank(sa.Zonas_a_Tratar__c) && sa.Zonas_a_Tratar__c != 'Sin descripción técnica') {
                                lastZonas = sa.Zonas_a_Tratar__c;
                            }
                        }
                        tra.put('schedulingRows', rows);
                        tra.put('tecnicosIds', new List<String>(techIds));
                        if (String.isNotBlank(lastZonas)) tra.put('zonas', lastZonas);
                    }
                }
            }

            result.put('quoteId', targetQuote.Id);
            result.put('oppId', targetQuote.OpportunityId);
            result.put('accountId', targetQuote.AccountId);
            result.put('serviceContractId', serviceContractId);
            result.put('folio', targetQuote.QuoteNumber);
            result.put('cliente', targetQuote.Account.Name);
            result.put('direccion', targetQuote.Account.BillingStreet + ', ' + targetQuote.Account.BillingCity);
            result.put('lineaNegocio', targetQuote.Business_Lines_Selected__c != null ? targetQuote.Business_Lines_Selected__c : '---');
            result.put('sedes', targetQuote.Technical_Sedes__c != null ? targetQuote.Technical_Sedes__c : '---');
            result.put('fechaInicio', targetQuote.CreatedDate.format('dd-MMM-yyyy'));
            result.put('fechaFin', targetQuote.ExpirationDate != null ? targetQuote.ExpirationDate.format() : 'No definida');
            
            List<AccountContactRelation> acrs = [SELECT Contact.Name FROM AccountContactRelation WHERE AccountId = :targetQuote.AccountId AND IsDirect = true LIMIT 1];
            if (!acrs.isEmpty()) result.put('contacto', acrs[0].Contact.Name);

            result.put('tratamientos', tratamientosComerciales);
            return result;
        } catch (Exception e) { throw new AuraHandledException('Error: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceResources() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (ServiceResource sr : [SELECT Id, Name FROM ServiceResource WHERE IsActive = true AND ResourceType = 'T' ORDER BY Name ASC LIMIT 50]) {
            results.add(new Map<String, String>{'id' => sr.Id, 'name' => sr.Name});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceTerritories() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (ServiceTerritory st : [SELECT Id, Name FROM ServiceTerritory WHERE IsActive = true ORDER BY Name ASC]) {
            results.add(new Map<String, String>{'label' => st.Name, 'value' => st.Id});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Zona_Servicio_Pyatz__c> getAccountZonesData(Id accountId, String searchTerm, String nameFilter, String templateFilter, String lobFilter, String codeFilter) {
        String query = 'SELECT Id, Name, Linea_de_Negocio__c, Tipo_de_Servicio__c, Id_Unico_Zona__c, (SELECT Plantilla__c, Plantilla__r.Name FROM Plantillas_de_Zona__r) FROM Zona_Servicio_Pyatz__c WHERE Cuenta__c = :accountId';
        if (String.isNotBlank(searchTerm)) {
            String searchKey = '%' + searchTerm + '%';
            query += ' AND (Name LIKE :searchKey OR Tipo_de_Servicio__c LIKE :searchKey OR Id_Unico_Zona__c LIKE :searchKey)';
        }
        query += ' ORDER BY Name ASC LIMIT 500';
        return Database.query(query);
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
    public static String saveWorkOrders(String payloadJson) {
        System.debug('--- TechWorkOrder - Inicio saveWorkOrders ---');
        System.debug('Payload recibido: ' + payloadJson);
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            
            // Extracción segura de IDs
            String existingIdStr = (String)payload.get('existingWorkOrderId');
            Id existingWorkOrderId = null;
            if (String.isNotBlank(existingIdStr)) {
                try { existingWorkOrderId = (Id)existingIdStr; } catch(Exception e) { System.debug('Error casting existingWorkOrderId: ' + existingIdStr); }
            }
            
            String quoteIdStr = (String)payload.get('quoteId');
            Id quoteId = null;
            if (String.isNotBlank(quoteIdStr)) {
                try { quoteId = (Id)quoteIdStr; } catch(Exception e) { System.debug('Error casting quoteId: ' + quoteIdStr); }
            }
            
            String contractIdStr = (String)payload.get('serviceContractId');
            Id serviceContractId = null;
            if (String.isNotBlank(contractIdStr)) {
                try { serviceContractId = (Id)contractIdStr; } catch(Exception e) { System.debug('Error casting serviceContractId: ' + contractIdStr); }
            }
            
            Id accountId = (Id)payload.get('accountId');
            System.debug('IDs procesados - WO: ' + existingWorkOrderId + ', Quote: ' + quoteId + ', Account: ' + accountId);

            String territoryId = (String)payload.get('territoryId');
            String notes = (String)payload.get('notes');
            String folio = (String)payload.get('folio');
            String priority = (String)payload.get('priority');
            String executionAddress = (String)payload.get('executionAddress');
            String contactPerson = (String)payload.get('contactPerson');
            List<Object> sedesPayload = (List<Object>)payload.get('sedesList');

            Account acc = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account WHERE Id = :accountId LIMIT 1];
            WorkOrder wo = existingWorkOrderId != null ? [SELECT Id, OwnerId FROM WorkOrder WHERE Id = :existingWorkOrderId LIMIT 1] : new WorkOrder();

            wo.Subject = 'Contrato Pyatz: ' + folio;
            wo.AccountId = accountId;
            wo.ServiceContractId = serviceContractId; 
            if (wo.Id == null) wo.Status = 'New';
            wo.Priority = String.isNotBlank(priority) ? priority : 'Medium';
            wo.ServiceTerritoryId = String.isNotBlank(territoryId) ? (Id)territoryId : null;
            wo.Street = String.isNotBlank(executionAddress) ? executionAddress : acc.BillingStreet;
            wo.City = acc.BillingCity; wo.State = acc.BillingState; wo.PostalCode = acc.BillingPostalCode; wo.Country = acc.BillingCountry;
            wo.Description = 'Generada desde 360 Pyatz.\nContacto en Sede: ' + contactPerson + '\nNotas:\n' + notes;
            
            System.debug('Upserting WorkOrder...');
            upsert wo;
            System.debug('WorkOrder Upserted ID: ' + wo.Id);

            List<ServiceAppointment> sasToUpsert = new List<ServiceAppointment>();
            Set<Id> incomingSaIds = new Set<Id>();
            Map<Integer, List<String>> techIndexMap = new Map<Integer, List<String>>();
            Map<Integer, List<String>> templateIndexMap = new Map<Integer, List<String>>();
            Map<Integer, Id> levantamientoIndexMap = new Map<Integer, Id>();

            Set<Id> originIds = new Set<Id>();
            for (Object sedeObj : sedesPayload) {
                for (Object traObj : (List<Object>)((Map<String, Object>)sedeObj).get('tratamientos')) {
                    String tId = (String)((Map<String, Object>)traObj).get('id');
                    if (String.isNotBlank(tId)) originIds.add((Id)tId);
                }
            }

            Map<Id, Id> originToProduct = new Map<Id, Id>();
            Map<Id, String> productToTemplate = new Map<Id, String>();
            if (!originIds.isEmpty()) {
                String firstIdStr = String.valueOf(new List<Id>(originIds)[0]);
                if (firstIdStr.startsWith('0QL')) {
                    for(QuoteLineItem qli : [SELECT Id, Product2Id, Product2.Plantilla_Inspeccion__c FROM QuoteLineItem WHERE Id IN :originIds]) {
                        originToProduct.put(qli.Id, qli.Product2Id);
                        productToTemplate.put(qli.Product2Id, qli.Product2.Plantilla_Inspeccion__c);
                    }
                } else if (firstIdStr.startsWith('08k')) {
                    for(ContractLineItem cli : [SELECT Id, Product2Id, Product2.Plantilla_Inspeccion__c FROM ContractLineItem WHERE Id IN :originIds]) {
                        originToProduct.put(cli.Id, cli.Product2Id);
                        productToTemplate.put(cli.Product2Id, cli.Product2.Plantilla_Inspeccion__c);
                    }
                }
            }

            // --- NUEVO: AUTO-MAPEO BULKIFICADO DE ZONAS DESDE TEXTO ---
            Set<String> allZoneNamesToSearch = new Set<String>();
            for (Object sedeObj : sedesPayload) {
                for (Object traObj : (List<Object>)((Map<String, Object>)sedeObj).get('tratamientos')) {
                    Map<String, Object> tra = (Map<String, Object>)traObj;
                    if (!tra.containsKey('selectedZonesData') && tra.containsKey('zonas') && String.isNotBlank((String)tra.get('zonas'))) {
                        for(String zn : ((String)tra.get('zonas')).split(',')) {
                            allZoneNamesToSearch.add(zn.trim());
                        }
                    }
                }
            }

            Map<String, List<String>> autoMapZonesToTemplates = new Map<String, List<String>>();
            if (!allZoneNamesToSearch.isEmpty()) {
                for(Zona_Servicio_Pyatz__c z : [SELECT Id, Name, (SELECT Plantilla__c FROM Plantillas_de_Zona__r) FROM Zona_Servicio_Pyatz__c WHERE Cuenta__c = :accountId AND Name IN :allZoneNamesToSearch]) {
                    if (!autoMapZonesToTemplates.containsKey(z.Name)) {
                        autoMapZonesToTemplates.put(z.Name, new List<String>());
                    }
                    for(Plantilla_de_Zona__c pz : z.Plantillas_de_Zona__r) {
                        if (String.isNotBlank(pz.Plantilla__c)) {
                            autoMapZonesToTemplates.get(z.Name).add(pz.Plantilla__c);
                        }
                    }
                }
            }
            // -----------------------------------------------------------


            // Precarga de estados actuales para evitar transiciones inválidas
            Map<Id, String> saCurrentStatusMap = new Map<Id, String>();
            Set<Id> saIdsToQuery = new Set<Id>();
            for (Object sedeObj : sedesPayload) {
                for (Object traObj : (List<Object>)((Map<String, Object>)sedeObj).get('tratamientos')) {
                    for (Object rowObj : (List<Object>)((Map<String, Object>)traObj).get('schedulingRows')) {
                        String sid = (String)((Map<String, Object>)rowObj).get('saId');
                        if (String.isNotBlank(sid)) saIdsToQuery.add((Id)sid);
                    }
                }
            }
            if (!saIdsToQuery.isEmpty()) {
                for (ServiceAppointment existingSa : [SELECT Id, Status FROM ServiceAppointment WHERE Id IN :saIdsToQuery]) {
                    saCurrentStatusMap.put(existingSa.Id, existingSa.Status);
                }
            }

            Integer saIdx = 0;
            for (Object sedeObj : sedesPayload) {
                Map<String, Object> sede = (Map<String, Object>)sedeObj;
                for (Object traObj : (List<Object>)sede.get('tratamientos')) {
                    Map<String, Object> tra = (Map<String, Object>)traObj;
                    Id originId = (tra.get('id') != null) ? (Id)tra.get('id') : null;
                    Id productId = (originId != null) ? originToProduct.get(originId) : null;
                    String defaultTemplate = (productId != null) ? productToTemplate.get(productId) : null;
                    Id levId = (tra.get('levantamientoId') != null && String.valueOf(tra.get('levantamientoId')) != '') ? (Id)tra.get('levantamientoId') : null;
                    
                    List<String> zoneTemplates = new List<String>();
                    if (tra.containsKey('selectedZonesData')) {
                        for (Object zoneObj : (List<Object>)tra.get('selectedZonesData')) {
                            Map<String, Object> zone = (Map<String, Object>)zoneObj;
                            if (zone.containsKey('Plantillas_de_Zona__r') && zone.get('Plantillas_de_Zona__r') != null) {
                                List<Object> pzrList = (List<Object>)zone.get('Plantillas_de_Zona__r');
                                for(Object pzrObj : pzrList) {
                                    Map<String, Object> pzr = (Map<String, Object>)pzrObj;
                                    if(pzr.containsKey('Plantilla__c')) {
                                        String zTemp = (String)pzr.get('Plantilla__c');
                                        if (String.isNotBlank(zTemp) && !zoneTemplates.contains(zTemp)) zoneTemplates.add(zTemp);
                                    }
                                }
                            } else if (zone.containsKey('Plantilla_de_Formulario__c') && zone.get('Plantilla_de_Formulario__c') != null) {
                                String zTemp = (String)zone.get('Plantilla_de_Formulario__c');
                                if (String.isNotBlank(zTemp) && !zoneTemplates.contains(zTemp)) zoneTemplates.add(zTemp);
                            }
                        }
                    }
                    
                    if (zoneTemplates.isEmpty() && !tra.containsKey('selectedZonesData') && tra.containsKey('zonas') && String.isNotBlank((String)tra.get('zonas'))) {
                        for(String zn : ((String)tra.get('zonas')).split(',')) {
                            String trimmed = zn.trim();
                            if (autoMapZonesToTemplates.containsKey(trimmed)) {
                                for (String pId : autoMapZonesToTemplates.get(trimmed)) {
                                    if (!zoneTemplates.contains(pId)) zoneTemplates.add(pId);
                                }
                            }
                        }
                    }
                    
                    if (zoneTemplates.isEmpty() && String.isNotBlank(defaultTemplate)) zoneTemplates.add(defaultTemplate);
                    
                    for (Object rowObj : (List<Object>)tra.get('schedulingRows')) {
                        Map<String, Object> row = (Map<String, Object>)rowObj;
                        String saIdStr = (String)row.get('saId');
                        Id saId = String.isNotBlank(saIdStr) ? (Id)saIdStr : null;
                        
                        ServiceAppointment sa = new ServiceAppointment();
                        if (saId != null) { sa.Id = saId; incomingSaIds.add(saId); }
                        else { sa.ParentRecordId = wo.Id; sa.Status = 'Ninguno'; }
                        
                        sa.Subject = 'Servicio: ' + (String)tra.get('name');
                        sa.Street = wo.Street; sa.City = wo.City; sa.State = wo.State; sa.PostalCode = wo.PostalCode; sa.Country = wo.Country;
                        sa.ServiceTerritoryId = wo.ServiceTerritoryId;
                        sa.Duration = row.get('duration') != null ? Decimal.valueOf(String.valueOf(row.get('duration'))) : 60;
                        sa.DurationType = 'Minutes';
                        sa.Zonas_a_Tratar__c = (String)tra.get('zonas');
                        sa.Producto_Relacionado__c = productId;
                        sa.Levantamiento_Tecnico__c = levId;
                        
                        Date d = Date.valueOf((String)row.get('date'));
                        String timeStr = (String)row.get('startTime');
                        Integer h = 8, m = 0;
                        if (String.isNotBlank(timeStr)) {
                            List<String> pts = timeStr.substringBefore('.').split(':');
                            if (pts.size() >= 2) { h = Integer.valueOf(pts[0]); m = Integer.valueOf(pts[1]); }
                        }
                        sa.SchedStartTime = Datetime.newInstance(d, Time.newInstance(h, m, 0, 0));
                        sa.SchedEndTime = sa.SchedStartTime.addMinutes(Integer.valueOf(sa.Duration));
                        sa.DueDate = Datetime.newInstance(d, Time.newInstance(23, 59, 59, 0));
                        sa.EarliestStartTime = sa.SchedStartTime.addMinutes(-60);

                        Integer margin = row.get('arrivalMargin') != null ? Integer.valueOf(String.valueOf(row.get('arrivalMargin'))) : 0;
                        sa.ArrivalWindowStartTime = sa.SchedStartTime.addMinutes(-margin);
                        sa.ArrivalWindowEndTime = sa.SchedStartTime.addMinutes(margin);

                        if (row.get('locked') == true) sa.FSL__Pinned__c = true;
                        if (String.isNotBlank((String)row.get('notes'))) sa.ServiceNote = (String)row.get('notes');
                        
                        List<String> techs = new List<String>();
                        if (row.containsKey('tecnicosIds') && row.get('tecnicosIds') != null) {
                            for (Object tId : (List<Object>)row.get('tecnicosIds')) {
                                techs.add((String)tId);
                            }
                        } else if (String.isNotBlank((String)row.get('tecnicoId'))) {
                            techs.add((String)row.get('tecnicoId')); // Retrocompatibilidad
                        } else if (tra.containsKey('tecnicosIds')) {
                            for (Object tId : (List<Object>)tra.get('tecnicosIds')) techs.add((String)tId);
                        }
                        
                        // PROTECCIÓN DE ESTADO
                        String currentStatus = saId != null ? saCurrentStatusMap.get(saId) : 'Ninguno';
                        if (!techs.isEmpty()) {
                            // Solo pasamos a Programado si el estado actual lo permite
                            if (currentStatus == 'Ninguno' || currentStatus == 'Cita solicitada' || currentStatus == 'New') {
                                sa.Status = 'Programado';
                            }
                        }

                        sasToUpsert.add(sa);
                        techIndexMap.put(saIdx, techs);
                        templateIndexMap.put(saIdx, zoneTemplates);
                        levantamientoIndexMap.put(saIdx, levId);
                        saIdx++;
                    }
                }
            }

            if (!sasToUpsert.isEmpty()) {
                // 1. Identificar citas existentes que son modificables (No están en curso ni completadas)
                Set<Id> modifiableSaIds = new Set<Id>();
                for (Id sid : incomingSaIds) {
                    String currentStatus = saCurrentStatusMap.get(sid);
                    if (currentStatus == null || currentStatus == 'Ninguno' || currentStatus == 'Cita solicitada' || currentStatus == 'New' || currentStatus == 'Programado') {
                        modifiableSaIds.add(sid);
                    }
                }

                // 2. BORRAR AssignedResources ANTES del upsert del ServiceAppointment.
                if (!modifiableSaIds.isEmpty()) {
                    List<AssignedResource> oldARs = [SELECT Id FROM AssignedResource WHERE ServiceAppointmentId IN :modifiableSaIds];
                    if (!oldARs.isEmpty()) delete oldARs;
                }

                // 3. RECUPERAR NOMBRES DE PLANTILLAS Y ASIGNAR TIPO_DE_REPORTE__C
                Set<Id> allTemplateIds = new Set<Id>();
                for (List<String> tList : templateIndexMap.values()) {
                    for (String tId : tList) {
                        if (String.isNotBlank(tId)) allTemplateIds.add((Id)tId);
                    }
                }
                Map<Id, String> globalTemplateNames = new Map<Id, String>();
                if (!allTemplateIds.isEmpty()) {
                    for(Form_Template__c ft : [SELECT Id, Name FROM Form_Template__c WHERE Id IN :allTemplateIds]) {
                        globalTemplateNames.put(ft.Id, ft.Name);
                    }
                }
                
                for (Integer i = 0; i < sasToUpsert.size(); i++) {
                    List<String> tList = templateIndexMap.get(i);
                    List<String> tNames = new List<String>();
                    for (String tId : tList) {
                        if (String.isNotBlank(tId) && globalTemplateNames.containsKey((Id)tId)) {
                            tNames.add(globalTemplateNames.get((Id)tId));
                        }
                    }
                    if (!tNames.isEmpty()) {
                        String combined = String.join(tNames, ', ');
                        if (combined.length() > 255) combined = combined.substring(0, 252) + '...';
                        sasToUpsert[i].Tipo_de_Reporte__c = combined;
                    } else {
                        sasToUpsert[i].Tipo_de_Reporte__c = 'Sin Plantilla Asignada';
                    }
                }

                System.debug('Upserting ' + sasToUpsert.size() + ' ServiceAppointments...');
                upsert sasToUpsert;
                
                Set<Id> saIds = new Map<Id, ServiceAppointment>(sasToUpsert).keySet();
                
                // --- LIMPIEZA DE HUÉRFANOS ---
                // Borrar citas que pertenecen a esta WO pero que ya NO están en la pantalla del usuario
                // Solo borramos las que no han avanzado (Status inicial)
                if (existingWorkOrderId != null) {
                    delete [SELECT Id FROM ServiceAppointment 
                            WHERE ParentRecordId = :wo.Id 
                            AND Id NOT IN :saIds 
                            AND Status IN ('Ninguno', 'Cita solicitada', 'New', 'Programado')];
                }

                // Cargar revisiones existentes para actualización
                List<Revision_Cita_Servicio__c> allExistingRevs = [SELECT Id, Cita_Servicio__c, Status__c FROM Revision_Cita_Servicio__c WHERE Cita_Servicio__c IN :saIds];
                Map<Id, List<Revision_Cita_Servicio__c>> revsBySA = new Map<Id, List<Revision_Cita_Servicio__c>>();
                for (Revision_Cita_Servicio__c r : allExistingRevs) {
                    if (!revsBySA.containsKey(r.Cita_Servicio__c)) revsBySA.put(r.Cita_Servicio__c, new List<Revision_Cita_Servicio__c>());
                    revsBySA.get(r.Cita_Servicio__c).add(r);
                }

                Set<Id> allTechSRIds = new Set<Id>();
                for (List<String> tList : techIndexMap.values()) for (String tId : tList) allTechSRIds.add((Id)tId);
                
                Map<Id, Id> srToUserId = new Map<Id, Id>();
                for (ServiceResource sr : [SELECT Id, RelatedRecordId FROM ServiceResource WHERE Id IN :allTechSRIds]) {
                    srToUserId.put(sr.Id, sr.RelatedRecordId);
                }

                List<Revision_Cita_Servicio__c> revsToUpsert = new List<Revision_Cita_Servicio__c>();
                List<AssignedResource> arsToIns = new List<AssignedResource>();

                Id firstUserOwnerId = null;
                for (Integer i = 0; i < sasToUpsert.size(); i++) {
                    ServiceAppointment currentSA = sasToUpsert[i];
                    List<String> saTechSRIds = techIndexMap.get(i);
                    Id saPrimaryUserId = (!saTechSRIds.isEmpty() && srToUserId.containsKey((Id)saTechSRIds[0])) ? srToUserId.get((Id)saTechSRIds[0]) : UserInfo.getUserId();
                    if (firstUserOwnerId == null && !saTechSRIds.isEmpty()) firstUserOwnerId = srToUserId.get((Id)saTechSRIds[0]);

                    // Si no tiene revisiones, creamos nuevas
                    if (!revsBySA.containsKey(currentSA.Id) || revsBySA.get(currentSA.Id).isEmpty()) {
                        Integer revCounter = 1;
                        List<String> templateIds = templateIndexMap.get(i);
                        
                        if (!templateIds.isEmpty()) {
                            for (String templateId : templateIds) {
                                if (String.isBlank(templateId)) continue;
                                String tName = globalTemplateNames.get((Id)templateId);
                                revsToUpsert.add(new Revision_Cita_Servicio__c(
                                    Cita_Servicio__c = currentSA.Id, 
                                    Numero_Revision__c = revCounter++, 
                                    Tipo_Reporte__c = tName,
                                    Status__c = 'En Proceso', 
                                    Plantilla_de_Formulario__c = (Id)templateId, 
                                    Fecha_Revision__c = Datetime.now(), 
                                    Tecnico__c = saPrimaryUserId
                                ));
                            }
                        } else {
                            // Crear revisión genérica si no hay plantilla
                            revsToUpsert.add(new Revision_Cita_Servicio__c(
                                Cita_Servicio__c = currentSA.Id, 
                                Numero_Revision__c = revCounter++, 
                                Tipo_Reporte__c = 'Sin Plantilla Asignada',
                                Status__c = 'En Proceso', 
                                Fecha_Revision__c = Datetime.now(), 
                                Tecnico__c = saPrimaryUserId
                            ));
                        }
                    } 
                    // Si ya tiene revisiones, actualizamos el técnico si no está completada
                    else {
                        for (Revision_Cita_Servicio__c r : revsBySA.get(currentSA.Id)) {
                            if (r.Status__c != 'Completada') {
                                r.Tecnico__c = saPrimaryUserId;
                                revsToUpsert.add(r);
                            }
                        }
                    }
                    
                    // Solo asignamos los técnicos nuevos si la cita era nueva o estaba en un estado modificable
                    Boolean canChangeTech = (!incomingSaIds.contains(currentSA.Id)) || modifiableSaIds.contains(currentSA.Id);
                    if (canChangeTech) {
                        for (String tId : saTechSRIds) {
                            arsToIns.add(new AssignedResource(ServiceAppointmentId = currentSA.Id, ServiceResourceId = (Id)tId));
                        }
                    }
                }
                
                if (firstUserOwnerId != null && wo.OwnerId != firstUserOwnerId) {
                    try { wo.OwnerId = firstUserOwnerId; update wo; } catch (Exception e) { }
                }

                if (!revsToUpsert.isEmpty()) upsert revsToUpsert;
                if (!arsToIns.isEmpty()) { 
                    try { insert arsToIns; } 
                    catch (Exception e) { throw new AuraHandledException('Error al asignar técnicos: ' + e.getMessage()); } 
                }
            }
            System.debug('--- TechWorkOrder - Fin exitoso ---');
            return wo.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) { 
            throw new AuraHandledException('Error Técnico: ' + e.getMessage() + ' (Línea: ' + e.getLineNumber() + ')'); 
        }
    }

    @AuraEnabled
    public static Map<String, Object> getWorkOrderTemplateData(Id workOrderId) { return null; }
}