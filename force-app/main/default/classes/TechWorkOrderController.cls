public with sharing class TechWorkOrderController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialWorkOrderData(Id oppId, Id quoteId, Id serviceContractId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            // 1. PRIORIDAD: Cargar desde el Contrato de Servicio si se proporciona el ID
            if (serviceContractId != null) {
                ServiceContract sc = [SELECT Id, Name, StartDate, EndDate, Account.Name, Quote_Source__r.QuoteNumber 
                                     FROM ServiceContract WHERE Id = :serviceContractId LIMIT 1];
                
                result.put('quoteId', sc.Quote_Source__c);
                result.put('accountId', sc.AccountId);
                result.put('folio', sc.Quote_Source__r != null ? sc.Quote_Source__r.QuoteNumber : sc.Name);
                result.put('cliente', sc.Account.Name);
                result.put('fechaInicio', sc.StartDate != null ? sc.StartDate.format() : '---');
                result.put('fechaFin', sc.EndDate != null ? sc.EndDate.format() : '---');
                
                List<ContractLineItem> clis = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, Description 
                                              FROM ContractLineItem WHERE ServiceContractId = :sc.Id];
                
                List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
                for (ContractLineItem cli : clis) {
                    Map<String, Object> t = new Map<String, Object>();
                    t.put('id', cli.Id);
                    t.put('name', cli.Product2.Name);
                    t.put('quantity', cli.Quantity);
                    t.put('zonas', cli.Description);
                    tratamientos.add(t);
                }
                result.put('tratamientos', tratamientos);
                return result;
            }

            // 2. RESPALDO: Lógica original basada en Quote
            Quote targetQuote;
            if (quoteId != null) {
                targetQuote = [SELECT Id, QuoteNumber, Name, GrandTotal, ExpirationDate, CreatedDate, AccountId, Account.Name, OpportunityId, ContactId
                               FROM Quote WHERE Id = :quoteId LIMIT 1];
            } else {
                List<Quote> syncingQuotes = [SELECT Id, QuoteNumber, Name, GrandTotal, ExpirationDate, CreatedDate, AccountId, Account.Name, OpportunityId, ContactId
                                            FROM Quote WHERE OpportunityId = :oppId AND IsSyncing = true LIMIT 1];
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
            
            List<QuoteLineItem> qlis = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, Description 
                                       FROM QuoteLineItem WHERE QuoteId = :targetQuote.Id];
            
            List<Map<String, Object>> tratamientos = new List<Map<String, Object>>();
            for (QuoteLineItem qli : qlis) {
                Map<String, Object> t = new Map<String, Object>();
                t.put('id', qli.Id);
                t.put('name', qli.Product2.Name);
                t.put('quantity', qli.Quantity);
                t.put('zonas', qli.Description);
                tratamientos.add(t);
            }
            result.put('tratamientos', tratamientos);
            
            return result;
        } catch (Exception e) { throw new AuraHandledException('Error en Carga ODT: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static String saveWorkOrders(String payloadJson) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            Id quoteId = (Id) payload.get('quoteId');
            Id accountId = (Id) payload.get('accountId');
            String notes = (String) payload.get('notes');
            String folio = (String) payload.get('folio');
            
            // 1. Crear Work Order Maestra (Nativa) vinculada al Cliente
            WorkOrder wo = new WorkOrder();
            wo.Subject = 'Contrato Pyatz: ' + folio; // PRECISIÓN: Identificamos la ODT por el Folio del Presupuesto
            wo.AccountId = accountId;
            wo.Description = 'Generada desde el Presupuesto ID: ' + quoteId + '\nNotas Generales:\n' + notes;
            wo.Status = 'New';
            insert wo;

            // 2. Procesar Sedes y Tratamientos
            List<Object> sedes = (List<Object>) payload.get('sedesList');
            List<WorkOrderLineItem> wolisToInsert = new List<WorkOrderLineItem>();
            
            for (Object sedeObj : sedes) {
                Map<String, Object> sede = (Map<String, Object>) sedeObj;
                List<Object> treatments = (List<Object>) sede.get('tratamientos');
                for (Object traObj : treatments) {
                    Map<String, Object> tra = (Map<String, Object>) traObj;
                    WorkOrderLineItem woli = new WorkOrderLineItem();
                    woli.WorkOrderId = wo.Id;
                    woli.Description = (String) tra.get('name') + ' - ' + (String) tra.get('zonas');
                    woli.Quantity = (Decimal) tra.get('quantity');
                    wolisToInsert.add(woli);
                }
            }
            if (!wolisToInsert.isEmpty()) insert wolisToInsert;

            // 3. Crear Service Appointments (Citas de Servicio) usando campos nativos FSL
            List<ServiceAppointment> sasToInsert = new List<ServiceAppointment>();
            Integer woliIndex = 0;
            for (Object sedeObj : sedes) {
                Map<String, Object> sede = (Map<String, Object>) sedeObj;
                
                // Horarios permitidos de la Sede para Ventanas de Llegada
                String startTimeStr = (String) sede.get('startTime');
                String endTimeStr = (String) sede.get('endTime');
                
                List<Object> treatments = (List<Object>) sede.get('tratamientos');
                for (Object traObj : treatments) {
                    Map<String, Object> tra = (Map<String, Object>) traObj;
                    List<Object> rows = (List<Object>) tra.get('schedulingRows');
                    
                    for (Object rowObj : rows) {
                        Map<String, Object> row = (Map<String, Object>) rowObj;
                        String visitDateStr = (String) row.get('date');
                        
                        ServiceAppointment sa = new ServiceAppointment();
                        sa.ParentRecordId = wolisToInsert[woliIndex].Id;
                        sa.Subject = 'Servicio: ' + (String) tra.get('name');
                        
                        // Configuración de Fechas Estándar
                        Datetime earliest = Datetime.valueOf(visitDateStr + ' 00:00:00');
                        sa.EarliestStartTime = earliest;
                        sa.DueDate = earliest.addDays(1);
                        sa.Duration = (Decimal) row.get('duration');
                        sa.DurationType = 'Minutes';
                        sa.Status = 'Scheduled';

                        // Mapeo de Ventanas de Llegada (Arrival Window)
                        if (String.isNotBlank(startTimeStr) && String.isNotBlank(endTimeStr)) {
                            try {
                                sa.ArrivalWindowStartTime = Datetime.valueOf(visitDateStr + ' ' + startTimeStr);
                                sa.ArrivalWindowEndTime = Datetime.valueOf(visitDateStr + ' ' + endTimeStr);
                            } catch(Exception e) { /* Ignorar si el formato de hora falla */ }
                        }

                        // USO DE CAMPOS NATIVOS DE FIELD SERVICE (FSL)
                        if ((Boolean) row.get('locked')) {
                            sa.FSL__Pinned__c = true; // CAMPO NATIVO FSL
                        }
                        if (String.isNotBlank((String) row.get('notes'))) {
                            sa.ServiceNote = (String) row.get('notes'); // CAMPO NATIVO FSL
                        }
                        
                        sasToInsert.add(sa);
                    }
                    woliIndex++;
                }
            }
            if (!sasToInsert.isEmpty()) insert sasToInsert;

            return wo.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error en Generación ODT: ' + e.getMessage());
        }
    }
}