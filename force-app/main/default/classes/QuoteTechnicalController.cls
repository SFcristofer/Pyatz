/**
 * Orquestador principal para la plataforma técnica Pyatz.
 * Actúa como pasarela entre los componentes Lightning (LWC) y los servicios especializados.
 */
public with sharing class QuoteTechnicalController {
    
    // --- GESTIÓN DE ARCHIVOS Y DOCUMENTOS ---

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRelatedFiles(Id recordId) {
        return FileService.getRelatedFiles(recordId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getAvailableAttachments(Id oppId) {
        return FileService.getAvailableAttachments(oppId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getDocumentStates(Id opportunityId) {
        return FileService.getDocumentStates(opportunityId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEvidenceGallery(Id opportunityId) {
        return FileService.getEvidenceGallery(opportunityId);
    }

    @AuraEnabled
    public static void renameUploadedFile(Id documentId, String docType) {
        FileService.renameAndLinkFile(documentId, docType);
    }

    @AuraEnabled
    public static void deleteDocument(Id documentId) {
        FileService.deleteDocument(documentId);
    }

    // --- COMUNICACIONES Y EMAILS ---

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEmailEngagementDetails(Id oppId) {
        return EmailService.getEmailEngagementDetails(oppId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolders(List<String> folderNames) {
        return EmailService.getEmailTemplatesByFolders(folderNames);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolder(String folderName) {
        return EmailService.getEmailTemplatesByFolders(new List<String>{folderName});
    }

    @AuraEnabled
    public static String renderTemplate(Id templateId, Id quoteId) {
        return EmailService.renderTemplate(templateId, quoteId);
    }

    @ AuraEnabled
    public static void sendEmailWithAttachments(Id oppId, String toEmail, String ccEmail, String subject, String body, List<Map<String, String>> selectedAttachments) {
        EmailService.sendEmailWithAttachments(oppId, toEmail, ccEmail, subject, body, selectedAttachments);
    }

    // --- MOTOR TÉCNICO Y PRESUPUESTOS ---

    @AuraEnabled
    public static Id saveTechnicalData(Map<String, Object> data) {
        return QuoteEngineService.saveTechnicalData(data);
    }

    @AuraEnabled
    public static void saveSurveyData(Id oppId, String type, String surveyDataJson, String diagDataJson) {
        LevantamientoService.saveSurveyData(oppId, type, surveyDataJson, diagDataJson);
    }

    @AuraEnabled
    public static List<Levantamiento_Tecnico__c> getLevantamientoDetails(Id recordId) {
        return LevantamientoService.getLevantamientoDetails(recordId);
    }

    @AuraEnabled
    public static Id cloneQuote(Id quoteId, Map<String, Object> options, Id targetSedeId, Id targetProspectoId) {
        try {
            Quote source = QuoteSelector.getQuoteById(quoteId);
            Quote target = source.clone(false, true, false, false);
            target.Name = 'CLON - ' + source.Name;
            target.Status = 'Draft';
            insert target;

            if (options == null || (Boolean)options.get('copyLineItems')) {
                List<QuoteLineItem> newQlis = new List<QuoteLineItem>();
                for (QuoteLineItem qli : QuoteSelector.getLineItemsByQuoteId(quoteId)) {
                    QuoteLineItem n = qli.clone(false, true, false, false);
                    n.QuoteId = target.Id;
                    newQlis.add(n);
                }
                if (!newQlis.isEmpty()) insert newQlis;
            }
            return target.Id;
        } catch (Exception e) { throw new AuraHandledException('Error en clonación: ' + e.getMessage()); }
    }

    // --- CALENDARIO Y OPERACIONES ---

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCalendarData(Id recordId, String startDate, String endDate) {
        return CalendarService.getCalendarData(startDate, endDate);
    }

    // --- ANÁLISIS DE RENTABILIDAD (P&L) ---

    @AuraEnabled(cacheable=true)
    public static List<Analisis_PL__c> getPLAnalysis(Id quoteId) {
        return QuoteSelector.getPLAnalysisByQuoteId(quoteId);
    }

    @AuraEnabled
    public static void savePLAnalysis(Id quoteId, String plDataJson) {
        try {
            List<Object> data = (List<Object>)JSON.deserializeUntyped(plDataJson);
            List<Analisis_PL__c> toUpsert = new List<Analisis_PL__c>();
            for (Object obj : data) {
                Map<String, Object> row = (Map<String, Object>)obj;
                Integer anio = Integer.valueOf(row.get('anio'));
                Analisis_PL__c pl = new Analisis_PL__c(Presupuesto__c = quoteId, Anio__c = anio, Costo_Inversion__c = Decimal.valueOf(String.valueOf(row.get('costo'))), Margen_Esperado__c = Decimal.valueOf(String.valueOf(row.get('margen'))), Gastos_Indirectos__c = Decimal.valueOf(String.valueOf(row.get('indirecto'))), Comision_Venta__c = Decimal.valueOf(String.valueOf(row.get('comision1'))), Comision_Venta_2__c = Decimal.valueOf(String.valueOf(row.get('comision2'))), Regalias__c = Decimal.valueOf(String.valueOf(row.get('regalia'))), Dias_Financiamiento__c = Decimal.valueOf(String.valueOf(row.get('dias'))), Clave_Unica__c = quoteId + '_' + anio);
                toUpsert.add(pl);
            }
            if (!toUpsert.isEmpty()) upsert toUpsert Clave_Unica__c;
        } catch (Exception e) { throw new AuraHandledException('Error P&L: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getHistoricalPL(Id quoteId) {
        Map<String, Decimal> history = new Map<String, Decimal>{ 'current' => 0, 'previous' => 0 };
        try {
            Id accId = [SELECT AccountId FROM Quote WHERE Id = :quoteId LIMIT 1].AccountId;
            Integer yr = Date.today().year();
            AggregateResult curr = [SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = :accId AND IsWon = true AND CALENDAR_YEAR(CloseDate) = :yr];
            AggregateResult prev = [SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = :accId AND IsWon = true AND CALENDAR_YEAR(CloseDate) = :(yr-1)];
            history.put('current', (Decimal)curr.get('total') != null ? (Decimal)curr.get('total') : 0);
            history.put('previous', (Decimal)prev.get('total') != null ? (Decimal)prev.get('total') : 0);
        } catch (Exception e) {}
        return history;
    }

    // --- CONSULTAS DE DATOS INICIALES Y BÚSQUEDA ---

    @AuraEnabled
    public static Map<String, Object> getInitialData(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        Id accountId;
        if(recordId != null) {
            String sType = recordId.getSObjectType().getDescribe().getName();
            if(sType == 'Quote') {
                Quote q = QuoteSelector.getQuoteById(recordId);
                accountId = q.AccountId;
                result.put('quote', q);
                result.put('opportunityName', q.Opportunity.Name);
                result.put('agenteNombre', q.CreatedBy.Name);
            } else if(sType == 'Opportunity') {
                Opportunity opp = QuoteSelector.getOpportunityById(recordId);
                accountId = opp.AccountId;
                result.put('opportunity', opp);
                result.put('opportunityName', opp.Name);
                result.put('agenteNombre', UserInfo.getName());
            }
        }
        if (accountId != null) result.put('locations', QuoteSelector.getSedesByParentId(accountId, 50));
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSedeContacts(Id sedeId) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Contact c : [SELECT Id, Name, Title FROM Contact WHERE AccountId = :sedeId AND IsEmailBounced = false ORDER BY Name ASC LIMIT 50]) {
            results.add(new Map<String, String>{ 'label' => c.Name, 'value' => c.Id, 'name' => c.Name, 'title' => c.Title != null ? c.Title : '' });
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchProducts(String searchTerm, Id quoteId, List<String> businessLines, Boolean allowOtherLines) {
        return QuoteEngineService.searchProducts(searchTerm, quoteId, businessLines, allowOtherLines);
    }

    // --- CONTRATOS Y SOLUCIONES ---

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContractInitialData(Id oppId) {
        Map<String, Object> result = new Map<String, Object>();
        Opportunity opp = QuoteSelector.getOpportunityById(oppId);
        result.put('opportunity', opp);
        result.put('quotes', [SELECT Id, QuoteNumber, Name, GrandTotal, Status, CreatedDate, Introduction_Text__c FROM Quote WHERE OpportunityId = :oppId ORDER BY CreatedDate DESC]);
        result.put('syncedQuoteId', opp.SyncedQuoteId);
        if (opp.SyncedQuoteId != null) result.put('selectedQuote', QuoteSelector.getQuoteById(opp.SyncedQuoteId));
        if (opp.AccountId != null) result.put('contacts', [SELECT Id, Name, Title FROM Contact WHERE AccountId = :opp.AccountId AND IsEmailBounced = false ORDER BY Name ASC]);
        return result;
    }

    @AuraEnabled
    public static String saveContractData(Id quoteId, Map<String, Object> contractData) {
        // Mantenemos esta lógica en el controlador temporalmente por su alta dependencia de múltiples objetos estándar
        try {
            Quote q = QuoteSelector.getQuoteById(quoteId);
            String scName = 'Contrato: ' + q.QuoteNumber + ' - ' + q.Name;
            List<ServiceContract> existing = [SELECT Id FROM ServiceContract WHERE Name = :scName AND AccountId = :q.AccountId LIMIT 1];
            ServiceContract sc = existing.isEmpty() ? new ServiceContract() : existing[0];
            sc.Name = scName; sc.AccountId = q.AccountId; sc.Pricebook2Id = q.Pricebook2Id;
            if (contractData.containsKey('fechaInicioContrato')) sc.StartDate = Date.valueOf((String)contractData.get('fechaInicioContrato'));
            if (contractData.containsKey('fechaVencimiento')) sc.EndDate = Date.valueOf((String)contractData.get('fechaVencimiento'));
            if (contractData.containsKey('clientSignerId')) sc.ContactId = (Id)contractData.get('clientSignerId');
            if (contractData.containsKey('contenidoLegal')) sc.Legal_Content__c = (String)contractData.get('contenidoLegal');
            upsert sc;
            update new Quote(Id = quoteId, Status = 'In Review');
            return sc.Id;
        } catch (Exception e) { throw new AuraHandledException('Error Contrato: ' + e.getMessage()); }
    }

    // --- UTILIDADES ---

    @AuraEnabled
    public static void saveMemoria(Id recordId, String text) {
        try {
            String sType = recordId.getSObjectType().getDescribe().getName();
            if (sType == 'Quote') update new Quote(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Opportunity') update new Opportunity(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Levantamiento_Tecnico__c') update new Levantamiento_Tecnico__c(Id = recordId, Memoria_Descriptiva__c = text);
        } catch (Exception e) { throw new AuraHandledException('Error Memoria: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static Boolean validatePLPassword(String password) {
        return password == System.Label.PL_Access_Password;
    }

    public static void syncServiceZones(Id quoteId, String markersBase64) {
        if (String.isBlank(markersBase64)) return;
        try {
            // 1. Obtener datos de la Cotización y sus partidas para contexto
            Quote q = [SELECT Id, AccountId, Business_Lines_Selected__c FROM Quote WHERE Id = :quoteId LIMIT 1];
            
            // Mapeo de Partidas para vinculación (Usamos Product2Id o PricebookEntryId como referencia)
            Map<String, Id> pbeToQliId = new Map<String, Id>();
            for (QuoteLineItem qli : [SELECT Id, PricebookEntryId FROM QuoteLineItem WHERE QuoteId = :quoteId]) {
                pbeToQliId.put(qli.PricebookEntryId, qli.Id);
            }
            
            // 2. Decodificar y Parsear JSON
            String jsonStr = EncodingUtil.base64Decode(markersBase64).toString();
            Map<String, Object> root = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
            
            List<Object> servicios = (List<Object>)root.get('serviciosData');
            if (servicios == null || servicios.isEmpty()) return;

            // 3. Procesar cada servicio y sus áreas (zonas)
            List<Zona_Servicio_Pyatz__c> zonesToUpsert = new List<Zona_Servicio_Pyatz__c>();
            for (Object obj : servicios) {
                Map<String, Object> s = (Map<String, Object>)obj;
                String areasStr = (String)s.get('areas');
                String serviceName = (String)s.get('descripcion');
                String techDetail = (String)s.get('detalleTecnico');
                String pbeId = (String)s.get('pbeId');
                String levantamientoId = (String)s.get('levantamientoId');
                
                if (String.isBlank(areasStr)) continue;

                List<String> zoneNames = areasStr.split(',');
                
                for (String zoneName : zoneNames) {
                    String trimmedName = zoneName.trim();
                    if (String.isBlank(trimmedName)) continue;

                    Zona_Servicio_Pyatz__c z = new Zona_Servicio_Pyatz__c();
                    z.Name = trimmedName;
                    z.Cotizacion__c = quoteId;
                    z.Cuenta__c = q.AccountId;
                    z.Tipo_de_Servicio__c = serviceName;
                    z.Detalle_Tecnico__c = techDetail;
                    
                    // --- NUEVOS VÍNCULOS DE INTEGRACIÓN ---
                    // Vinculación con el Levantamiento (Etapa 1)
                    if (String.isNotBlank(levantamientoId)) {
                        z.Levantamiento_Tecnico__c = (Id)levantamientoId;
                    }
                    
                    // Vinculación con la Línea de Negocio (Etapa 2)
                    z.Linea_de_Negocio__c = q.Business_Lines_Selected__c;

                    // Vinculación con la Partida de Cotización
                    if (pbeToQliId.containsKey(pbeId)) {
                        z.Linea_de_Cotizacion__c = pbeToQliId.get(pbeId);
                    }
                    
                    // Llave externa sanitizada
                    String safeName = trimmedName.toLowerCase().replaceAll('[^a-z0-9]', '_');
                    z.Id_Unico_Zona__c = quoteId + '_' + safeName;
                    
                    zonesToUpsert.add(z);
                }
            }

            if (!zonesToUpsert.isEmpty()) {
                upsert zonesToUpsert Id_Unico_Zona__c;
            }

        } catch (Exception e) {
            System.debug('Error en syncServiceZones: ' + e.getMessage());
        }
    }
}