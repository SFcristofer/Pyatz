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

            // 2. CARGAR TRATAMIENTOS "COMERCIALES"
            List<Map<String, Object>> tratamientosComerciales = new List<Map<String, Object>>();
            if (serviceContractId != null) {
                for (ContractLineItem cli : [SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, Quantity, Description, Levantamiento_Tecnico__c 
                                            FROM ContractLineItem WHERE ServiceContractId = :serviceContractId]) {
                    tratamientosComerciales.add(new Map<String, Object>{
                        'id' => cli.Id, 'name' => cli.Product2.Name, 'code' => cli.Product2.ProductCode, 'quantity' => cli.Quantity, 
                        'zonas' => cli.Description, 'levantamientoId' => cli.Levantamiento_Tecnico__c,
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

                List<ServiceAppointment> sas = [SELECT Id, Duration, SchedStartTime, ServiceNote, ArrivalWindowStartTime, ArrivalWindowEndTime, 
                                                FSL__Pinned__c, Producto_Relacionado__c, Zonas_a_Tratar__c,
                                                (SELECT ServiceResourceId FROM ServiceResources) 
                                               FROM ServiceAppointment WHERE ParentRecordId = :existingWO.Id ORDER BY SchedStartTime ASC];
                
                // Mapeo inteligente de citas existentes a tratamientos (evitando duplicados por producto)
                Map<Id, List<ServiceAppointment>> availableSAsByProduct = new Map<Id, List<ServiceAppointment>>();
                for (ServiceAppointment sa : sas) {
                    if (sa.Producto_Relacionado__c == null) continue;
                    if (!availableSAsByProduct.containsKey(sa.Producto_Relacionado__c)) {
                        availableSAsByProduct.put(sa.Producto_Relacionado__c, new List<ServiceAppointment>());
                    }
                    availableSAsByProduct.get(sa.Producto_Relacionado__c).add(sa);
                }

                for (Map<String, Object> tra : tratamientosComerciales) {
                    Id pId = (Id)tra.get('productId');
                    if (availableSAsByProduct.containsKey(pId) && !availableSAsByProduct.get(pId).isEmpty()) {
                        List<ServiceAppointment> matchingSAs = availableSAsByProduct.get(pId);
                        List<Map<String, Object>> rows = new List<Map<String, Object>>();
                        Set<String> techIds = new Set<String>();
                        String lastZonas = '';

                        for (ServiceAppointment sa : matchingSAs) {
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
                                'notes' => String.isNotBlank(sa.ServiceNote) ? sa.ServiceNote : '',
                                'arrivalMargin' => margin,
                                'locked' => sa.FSL__Pinned__c,
                                'tecnicoId' => firstTechId
                            });
                            lastZonas = sa.Zonas_a_Tratar__c;
                        }
                        tra.put('schedulingRows', rows);
                        tra.put('tecnicosIds', new List<String>(techIds));
                        if (String.isNotBlank(lastZonas)) tra.put('zonas', lastZonas);
                        
                        // Consumir las citas para que no se asignen a otro tratamiento del mismo producto
                        availableSAsByProduct.remove(pId);
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
        String query = 'SELECT Id, Name, Linea_de_Negocio__c, Tipo_de_Servicio__c, Id_Unico_Zona__c, Plantilla_de_Formulario__r.Name FROM Zona_Servicio_Pyatz__c WHERE Cuenta__c = :accountId';
        if (String.isNotBlank(searchTerm)) {
            String searchKey = '%' + searchTerm + '%';
            query += ' AND (Name LIKE :searchKey OR Tipo_de_Servicio__c LIKE :searchKey OR Id_Unico_Zona__c LIKE :searchKey OR Plantilla_de_Formulario__r.Name LIKE :searchKey)';
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
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            Id existingWorkOrderId = String.isNotBlank((String)payload.get('existingWorkOrderId')) ? (Id)payload.get('existingWorkOrderId') : null;
            Id quoteId = String.isNotBlank((String)payload.get('quoteId')) ? (Id)payload.get('quoteId') : null;
            Id serviceContractId = String.isNotBlank((String)payload.get('serviceContractId')) ? (Id)payload.get('serviceContractId') : null;
            Id accountId = (Id)payload.get('accountId');
            String territoryId = (String)payload.get('territoryId');
            String notes = (String)payload.get('notes');
            String folio = (String)payload.get('folio');
            String priority = (String)payload.get('priority');
            String executionAddress = (String)payload.get('executionAddress');
            String contactPerson = (String)payload.get('contactPerson');
            List<Object> sedesPayload = (List<Object>)payload.get('sedesList');

            Account acc = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry FROM Account WHERE Id = :accountId LIMIT 1];
            WorkOrder wo = existingWorkOrderId != null ? [SELECT Id FROM WorkOrder WHERE Id = :existingWorkOrderId LIMIT 1] : new WorkOrder();

            wo.Subject = 'Contrato Pyatz: ' + folio;
            wo.AccountId = accountId;
            wo.ServiceContractId = serviceContractId; 
            wo.Status = 'New';
            wo.Priority = String.isNotBlank(priority) ? priority : 'Medium';
            wo.ServiceTerritoryId = String.isNotBlank(territoryId) ? (Id)territoryId : null;
            wo.Street = String.isNotBlank(executionAddress) ? executionAddress : acc.BillingStreet;
            wo.City = acc.BillingCity; wo.State = acc.BillingState; wo.PostalCode = acc.BillingPostalCode; wo.Country = acc.BillingCountry;
            wo.Description = 'Generada desde 360 Pyatz.\nContacto en Sede: ' + contactPerson + '\nNotas:\n' + notes;
            upsert wo;

            List<ServiceAppointment> sasToUpsert = new List<ServiceAppointment>();
            Set<Id> incomingSaIds = new Set<Id>();
            Map<Integer, List<String>> techIndexMap = new Map<Integer, List<String>>();
            Map<Integer, List<String>> templateIndexMap = new Map<Integer, List<String>>();
            Map<Integer, Id> levantamientoIndexMap = new Map<Integer, Id>();

            Set<Id> originIds = new Set<Id>();
            for (Object sedeObj : sedesPayload) {
                for (Object traObj : (List<Object>)((Map<String, Object>)sedeObj).get('tratamientos')) {
                    originIds.add((Id)((Map<String, Object>)traObj).get('id'));
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

            Integer saIdx = 0;
            for (Object sedeObj : sedesPayload) {
                Map<String, Object> sede = (Map<String, Object>)sedeObj;
                for (Object traObj : (List<Object>)sede.get('tratamientos')) {
                    Map<String, Object> tra = (Map<String, Object>)traObj;
                    Id originId = (Id)tra.get('id');
                    Id productId = originToProduct.get(originId);
                    String defaultTemplate = productToTemplate.get(productId);
                    Id levId = (tra.get('levantamientoId') != null && String.valueOf(tra.get('levantamientoId')) != '') ? (Id)tra.get('levantamientoId') : null;
                    
                    List<String> zoneTemplates = new List<String>();
                    if (tra.containsKey('selectedZonesData')) {
                        for (Object zoneObj : (List<Object>)tra.get('selectedZonesData')) {
                            Map<String, Object> zone = (Map<String, Object>)zoneObj;
                            if (zone.containsKey('Plantilla_de_Formulario__c') && zone.get('Plantilla_de_Formulario__c') != null) {
                                String zTemp = (String)zone.get('Plantilla_de_Formulario__c');
                                if (!zoneTemplates.contains(zTemp)) zoneTemplates.add(zTemp);
                            }
                        }
                    }
                    if (zoneTemplates.isEmpty() && String.isNotBlank(defaultTemplate)) zoneTemplates.add(defaultTemplate);
                    
                    for (Object rowObj : (List<Object>)tra.get('schedulingRows')) {
                        Map<String, Object> row = (Map<String, Object>)rowObj;
                        Id saId = (row.get('saId') != null && String.valueOf(row.get('saId')) != '') ? (Id)row.get('saId') : null;
                        
                        ServiceAppointment sa = new ServiceAppointment();
                        if (saId != null) { sa.Id = saId; incomingSaIds.add(saId); }
                        else { sa.ParentRecordId = wo.Id; sa.Status = 'Ninguno'; }
                        
                        sa.Subject = 'Servicio: ' + (String)tra.get('name');
                        sa.Street = wo.Street; sa.City = wo.City; sa.State = wo.State; sa.PostalCode = wo.PostalCode; sa.Country = wo.Country;
                        sa.ServiceTerritoryId = wo.ServiceTerritoryId;
                        sa.Duration = (Decimal)row.get('duration');
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
                        if ((Boolean)row.get('locked')) sa.FSL__Pinned__c = true;
                        if (String.isNotBlank((String)row.get('notes'))) sa.ServiceNote = (String)row.get('notes');
                        
                        sasToUpsert.add(sa);
                        List<String> techs = new List<String>();
                        if (String.isNotBlank((String)row.get('tecnicoId'))) techs.add((String)row.get('tecnicoId'));
                        else if (tra.containsKey('tecnicosIds')) for (Object tId : (List<Object>)tra.get('tecnicosIds')) techs.add((String)tId);
                        
                        techIndexMap.put(saIdx, techs);
                        templateIndexMap.put(saIdx, zoneTemplates);
                        levantamientoIndexMap.put(saIdx, levId);
                        saIdx++;
                    }
                }
            }

            // COMENTADO POR SEGURIDAD PARA EVITAR BORRADO ACCIDENTAL DE DATOS TÉCNICOS
            /*
            if (existingWorkOrderId != null) {
                List<ServiceAppointment> orphans = [SELECT Id FROM ServiceAppointment WHERE ParentRecordId = :wo.Id AND Id NOT IN :incomingSaIds];
                if (!orphans.isEmpty()) {
                    Set<Id> saWithWork = new Map<Id, AggregateResult>([SELECT Cita_Servicio__c Id FROM Revision_Cita_Servicio__c WHERE Cita_Servicio__c IN :orphans AND Status__c = 'Completada' GROUP BY Cita_Servicio__c]).keySet();
                    List<ServiceAppointment> toDelete = new List<ServiceAppointment>();
                    for (ServiceAppointment ora : orphans) if (!saWithWork.contains(ora.Id)) toDelete.add(ora);
                    if (!toDelete.isEmpty()) delete toDelete;
                }
            }
            */

            if (!sasToUpsert.isEmpty()) {
                upsert sasToUpsert;
                
                Set<Id> saIds = new Map<Id, ServiceAppointment>(sasToUpsert).keySet();
                List<Revision_Cita_Servicio__c> allExistingRevs = [SELECT Id, Cita_Servicio__c FROM Revision_Cita_Servicio__c WHERE Cita_Servicio__c IN :saIds];
                Map<Id, List<Revision_Cita_Servicio__c>> revsBySA = new Map<Id, List<Revision_Cita_Servicio__c>>();
                for (Revision_Cita_Servicio__c r : allExistingRevs) {
                    if (!revsBySA.containsKey(r.Cita_Servicio__c)) revsBySA.put(r.Cita_Servicio__c, new List<Revision_Cita_Servicio__c>());
                    revsBySA.get(r.Cita_Servicio__c).add(r);
                }

                // Mapear ServiceResource a UserID para asignación correcta
                Set<Id> allTechSRIds = new Set<Id>();
                for (List<String> tList : techIndexMap.values()) for (String tId : tList) allTechSRIds.add((Id)tId);
                
                Map<Id, Id> srToUserId = new Map<Id, Id>();
                for (ServiceResource sr : [SELECT Id, RelatedRecordId FROM ServiceResource WHERE Id IN :allTechSRIds]) {
                    srToUserId.put(sr.Id, sr.RelatedRecordId);
                }

                List<ServiceAppointment> sasUpdate = new List<ServiceAppointment>();
                List<Revision_Cita_Servicio__c> revsToIns = new List<Revision_Cita_Servicio__c>();
                List<AssignedResource> arsToIns = new List<AssignedResource>();
                
                if (!incomingSaIds.isEmpty()) delete [SELECT Id FROM AssignedResource WHERE ServiceAppointmentId IN :incomingSaIds];

                Id firstUserOwnerId = null;
                for (Integer i = 0; i < sasToUpsert.size(); i++) {
                    ServiceAppointment currentSA = sasToUpsert[i];
                    if (currentSA.Status == 'Ninguno') sasUpdate.add(new ServiceAppointment(Id = currentSA.Id, Status = 'Programado'));
                    
                    List<String> saTechSRIds = techIndexMap.get(i);
                    Id saPrimaryUserId = (!saTechSRIds.isEmpty() && srToUserId.containsKey((Id)saTechSRIds[0])) ? srToUserId.get((Id)saTechSRIds[0]) : UserInfo.getUserId();
                    if (firstUserOwnerId == null && !saTechSRIds.isEmpty()) firstUserOwnerId = srToUserId.get((Id)saTechSRIds[0]);

                    if (!revsBySA.containsKey(currentSA.Id) || revsBySA.get(currentSA.Id).isEmpty()) {
                        Integer revCounter = 1;
                        for (String templateId : templateIndexMap.get(i)) {
                            revsToIns.add(new Revision_Cita_Servicio__c(
                                Cita_Servicio__c = currentSA.Id, 
                                Numero_Revision__c = revCounter++, 
                                Status__c = 'En Proceso', 
                                Plantilla_de_Formulario__c = (Id)templateId, 
                                Fecha_Revision__c = Datetime.now(), 
                                Tecnico__c = saPrimaryUserId // Asignamos el User ID del Técnico seleccionado
                            ));
                        }
                    }
                    
                    for (String tId : saTechSRIds) {
                        arsToIns.add(new AssignedResource(ServiceAppointmentId = currentSA.Id, ServiceResourceId = (Id)tId));
                    }
                }
                
                if (firstUserOwnerId != null && wo.OwnerId != firstUserOwnerId) {
                    try {
                        wo.OwnerId = firstUserOwnerId;
                        update wo;
                    } catch (Exception e) { }
                }

                if (!sasUpdate.isEmpty()) update sasUpdate;
                if (!revsToIns.isEmpty()) insert revsToIns;
                if (!arsToIns.isEmpty()) { try { insert arsToIns; } catch (DmlException e) { throw new AuraHandledException('Error al asignar técnicos: ' + e.getDmlMessage(0)); } }
            }
            return wo.Id;
        } catch (Exception e) { throw new AuraHandledException('Error: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static Map<String, Object> getWorkOrderTemplateData(Id workOrderId) { return null; }
}
