public with sharing class QuoteTechnicalController {
    
    @AuraEnabled
    public static Map<String, Object> getContractInitialData(Id oppId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            Opportunity opp = [SELECT Id, Name, AccountId, SyncedQuoteId, (SELECT Id, QuoteNumber, Name, GrandTotal, Status, CreatedDate FROM Quotes ORDER BY CreatedDate DESC) FROM Opportunity WHERE Id = :oppId LIMIT 1];
            result.put('opportunity', opp);
            result.put('quotes', opp.Quotes);
            result.put('syncedQuoteId', opp.SyncedQuoteId);
            
            // Si hay una cotización sincronizada, traer sus datos de contrato actuales
            if (opp.SyncedQuoteId != null) {
                Quote q = [SELECT Id, Name, ExpirationDate, Description, Introduction_Text__c, Warranty_Text__c, Status FROM Quote WHERE Id = :opp.SyncedQuoteId];
                result.put('selectedQuote', q);
            }

            // Traer contactos para el firmante
            if (opp.AccountId != null) {
                result.put('contacts', [SELECT Id, Name, Title FROM Contact WHERE AccountId = :opp.AccountId AND IsEmailBounced = false ORDER BY Name ASC]);
            }
        } catch (Exception e) { throw new AuraHandledException('Error cargando datos de contrato: ' + e.getMessage()); }
        return result;
    }

    @AuraEnabled
    public static String saveContractData(Id quoteId, Map<String, Object> contractData) {
        try {
            Quote q = [SELECT Id, OpportunityId, AccountId, Pricebook2Id, QuoteNumber, Name FROM Quote WHERE Id = :quoteId LIMIT 1];
            
            // 1. Intentar buscar un contrato existente por nombre (ya que Quote_Source__c no existe)
            String scName = 'Contrato: ' + q.QuoteNumber + ' - ' + q.Name;
            List<ServiceContract> existing = [SELECT Id FROM ServiceContract WHERE Name = :scName AND AccountId = :q.AccountId LIMIT 1];
            ServiceContract sc = existing.isEmpty() ? new ServiceContract() : existing[0];

            // Mapeo de Cabecera (SOLO CAMPOS CONFIRMADOS EXISTENTES)
            sc.Name = scName;
            sc.AccountId = q.AccountId;
            sc.Pricebook2Id = q.Pricebook2Id;
            
            // Fechas Estándar (Confirmadas)
            if (contractData.containsKey('fechaInicioContrato') && String.isNotBlank((String)contractData.get('fechaInicioContrato'))) {
                sc.StartDate = Date.valueOf((String)contractData.get('fechaInicioContrato'));
            }
            if (contractData.containsKey('fechaVencimiento') && String.isNotBlank((String)contractData.get('fechaVencimiento'))) {
                sc.EndDate = Date.valueOf((String)contractData.get('fechaVencimiento'));
            }
            
            // Firmante y Contacto Estándar
            if (contractData.containsKey('clientSignerId') && String.isNotBlank((String)contractData.get('clientSignerId'))) {
                sc.ContactId = (Id)contractData.get('clientSignerId');
            }
            
            // Textos y Observaciones (Usando campos estándar para mayor seguridad)
            if (contractData.containsKey('contenidoLegal')) sc.Legal_Content__c = (String)contractData.get('contenidoLegal');
            if (contractData.containsKey('introduccion')) sc.Description = (String)contractData.get('introduccion');
            if (contractData.containsKey('observaciones')) sc.SpecialTerms = (String)contractData.get('observaciones');
            
            upsert sc;

            // 2. Mapear Partidas (ContractLineItem)
            if (contractData.containsKey('lineItemsJson')) {
                delete [SELECT Id FROM ContractLineItem WHERE ServiceContractId = :sc.Id];
                
                List<Object> items = (List<Object>)JSON.deserializeUntyped((String)contractData.get('lineItemsJson'));
                List<ContractLineItem> cliList = new List<ContractLineItem>();
                
                for (Object obj : items) {
                    Map<String, Object> it = (Map<String, Object>)obj;
                    if (it.containsKey('isSelected') && (Boolean)it.get('isSelected')) {
                        ContractLineItem cli = new ContractLineItem();
                        cli.ServiceContractId = sc.Id;
                        cli.PricebookEntryId = (Id)it.get('PricebookEntryId');
                        cli.Quantity = Decimal.valueOf(String.valueOf(it.get('Quantity')));
                        cli.UnitPrice = Decimal.valueOf(String.valueOf(it.get('UnitPrice')));
                        cli.Description = (String)it.get('Description');
                        cliList.add(cli);
                    }
                }
                if (!cliList.isEmpty()) insert cliList;
            }

            // 3. Actualizar la Quote
            q.Status = 'In Review';
            update q;

            return sc.Id;
        } catch (Exception e) { 
            throw new AuraHandledException('Error en Contrato Nativo: ' + e.getMessage()); 
        }
    }

    @AuraEnabled
    public static void cloneQuoteToContract(Id sourceQuoteId, Id targetOppId) {
        // Lógica futura si se requiere separar presupuesto de contrato
    }

    @AuraEnabled
    public static Id saveNote(Id parentId, String title, String content) {
        try {
            ContentNote cn = new ContentNote();
            cn.Title = title;
            cn.Content = Blob.valueOf(content.escapeHtml4());
            insert cn;
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cn.Id;
            cdl.LinkedEntityId = parentId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
            
            return cn.Id;
        } catch (Exception e) { throw new AuraHandledException('Error al guardar nota: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTacticalHistory(Id oppId) {
        List<Map<String, Object>> history = new List<Map<String, Object>>();
        if (oppId == null) return history;

        // 1. Recolectar todos los IDs relacionados (Estrategia de Burbujeo)
        Set<Id> allRelatedIds = new Set<Id>{oppId};
        for (Levantamiento_Tecnico__c lev : [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId]) {
            allRelatedIds.add(lev.Id);
        }
        for (Solucion_Tecnica__c sol : [SELECT Id FROM Solucion_Tecnica__c WHERE Levantamiento_Tecnico__r.Oportunidad__c = :oppId]) {
            allRelatedIds.add(sol.Id);
        }
        
        // 2. Tareas y Llamadas (Limpia duplicidad de EmailMessage al centralizar aquí)
        for (Task t : [SELECT Id, Subject, Status, Description, TaskSubtype, CreatedDate FROM Task WHERE WhatId = :oppId ORDER BY CreatedDate DESC LIMIT 40]) {
            String subType = t.TaskSubtype != null ? t.TaskSubtype : 'Task';
            String icon = subType == 'Call' ? 'standard:log_a_call' : (subType == 'Email' ? 'standard:email' : 'standard:task');
            String color = subType == 'Call' ? 'background: #e3f2fd;' : (subType == 'Email' ? 'background: #f1f8e9;' : 'background: #fff3e0;');
            
            history.add(new Map<String, Object>{ 
                'id' => t.Id, 
                'type' => 'Actividad', 
                'label' => subType, 
                'subject' => t.Subject, 
                'date' => t.CreatedDate, 
                'icon' => icon, 
                'color' => color, 
                'desc' => t.Description,
                'status' => t.Status,
                'isTask' => (subType != 'Email') // Todas las actividades menos los correos informativos son gestionables
            });
        }

        // 3. HITOS DE NEGOCIO: Levantamientos y Soluciones
        for (Levantamiento_Tecnico__c lev : [SELECT Id, Name, Tipo_Servicio__c, CreatedDate FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY CreatedDate DESC]) {
            history.add(new Map<String, Object>{ 'id' => lev.Id, 'type' => 'Levantamiento', 'label' => 'Auditoría Técnica', 'subject' => 'Levantamiento: ' + lev.Tipo_Servicio__c, 'date' => lev.CreatedDate, 'icon' => 'standard:survey', 'color' => 'background: #ede7f6;', 'desc' => 'Se registraron hallazgos técnicos en la sede cliente.' });
        }
        for (Solucion_Tecnica__c sol : [SELECT Id, Name, CreatedDate, Levantamiento_Tecnico__r.Tipo_Servicio__c FROM Solucion_Tecnica__c WHERE Levantamiento_Tecnico__r.Oportunidad__c = :oppId ORDER BY CreatedDate DESC]) {
            history.add(new Map<String, Object>{ 'id' => sol.Id, 'type' => 'Solución', 'label' => 'Propuesta Técnica', 'subject' => 'Solución: ' + sol.Name, 'date' => sol.CreatedDate, 'icon' => 'standard:solution', 'color' => 'background: #e8f5e9;', 'desc' => 'Propuesta técnica derivada del levantamiento de ' + sol.Levantamiento_Tecnico__r.Tipo_Servicio__c });
        }
        
        // 4. Notas y Archivos Agregados (Oportunidad + Levantamientos + Soluciones)
        Set<Id> docIds = new Set<Id>();
        Map<Id, Id> docToEntityMap = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :allRelatedIds]) {
            docIds.add(cdl.ContentDocumentId);
            docToEntityMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
        }

        if (!docIds.isEmpty()) {
            // 4a. Notas (ContentNote)
            for (ContentNote n : [SELECT Id, Title, Content, CreatedDate FROM ContentNote WHERE Id IN :docIds ORDER BY CreatedDate DESC LIMIT 20]) {
                String origin = docToEntityMap.get(n.Id).getSObjectType().getDescribe().getLabel();
                history.add(new Map<String, Object>{ 'id' => n.Id, 'type' => 'Nota', 'label' => 'Nota (' + origin + ')', 'subject' => n.Title, 'date' => n.CreatedDate, 'icon' => 'standard:note', 'color' => 'background: #fdfae5;', 'desc' => 'Nota registrada en el expediente técnico.' });
            }

            // 4b. Archivos e Imágenes (ContentVersion)
            for (ContentVersion cv : [SELECT Id, Title, FileExtension, ContentDocumentId, CreatedDate FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true ORDER BY CreatedDate DESC LIMIT 20]) {
                String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
                Boolean isImg = new Set<String>{'png', 'jpg', 'jpeg', 'gif'}.contains(ext);
                String origin = docToEntityMap.get(cv.ContentDocumentId).getSObjectType().getDescribe().getLabel();
                
                history.add(new Map<String, Object>{ 
                    'id' => cv.Id, 
                    'type' => isImg ? 'Imagen' : 'Archivo', 
                    'label' => (isImg ? 'Imagen' : 'Archivo') + ' (' + origin + ')', 
                    'subject' => cv.Title + '.' + cv.FileExtension, 
                    'date' => cv.CreatedDate, 
                    'icon' => isImg ? 'standard:image' : 'standard:file', 
                    'color' => isImg ? 'background: #f3e5f5;' : 'background: #eceff1;',
                    'previewUrl' => isImg ? '/sfc/servlet.shepherd/version/download/' + cv.Id : null,
                    'desc' => 'Documento cargado desde ' + origin
                });
            }
        }

        return history;
    }

    @AuraEnabled
    public static void updateTaskActivity(Id taskId, String newStatus, String observation) {
        try {
            Task t = [SELECT Id, Status, Description FROM Task WHERE Id = :taskId LIMIT 1];
            if (String.isNotBlank(newStatus)) {
                t.Status = newStatus;
            }
            if (String.isNotBlank(observation)) {
                String timestamp = '[' + System.now().format('dd/MM/yyyy HH:mm') + ' - ' + UserInfo.getName() + ']: ';
                String currentDesc = t.Description != null ? t.Description : '';
                t.Description = currentDesc + '\n' + timestamp + observation;
            }
            update t;
        } catch (Exception e) {
            throw new AuraHandledException('Error al actualizar tarea: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchUsers(String searchTerm) {
        String query = '%' + searchTerm + '%';
        List<User> users = [SELECT Id, Name, Title FROM User WHERE Name LIKE :query AND IsActive = true LIMIT 5];
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (User u : users) {
            results.add(new Map<String, String>{ 'id' => u.Id, 'name' => u.Name, 'title' => u.Title != null ? u.Title : 'Colaborador' });
        }
        return results;
    }

    /**
     * Guarda o actualiza el seguimiento de una sub-etapa específica.
     */
    @AuraEnabled
    public static void saveStageTracking(Id opportunityId, String stage, String subStage, String status) {
        try {
            String uniqueKey = opportunityId + '_' + stage + '_' + subStage;
            Seguimiento_Etapas_Pyatz__c track = new Seguimiento_Etapas_Pyatz__c();
            track.Oportunidad__c = opportunityId;
            track.Etapa__c = stage;
            track.Subetapa__c = subStage;
            track.Estado__c = status;
            track.Clave_Unica__c = uniqueKey;
            
            upsert track Clave_Unica__c;
        } catch (Exception e) {
            throw new AuraHandledException('Error al guardar seguimiento: ' + e.getMessage());
        }
    }

    /**
     * Recupera el historial de estados para el Dashboard de Autorización.
     */
    @AuraEnabled(cacheable=true)
    public static List<Seguimiento_Etapas_Pyatz__c> getProcessHistory(Id opportunityId) {
        return [SELECT Etapa__c, Subetapa__c, Estado__c, LastModifiedDate 
                FROM Seguimiento_Etapas_Pyatz__c 
                WHERE Oportunidad__c = :opportunityId 
                ORDER BY CreatedDate ASC];
    }

    /**
     * Recupera la lista de oportunidades abiertas (Pipeline Activo).
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOpenOpportunities() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(Opportunity o : [SELECT Id, Name FROM Opportunity WHERE IsClosed = false ORDER BY Name ASC LIMIT 100]) {
            options.add(new Map<String, String>{
                'label' => o.Name,
                'value' => o.Id
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getQuoteStats() {
        Map<String, Integer> stats = new Map<String, Integer>{
            'Total' => 0, 'Aprobada' => 0, 'Pendiente' => 0, 'Rechazada' => 0, 'Actualizada' => 0
        };
        for (AggregateResult ar : [SELECT Status, COUNT(Id) total FROM Quote GROUP BY Status]) {
            String status = (String)ar.get('Status');
            Integer count = (Integer)ar.get('total');
            stats.put('Total', stats.get('Total') + count);
            if (status == 'Approved' || status == 'Aprobada') stats.put('Aprobada', count);
            else if (status == 'Draft' || status == 'Borrador' || status == 'Pendiente') stats.put('Pendiente', stats.get('Pendiente') + count);
            else if (status == 'Rejected' || status == 'Rechazada') stats.put('Rechazada', count);
            else if (status == 'Actualizada') stats.put('Actualizada', count);
        }
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpportunitiesList() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(Opportunity o : [SELECT Id, Name, Account.Name, StageName, Amount, CloseDate, Owner.Name 
                       FROM Opportunity ORDER BY CreatedDate DESC LIMIT 50]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', o.Id);
            row.put('name', o.Name);
            row.put('account', o.Account.Name);
            row.put('owner', o.Owner.Name);
            row.put('closeDate', o.CloseDate);
            row.put('amount', o.Amount);
            row.put('stageName', o.StageName);
            result.add(row);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getQuotesList(Id opportunityId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        String query = 'SELECT Id, QuoteNumber, Name, Account.Name, Status, GrandTotal, CreatedDate, CreatedBy.Name, Technical_Sedes__c ' +
                      'FROM Quote ';
        
        if (opportunityId != null) {
            query += 'WHERE OpportunityId = :opportunityId ';
        }
        
        query += 'ORDER BY CreatedDate DESC LIMIT 50';

        for(Quote q : Database.query(query)) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', q.Id);
            row.put('folio', q.QuoteNumber);
            row.put('asunto', q.Name);
            row.put('cliente', q.Account.Name);
            row.put('sede', q.Technical_Sedes__c);
            row.put('generadoPor', q.CreatedBy.Name);
            row.put('fecha', q.CreatedDate);
            row.put('monto', q.GrandTotal);
            row.put('estado', q.Status);
            
            // Lógica de clases CSS para estados
            String css = 'slds-badge';
            if (q.Status == 'Approved' || q.Status == 'Aprobada') css += ' slds-theme_success';
            else if (q.Status == 'Draft' || q.Status == 'Borrador') css += ' slds-theme_warning';
            else if (q.Status == 'Rejected' || q.Status == 'Rechazada') css += ' slds-theme_error';
            row.put('estadoClass', css);
            
            result.add(row);
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getInitialData(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        Id accountId;
        if(recordId != null) {
            String sType = recordId.getSObjectType().getDescribe().getName();
            if(sType == 'Quote') {
                Quote q = [SELECT Id, Name, QuoteNumber, AccountId, Account.Name, ContactId, Contact.Name, Status, Description, 
                           Markers_Data__c, Introduction_Text__c, Warranty_Text__c, Business_Lines_Selected__c, 
                           Technical_Sedes__c, Show_Introduction__c, Show_Warranty__c, CreatedBy.Name, CreatedDate,
                           OpportunityId, Opportunity.Name
                           FROM Quote WHERE Id = :recordId];
                accountId = q.AccountId;
                result.put('quote', q);
                result.put('opportunityName', q.Opportunity.Name); // Nuevo: Enviar nombre de opp
                result.put('agenteNombre', q.CreatedBy.Name);
            } else if(sType == 'Opportunity') {
                Opportunity opp = [SELECT Id, Name, AccountId, Account.Name, Pricebook2Id FROM Opportunity WHERE Id = :recordId];
                accountId = opp.AccountId;
                result.put('opportunity', opp);
                result.put('opportunityName', opp.Name); // Nuevo: Enviar nombre de opp
                result.put('agenteNombre', UserInfo.getName());
            }
        }
        if (accountId != null) {
            result.put('locations', [SELECT Id, Name, BillingStreet, BillingCity, Phone FROM Account WHERE ParentId = :accountId LIMIT 50]);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBusinessLineOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(Schema.PicklistEntry f : Product2.Family.getDescribe().getPicklistValues()) {
            if(f.isActive()) options.add(new Map<String, String>{'label' => f.getLabel(), 'value' => f.getValue()});
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchProducts(String searchTerm, Id quoteId, List<String> businessLines, Boolean allowOtherLines) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        Id pbId;
        if (quoteId != null) {
            String sType = quoteId.getSObjectType().getDescribe().getName();
            if (sType == 'Quote') pbId = [SELECT Pricebook2Id FROM Quote WHERE Id = :quoteId].Pricebook2Id;
            else if (sType == 'Opportunity') pbId = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :quoteId].Pricebook2Id;
        }
        if (pbId == null) pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        
        String query = '%' + searchTerm + '%';
        String soql = 'SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, Product2.Description, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pbId AND (Product2.Name LIKE :query OR Product2.ProductCode LIKE :query) AND IsActive = true ';
        if (!allowOtherLines && businessLines != null && !businessLines.isEmpty()) soql += 'AND Product2.Family IN :businessLines ';
        for (PricebookEntry pbe : Database.query(soql + ' LIMIT 15')) {
            results.add(new Map<String, Object>{ 'id' => pbe.Id, 'productId' => pbe.Product2Id, 'name' => pbe.Product2.Name, 'sku' => pbe.Product2.ProductCode, 'description' => pbe.Product2.Description, 'unitPrice' => pbe.UnitPrice });
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getProductPrices(Id product2Id) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (PricebookEntry pbe : [SELECT Id, Pricebook2.Name, UnitPrice FROM PricebookEntry WHERE Product2Id = :product2Id AND IsActive = true AND Pricebook2.IsActive = true]) {
            results.add(new Map<String, Object>{ 'pbeId' => pbe.Id, 'pricebookName' => pbe.Pricebook2.Name, 'unitPrice' => pbe.UnitPrice });
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchNecesidades(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Necesidades__c n : [SELECT Id, Name, Linea_de_negocio__c FROM Necesidades__c WHERE Name LIKE :query LIMIT 10]) {
            results.add(new Map<String, String>{'id' => n.Id, 'name' => n.Name + ' (' + n.Linea_de_negocio__c + ')'});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolder(String folderName) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (EmailTemplate et : [SELECT Id, Name FROM EmailTemplate WHERE Folder.Name = :folderName AND IsActive = true]) {
            results.add(new Map<String, String>{'id' => et.Id, 'name' => et.Name});
        }
        return results;
    }

    @AuraEnabled
    public static String renderTemplate(Id templateId, Id quoteId) {
        if (templateId == null || quoteId == null) return '';
        try {
            Quote q = [SELECT ContactId, AccountId, Account.Name, Technical_Sedes__c, QuoteNumber FROM Quote WHERE Id = :quoteId LIMIT 1];
            Id conId = q.ContactId;
            if (conId == null) {
                List<Contact> cs = [SELECT Id FROM Contact WHERE AccountId = :q.AccountId LIMIT 1];
                if (!cs.isEmpty()) conId = cs[0].Id;
            }
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, conId, quoteId);
            String body = rendered.getHtmlBody();
            if (body == null) body = rendered.getPlainTextBody();
            if (body != null && body.contains('<body')) { body = body.substringAfter('>'); if (body.contains('</body>')) body = body.substringBeforeLast('</body>'); }
            
            String finalBody = body != null ? body.trim() : '';
            // El reemplazo de etiquetas [[SEDES]], [[CUENTA]], [[CLIENTE]], [[FOLIO]] 
            // se ha diferido a los controladores de PDF para garantizar la carga perezosa (Lazy Loading)
            return finalBody;
        } catch (Exception e) { throw new AuraHandledException('Error render: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static Id saveTechnicalData(Map<String, Object> data) {
        try {
            Map<String, Object> p = data.containsKey('data') ? (Map<String, Object>)data.get('data') : data;
            Id rid = (Id)p.get('quoteId');
            Id contactId = p.containsKey('contactId') && p.get('contactId') != null ? (Id)p.get('contactId') : null;
            
            // Extraer ID de oportunidad de forma robusta
            String oppIdStr = (String)p.get('opportunityId');
            Id oppId = (oppIdStr != null && oppIdStr != '') ? (Id)oppIdStr : null;
            
            String itemsJson = (String)p.get('lineItems');
            String status = (String)p.get('status');
            
            Quote q;
            if (rid != null && rid.getSObjectType().getDescribe().getName() == 'Quote') {
                q = [SELECT Id FROM Quote WHERE Id = :rid LIMIT 1];
                q.Name = (String)p.get('name');
                q.Status = status;
                q.ContactId = contactId;
                q.Introduction_Text__c = (String)p.get('intro');
                q.Warranty_Text__c = (String)p.get('warranty');
                q.Markers_Data__c = (String)p.get('markersData');
                q.Technical_Sedes__c = (String)p.get('technicalSedes');
                q.Description = (String)p.get('observacionesPago');
                update q;
            } else {
                // Fallback: si rid era la Opp, la usamos como oppId
                if (oppId == null && rid != null && rid.getSObjectType().getDescribe().getName() == 'Opportunity') {
                    oppId = rid;
                }
                
                Id pbId;
                if (oppId != null) {
                    List<Opportunity> opps = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1];
                    if (!opps.isEmpty()) pbId = opps[0].Pricebook2Id;
                }
                if (pbId == null) try { pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1].Id; } catch(Exception e) {}
                
                q = new Quote();
                q.Name = (String)p.get('name'); 
                q.OpportunityId = oppId; 
                q.Pricebook2Id = pbId; 
                q.Status = status;
                q.ContactId = contactId;
                q.Introduction_Text__c = (String)p.get('intro'); 
                q.Warranty_Text__c = (String)p.get('warranty');
                q.Markers_Data__c = (String)p.get('markersData'); 
                q.Technical_Sedes__c = (String)p.get('technicalSedes');
                q.Description = (String)p.get('observacionesPago'); 
                q.ExpirationDate = Date.today().addDays(30);
                insert q;
                rid = q.Id;
            }
            try {
                String markersBase64 = (String)p.get('markersData');
                if (String.isNotBlank(markersBase64) && rid != null) processLevantamientos(rid, markersBase64);
            } catch (Exception e) {}
            
            if (String.isNotBlank(itemsJson) && rid != null) {
                List<Object> items = (List<Object>)JSON.deserializeUntyped(itemsJson);
                delete [SELECT Id FROM QuoteLineItem WHERE QuoteId = :rid];
                List<QuoteLineItem> qlis = new List<QuoteLineItem>();
                for (Object obj : items) {
                    Map<String, Object> it = (Map<String, Object>)obj;
                    String pbeIdStr = (String)it.get('pbeId');
                    if (String.isBlank(pbeIdStr) || pbeIdStr == 'null') pbeIdStr = (String)it.get('id');
                    if (String.isBlank(pbeIdStr) || pbeIdStr.length() < 15) continue;
                    try {
                        Decimal can = Decimal.valueOf(String.valueOf(it.get('cantidad') != null ? it.get('cantidad') : 1));
                        Decimal tot = Decimal.valueOf(String.valueOf(it.get('totalSinImpuestos') != null ? it.get('totalSinImpuestos') : 0));
                        String det = (String)it.get('detalleTecnico');
                        QuoteLineItem qli = new QuoteLineItem(
                            QuoteId = rid, 
                            PricebookEntryId = (Id)pbeIdStr, 
                            Quantity = (can > 0 ? can : 1), 
                            UnitPrice = (can > 0 ? (tot/can) : tot),
                            Descripcion_Detallada__c = det, // Toda la información aquí (32k chars)
                            Description = null // Dejamos el estándar limpio para evitar errores
                        );
                        qlis.add(qli);
                    } catch (Exception e) {}
                }
                if (!qlis.isEmpty()) insert qlis;
            }
            
            // Automatizar Sincronización para actualizar Importe de Oportunidad
            if (oppId != null && rid != null) {
                update new Opportunity(Id = oppId, SyncedQuoteId = rid);
            }
            
            return rid;
        } catch (Exception e) { throw new AuraHandledException('Error Apex: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> getFilteredSedes(String searchTerm, Id parentAccountId, Boolean isGlobal) {
        String key = '%' + searchTerm + '%';
        if (isGlobal) return [SELECT Id, Name, BillingStreet, BillingCity, Phone, Parent.Name FROM Account WHERE Name LIKE :key LIMIT 100];
        if (parentAccountId == null) return new List<Account>();
        return [SELECT Id, Name, BillingStreet, BillingCity, Phone FROM Account WHERE ParentId = :parentAccountId AND (Name LIKE :key OR BillingCity LIKE :key) LIMIT 200];
    }

    @AuraEnabled
    public static void saveSurveyData(Id oppId, String type, String surveyDataJson, String diagDataJson) {
        try {
            if (String.isBlank(surveyDataJson) || oppId == null) return;
            List<Object> rows = (List<Object>)JSON.deserializeUntyped(surveyDataJson);
            Map<String, Object> diag = String.isNotBlank(diagDataJson) ? (Map<String, Object>)JSON.deserializeUntyped(diagDataJson) : new Map<String, Object>();
            String typeUpper = type.toUpperCase();
            
            // 1. Obtener registros existentes para manejo inteligente (Upsert)
            Map<Id, Levantamiento_Tecnico__c> existingRecords = new Map<Id, Levantamiento_Tecnico__c>(
                [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId AND Tipo_Servicio__c = :typeUpper]
            );
            
            List<Levantamiento_Tecnico__c> toUpsert = new List<Levantamiento_Tecnico__c>();
            Set<Id> idsToKeep = new Set<Id>();

            for (Object obj : rows) {
                Map<String, Object> row = (Map<String, Object>)obj;
                String rawId = (row.get('id') != null) ? String.valueOf(row.get('id')) : null;
                Id rowId = null;
                
                // VALIDACIÓN ROBUSTA DE ID: Solo si tiene 15 o 18 caracteres y no contiene puntos decimales
                if (String.isNotBlank(rawId) && (rawId.length() == 15 || rawId.length() == 18) && !rawId.contains('.')) {
                    try {
                        rowId = (Id)rawId;
                    } catch (Exception e) { rowId = null; }
                }
                
                Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(
                    Oportunidad__c = oppId,
                    Tipo_Servicio__c = typeUpper,
                    Nivel__c = (String)row.get('nivel'),
                    Area_Cocina_Banos__c = (String)row.get('area'),
                    Zona_Genero__c = (String)row.get('zona'),
                    Observaciones_Tecnicas__c = (String)row.get('obs')
                );
                
                if (rowId != null && existingRecords.containsKey(rowId)) {
                    lev.Id = rowId;
                    idsToKeep.add(rowId);
                }

                // --- MAPEO INTEGRAL POR TIPO ---
                if (typeUpper == 'BIOENZIMÁTICO') {
                    lev.VE__c = row.get('ve') != null ? Decimal.valueOf(String.valueOf(row.get('ve'))) : 0;
                    lev.VP__c = row.get('vp') != null ? Decimal.valueOf(String.valueOf(row.get('vp'))) : 0;
                    lev.Bidon_10L__c = row.get('c10l') != null ? Decimal.valueOf(String.valueOf(row.get('c10l'))) : 0;
                    lev.Bidon_20L__c = row.get('c20l') != null ? Decimal.valueOf(String.valueOf(row.get('c20l'))) : 0;
                    lev.Bidon_25L__c = row.get('c25l') != null ? Decimal.valueOf(String.valueOf(row.get('c25l'))) : 0;
                    lev.Piso__c = row.get('piso') != null ? Decimal.valueOf(String.valueOf(row.get('piso'))) : 0;
                    lev.Mueble__c = row.get('mueble') != null ? Decimal.valueOf(String.valueOf(row.get('mueble'))) : 0;
                    lev.Pared__c = row.get('pared') != null ? Decimal.valueOf(String.valueOf(row.get('pared'))) : 0;
                    lev.Residuos_Tarja__c = (String)row.get('residuos');
                    lev.Escamoche__c = (String)row.get('escamoche');
                    lev.Estado_Instalacion__c = (String)row.get('instala');
                    lev.Azolves__c = (String)row.get('azolves');
                    lev.Coladeras__c = row.get('coladeras') != null ? Decimal.valueOf(String.valueOf(row.get('coladeras'))) : 0;
                    lev.Tapon_Registro__c = row.get('tapon') != null ? Decimal.valueOf(String.valueOf(row.get('tapon'))) : 0;
                    lev.Tarja__c = row.get('tarja') != null ? Decimal.valueOf(String.valueOf(row.get('tarja'))) : 0;
                    lev.Tinas_por_Tarja__c = row.get('tinas') != null ? Decimal.valueOf(String.valueOf(row.get('tinas'))) : 0;
                    lev.Trampa_Grasa__c = row.get('tgrasa') != null ? Decimal.valueOf(String.valueOf(row.get('tgrasa'))) : 0;
                    lev.Modelo_TG_Bio__c = (String)row.get('modelo');
                    lev.ST_1__c = row.get('st1') != null ? Decimal.valueOf(String.valueOf(row.get('st1'))) : 0;
                    lev.Ovalines_Lavabo__c = row.get('ovalines') != null ? Decimal.valueOf(String.valueOf(row.get('ovalines'))) : 0;
                }
                else if (typeUpper == 'GRASAS') {
                    lev.SP__c = row.get('sp') != null ? Decimal.valueOf(String.valueOf(row.get('sp'))) : 0;
                    lev.ENT__c = row.get('ent') != null ? Decimal.valueOf(String.valueOf(row.get('ent'))) : 0;
                    lev.Modelo_Grasas__c = (String)row.get('modelo');
                    lev.Frecuencia_Limpieza__c = (String)row.get('frecuencia');
                    lev.Estado_Trampa__c = (String)row.get('estado');
                    lev.Tornillo__c = row.get('tornillo') != null ? Decimal.valueOf(String.valueOf(row.get('tornillo'))) : 0;
                    lev.Sello__c = row.get('sello') != null ? Decimal.valueOf(String.valueOf(row.get('sello'))) : 0;
                    lev.Mampara__c = row.get('mampara') != null ? Decimal.valueOf(String.valueOf(row.get('mampara'))) : 0;
                    lev.Canastilla__c = row.get('canastilla') != null ? Decimal.valueOf(String.valueOf(row.get('canastilla'))) : 0;
                    lev.Ret_Salida__c = row.get('retSalida') != null ? Decimal.valueOf(String.valueOf(row.get('retSalida'))) : 0;
                }
                else if (typeUpper == 'INTIMA') {
                    lev.WC__c = row.get('wc') != null ? Decimal.valueOf(String.valueOf(row.get('wc'))) : 0;
                    lev.Frecuencia__c = (String)row.get('frecuencia');
                    lev.Dias_Servicio_Censo__c = (String)row.get('dias');
                    // Diagnóstico
                    lev.GM_Usuarias_Internas__c = diag.get('gmUsuariasInt') != null ? Decimal.valueOf(String.valueOf(diag.get('gmUsuariasInt'))) : 0;
                    lev.GM_Usuarias_Externas__c = diag.get('gmUsuariasExt') != null ? Decimal.valueOf(String.valueOf(diag.get('gmUsuariasExt'))) : 0;
                    lev.GM_Frecuencia_Uso__c = (String)diag.get('gmFreqUso');
                    lev.GM_Sanitarios_Totales__c = diag.get('gmSanitarios') != null ? Decimal.valueOf(String.valueOf(diag.get('gmSanitarios'))) : 0;
                    lev.GM_Cubiculos_Totales__c = diag.get('gmCubiculos') != null ? Decimal.valueOf(String.valueOf(diag.get('gmCubiculos'))) : 0;
                    lev.GM_Contenedores_Sugeridos__c = diag.get('gmContSugeridos') != null ? Decimal.valueOf(String.valueOf(diag.get('gmContSugeridos'))) : 0;
                    lev.GM_Frecuencia_Recoleccion__c = (String)diag.get('gmFreqRec');
                    lev.GM_Dias_Servicio__c = (String)diag.get('gmDiasServ');
                    lev.GM_Horario_Servicio__c = (String)diag.get('gmHorario');
                    lev.GM_Permisos_Acceso__c = (String)diag.get('gmPermisos');
                    lev.GM_Consideraciones_Especiales__c = (String)diag.get('gmConsideraciones');
                    lev.GM_Requiere_Capacitacion__c = (String)diag.get('gmCapacitacion');
                    lev.GM_Presupuesto_Asignado__c = (String)diag.get('gmPresupuesto');
                    lev.GM_Motivo_Necesidad__c = (String)diag.get('gmMotivo');
                    lev.GM_Permite_Levantamiento_Foto__c = (String)diag.get('gmPermiteLev');
                }
                else if (typeUpper == 'DESAZOLVE MECANICO') {
                    lev.Ovalines_Lavabo__c = row.get('ovalines') != null ? Decimal.valueOf(String.valueOf(row.get('ovalines'))) : 0;
                    lev.Coladeras__c = row.get('coladeras') != null ? Decimal.valueOf(String.valueOf(row.get('coladeras'))) : 0;
                    lev.Tapon_Registro__c = row.get('tapon') != null ? Decimal.valueOf(String.valueOf(row.get('tapon'))) : 0;
                    lev.Mingitorios__c = row.get('mingitorios') != null ? Decimal.valueOf(String.valueOf(row.get('mingitorios'))) : 0;
                    lev.WC__c = row.get('wc') != null ? Decimal.valueOf(String.valueOf(row.get('wc'))) : 0;
                    lev.Metros_Lineales__c = row.get('mtLineal') != null ? Decimal.valueOf(String.valueOf(row.get('mtLineal'))) : 0;
                    lev.Tarjas_Servicios__c = row.get('tarjas') != null ? Decimal.valueOf(String.valueOf(row.get('tarjas'))) : 0;
                    lev.Cuarto_Humado__c = row.get('cuartoHumado') != null ? Decimal.valueOf(String.valueOf(row.get('cuartoHumado'))) : 0;
                }
                else if (typeUpper == 'AROMATIZANTES') {
                    lev.Equipos_ARM__c = row.get('arm') != null ? Decimal.valueOf(String.valueOf(row.get('arm'))) : 0;
                }
                else if (typeUpper == 'VACTOR') {
                    lev.Vactor_Descripcion__c = (String)row.get('descripcion');
                    lev.Vactor_Medida__c = (String)row.get('medida');
                    lev.Vactor_Material__c = (String)row.get('material');
                    lev.Vactor_Servicio_Requerido__c = (String)row.get('servicio');
                    lev.Vactor_Largo__c = row.get('largo') != null ? Decimal.valueOf(String.valueOf(row.get('largo'))) : 0;
                    lev.Vactor_Ancho__c = row.get('ancho') != null ? Decimal.valueOf(String.valueOf(row.get('ancho'))) : 0;
                    lev.Vactor_Profundidad__c = row.get('prof') != null ? Decimal.valueOf(String.valueOf(row.get('prof'))) : 0;
                    lev.Metros_Lineales__c = row.get('mtLineal') != null ? Decimal.valueOf(String.valueOf(row.get('mtLineal'))) : 0;
                    lev.Vactor_Distancia_Camion__c = (String)row.get('distancia');
                    lev.Vactor_Permiso_Delegacion__c = (String)row.get('permDelegacion');
                    lev.Vactor_Permiso_Plaza__c = (String)row.get('permPlaza');
                    lev.Vactor_Dificultad__c = (String)row.get('dificultad');
                    lev.Vactor_Alcance_Pyatz__c = (String)row.get('alcance');
                }
                
                toUpsert.add(lev);
            }
            
            // 2. Ejecutar Upsert
            if (!toUpsert.isEmpty()) upsert toUpsert;
            
            // 3. Borrar registros que ya no vienen en el JSON (Eliminados por el usuario)
            List<Levantamiento_Tecnico__c> toDelete = new List<Levantamiento_Tecnico__c>();
            for (Id existingId : existingRecords.keySet()) {
                if (!idsToKeep.contains(existingId)) toDelete.add(new Levantamiento_Tecnico__c(Id = existingId));
            }
            if (!toDelete.isEmpty()) delete toDelete;

        } catch (Exception e) { throw new AuraHandledException('Error levantamiento integral: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static List<Map<String, Object>> getOpportunitySolutions(Id oppId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            for (Levantamiento_Tecnico__c l : [SELECT Id, Name, Tipo_Servicio__c, Area_Cocina_Banos__c, Nivel__c, (SELECT Id, Name, Descripcion_Detallada__c, Observaciones_Comerciales__c FROM Soluciones_Tecnicas__r ORDER BY CreatedDate ASC) FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY Tipo_Servicio__c, CreatedDate ASC]) {
                if (l.Soluciones_Tecnicas__r.isEmpty()) continue;
                Map<String, Object> levMap = new Map<String, Object>{'id' => l.Id, 'name' => l.Name, 'label' => l.Tipo_Servicio__c + ' - ' + (l.Area_Cocina_Banos__c != null ? l.Area_Cocina_Banos__c : l.Nivel__c)};
                List<Map<String, Object>> solList = new List<Map<String, Object>>();
                for (Solucion_Tecnica__c s : l.Soluciones_Tecnicas__r) solList.add(new Map<String, Object>{'id' => s.Id, 'name' => s.Name, 'techDesc' => s.Descripcion_Detallada__c, 'commObs' => s.Observaciones_Comerciales__c});
                levMap.put('solutions', solList); result.add(levMap);
            }
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
        return result;
    }

    @AuraEnabled
    public static List<Solucion_Tecnica__c> getSoluciones(Id levantamientoId) {
        return [SELECT Id, Name, Descripcion_Detallada__c FROM Solucion_Tecnica__c WHERE Levantamiento_Tecnico__c = :levantamientoId ORDER BY CreatedDate ASC];
    }

    @AuraEnabled
    public static Id saveSolucion(Id levantamientoId, Id solucionId, String nombre, String descripcion, String observaciones) {
        try {
            Solucion_Tecnica__c sol = new Solucion_Tecnica__c(Id = solucionId, Levantamiento_Tecnico__c = (solucionId == null ? levantamientoId : null), Name = nombre, Descripcion_Detallada__c = descripcion, Observaciones_Comerciales__c = observaciones);
            upsert sol; return sol.Id;
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void deleteSolucion(Id solucionId) {
        try { delete [SELECT Id FROM Solucion_Tecnica__c WHERE Id = :solucionId]; } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void saveMemoria(Id recordId, String text) {
        try {
            if (recordId == null) return;
            String sType = recordId.getSObjectType().getDescribe().getName();
            if (sType == 'Quote') update new Quote(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Opportunity') update new Opportunity(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Levantamiento_Tecnico__c') update new Levantamiento_Tecnico__c(Id = recordId, Memoria_Descriptiva__c = text);
        } catch (Exception e) { throw new AuraHandledException('Error memoria: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static List<Levantamiento_Tecnico__c> getLevantamientoDetails(Id recordId) {
        try {
            Id oppId = recordId;
            if (recordId != null && recordId.getSObjectType().getDescribe().getName() == 'Quote') oppId = [SELECT OpportunityId FROM Quote WHERE Id = :recordId].OpportunityId;
            return [SELECT Id, Name, Tipo_Servicio__c, Nivel__c, Area_Cocina_Banos__c, Zona_Genero__c, Cantidad_Principal__c, Estado_Instalacion__c, Frecuencia__c, Metros_Lineales__c, Observaciones_Tecnicas__c, Memoria_Descriptiva__c, CreatedDate,
                    VE__c, VP__c, Bidon_10L__c, Bidon_20L__c, Bidon_25L__c, Piso__c, Mueble__c, Pared__c, Fotografia__c, Residuos_Tarja__c, Escamoche__c, Instalaciones__c, Azolves__c, Coladeras__c, Tapon_Registro__c, Tarja__c, Tinas_por_Tarja__c, Trampa_Grasa__c, Modelo_TG_Bio__c, ST_1__c, Ovalines_Lavabo__c,
                    SP__c, ENT__c, Modelo_Grasas__c, Frecuencia_Limpieza__c, Estado_Trampa__c, Tornillo__c, Sello__c, Mampara__c, Canastilla__c, Ret_Salida__c,
                    GM_Usuarias_Internas__c, GM_Usuarias_Externas__c, GM_Frecuencia_Uso__c, GM_Sanitarios_Totales__c, GM_Cubiculos_Totales__c, GM_Contenedores_Sugeridos__c, GM_Frecuencia_Recoleccion__c, GM_Dias_Servicio__c, GM_Horario_Servicio__c, GM_Permisos_Acceso__c, GM_Consideraciones_Especiales__c, GM_Requiere_Capacitacion__c, GM_Presupuesto_Asignado__c, GM_Motivo_Necesidad__c, GM_Permite_Levantamiento_Foto__c,
                    WC__c, Dias_Servicio_Censo__c, Mingitorios__c, Tarjas_Servicios__c, Cuarto_Humado__c, Equipos_ARM__c,
                    Vactor_Descripcion__c, Vactor_Medida__c, Vactor_Material__c, Vactor_Servicio_Requerido__c, Vactor_Largo__c, Vactor_Ancho__c, Vactor_Profundidad__c, Vactor_Distancia_Camion__c, Vactor_Permiso_Delegacion__c, Vactor_Permiso_Plaza__c, Vactor_Dificultad__c, Vactor_Alcance_Pyatz__c,
                    (SELECT Id FROM Soluciones_Tecnicas__r LIMIT 1) 
                    FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY Tipo_Servicio__c, CreatedDate ASC];
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    private static void processLevantamientos(Id quoteId, String markersBase64) {
        try {
            Id oppId = [SELECT OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1].OpportunityId;
            String jsonStr = EncodingUtil.urlDecode(EncodingUtil.base64Decode(markersBase64).toString(), 'UTF-8');
            Map<String, Object> markers = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
            if (!markers.containsKey('surveyData')) return;
            List<Object> rows = (List<Object>)markers.get('surveyData');
            String type = markers.containsKey('surveyType') ? (String)markers.get('surveyType') : '';
            delete [SELECT Id FROM Levantamiento_Tecnico__c WHERE Presupuesto__c = :quoteId];
            List<Levantamiento_Tecnico__c> records = new List<Levantamiento_Tecnico__c>();
            for (Object obj : rows) {
                Map<String, Object> r = (Map<String, Object>)obj;
                Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(Presupuesto__c = quoteId, Oportunidad__c = oppId, Tipo_Servicio__c = type.toUpperCase(), Nivel__c = (String)r.get('nivel'), Area_Cocina_Banos__c = (String)r.get('area'), Zona_Genero__c = (String)r.get('zona'), Observaciones_Tecnicas__c = (String)r.get('obs'));
                if (type.equalsIgnoreCase('Bioenzimatico')) { lev.Cantidad_Principal__c = (r.get('ve') != null) ? Decimal.valueOf(String.valueOf(r.get('ve'))) : 0; lev.Estado_Instalacion__c = (String)r.get('instala'); }
                else if (type.equalsIgnoreCase('Grasas')) { lev.Estado_Instalacion__c = (String)r.get('estado'); lev.Frecuencia__c = (String)r.get('frecuencia'); }
                else if (type.equalsIgnoreCase('Intima')) { lev.Cantidad_Principal__c = (r.get('wc') != null) ? Decimal.valueOf(String.valueOf(r.get('wc'))) : 0; }
                records.add(lev);
            }
            if (!records.isEmpty()) insert records;
        } catch (Exception e) {}
    }

    @AuraEnabled
    public static Boolean validatePLPassword(String password) {
        return password == System.Label.PL_Access_Password;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchParentAccounts(String searchTerm) {
        String key = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE :key AND ParentId = null LIMIT 10]) {
            results.add(new Map<String, String>{'id' => a.Id, 'name' => a.Name});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSedeContacts(Id sedeId) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        try {
            if (sedeId == null) return results;
            for (Contact c : [SELECT Id, Name, Title FROM Contact WHERE AccountId = :sedeId AND IsEmailBounced = false ORDER BY Name ASC LIMIT 50]) {
                results.add(new Map<String, String>{
                    'label' => c.Name,
                    'value' => c.Id,
                    'name' => c.Name,
                    'title' => c.Title != null ? c.Title : ''
                });
            }
        } catch (Exception e) {}
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchSedes(String searchTerm) {
        String key = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE :key AND ParentId != null LIMIT 10]) {
            results.add(new Map<String, String>{'id' => a.Id, 'name' => a.Name});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchProspectos(String searchTerm) {
        String key = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Lead l : [SELECT Id, Name, Company FROM Lead WHERE (Name LIKE :key OR Company LIKE :key) AND IsConverted = false LIMIT 10]) {
            results.add(new Map<String, String>{'id' => l.Id, 'name' => l.Name + ' (' + l.Company + ')'});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEmailEngagementDetails(Id oppId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (EmailMessage em : [SELECT Id, Subject, ToAddress, CcAddress, Status, MessageDate, IsOpened, FirstOpenedDate, LastOpenedDate,
                               (SELECT RelationId, RelationAddress, RelationType FROM EmailMessageRelations WHERE RelationType IN ('ToAddress', 'CcAddress'))
                               FROM EmailMessage WHERE RelatedToId = :oppId ORDER BY MessageDate DESC LIMIT 50]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', em.Id);
            row.put('subject', em.Subject);
            row.put('sentDate', em.MessageDate);
            row.put('isOpened', em.IsOpened);
            row.put('firstOpen', em.FirstOpenedDate);
            row.put('lastOpen', em.LastOpenedDate);
            
            List<Map<String, String>> recipients = new List<Map<String, String>>();
            for (EmailMessageRelation rel : em.EmailMessageRelations) {
                recipients.add(new Map<String, String>{
                    'name' => rel.RelationAddress, // Usamos la dirección como nombre si el Relation.Name no es accesible directamente
                    'email' => rel.RelationAddress,
                    'type' => rel.RelationType == 'ToAddress' ? 'Principal' : 'En Copia'
                });
            }
            row.put('recipients', recipients);
            
            String statusLabel = 'Enviado';
            String statusClass = 'slds-theme_shade';
            if (em.IsOpened) {
                statusLabel = 'Leído';
                statusClass = 'slds-theme_success';
            }
            row.put('statusLabel', statusLabel);
            row.put('statusClass', statusClass);
            
            results.add(row);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolders(List<String> folderNames) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (EmailTemplate et : [SELECT Id, Name, Folder.Name FROM EmailTemplate WHERE Folder.Name IN :folderNames AND IsActive = true ORDER BY Folder.Name, Name ASC]) {
            results.add(new Map<String, String>{'id' => et.Id, 'name' => et.Name, 'folder' => et.Folder.Name});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getAvailableAttachments(Id oppId) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        
        // 1. Presupuestos (Quotes)
        List<Map<String, String>> quotes = new List<Map<String, String>>();
        for (Quote q : [SELECT Id, Name, QuoteNumber FROM Quote WHERE OpportunityId = :oppId ORDER BY CreatedDate DESC]) {
            quotes.add(new Map<String, String>{'id' => q.Id, 'name' => 'Presupuesto: ' + q.QuoteNumber + ' - ' + q.Name, 'type' => 'Quote'});
        }
        result.put('quotes', quotes);

        // 2. Levantamientos Técnicos (Agrupados por Oportunidad)
        List<Map<String, String>> surveys = new List<Map<String, String>>();
        for (AggregateResult ar : [SELECT Tipo_Servicio__c FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId GROUP BY Tipo_Servicio__c]) {
            String tipo = (String)ar.get('Tipo_Servicio__c');
            surveys.add(new Map<String, String>{'id' => oppId, 'name' => 'Levantamiento: ' + tipo, 'type' => 'Survey', 'subType' => tipo});
        }
        result.put('surveys', surveys);

        // 3. Archivos cargados (Files)
        List<Map<String, String>> files = new List<Map<String, String>>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension FROM ContentDocumentLink WHERE LinkedEntityId = :oppId AND ContentDocument.FileExtension = 'pdf']) {
            files.add(new Map<String, String>{'id' => cdl.ContentDocumentId, 'name' => 'Archivo: ' + cdl.ContentDocument.Title, 'type' => 'File'});
        }
        result.put('files', files);

        return result;
    }

    /**
     * PENDIENTE DE IMPLEMENTAR (Solicitud Usuario):
     * 1. Selector de Remitente Dinámico (User vs Org-Wide Address).
     * 2. Rastreo de Respuestas vía BCC (Email-to-Salesforce) para visibilidad en Timeline.
     */
    @AuraEnabled
    public static void sendEmailWithAttachments(Id oppId, String toEmail, String ccEmail, String subject, String body, List<Map<String, String>> selectedAttachments) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{toEmail});
            if (String.isNotBlank(ccEmail)) mail.setCcAddresses(ccEmail.split(','));
            mail.setSubject(subject);
            mail.setHtmlBody(body);
            mail.setWhatId(oppId);
            mail.setSaveAsActivity(true);

            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();

            for (Map<String, String> att : selectedAttachments) {
                String type = att.get('type');
                Id attId = (Id)att.get('id');
                
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                
                if (type == 'Quote') {
                    PageReference pr = Page.QuoteTechnicalPDF;
                    pr.getParameters().put('id', attId);
                    efa.setFileName(att.get('name') + '.pdf');
                    efa.setBody(!Test.isRunningTest() ? pr.getContentAsPDF() : Blob.valueOf('Test Content'));
                    attachments.add(efa);
                } else if (type == 'Survey') {
                    // Similar a Quote pero con parámetros para el levantamiento
                    PageReference pr = Page.QuoteTechnicalPDF;
                    pr.getParameters().put('id', oppId);
                    pr.getParameters().put('surveyOnly', 'true');
                    efa.setFileName(att.get('name') + '.pdf');
                    efa.setBody(!Test.isRunningTest() ? pr.getContentAsPDF() : Blob.valueOf('Test Content'));
                    attachments.add(efa);
                } else if (type == 'File') {
                    ContentVersion cv = [SELECT VersionData, Title, FileExtension FROM ContentVersion WHERE ContentDocumentId = :attId AND IsLatest = true LIMIT 1];
                    efa.setFileName(cv.Title + '.' + cv.FileExtension);
                    efa.setBody(cv.VersionData);
                    attachments.add(efa);
                }
            }
            
            mail.setFileAttachments(attachments);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch (Exception e) { throw new AuraHandledException('Error envío: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getDocumentStates(Id opportunityId) {
        Map<String, String> states = new Map<String, String>();
        if (opportunityId == null) return states;

        // 1. Obtener AccountId del cliente
        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        Id clientAccountId = opp.AccountId;

        // 2. Obtener AccountId del Repositorio Maestro de Pyatz
        Id pyatzMasterId = null;
        List<Account> pyatzAccs = [SELECT Id FROM Account WHERE Name = 'Pyatz Corporativo' LIMIT 1];
        if (!pyatzAccs.isEmpty()) pyatzMasterId = pyatzAccs[0].Id;

        // 3. Buscar en todas las entidades relevantes (Oportunidad, Cliente y Pyatz)
        Set<Id> entities = new Set<Id>{opportunityId};
        if (clientAccountId != null) entities.add(clientAccountId);
        if (pyatzMasterId != null) entities.add(pyatzMasterId);

        List<ContentDocumentLink> links = [SELECT ContentDocumentId, ContentDocument.Title 
                                           FROM ContentDocumentLink 
                                           WHERE LinkedEntityId IN :entities];
        
        // 4. LÓGICA DINÁMICA: Detectar cualquier etiqueta entre corchetes [TAG]
        for (ContentDocumentLink l : links) {
            String title = l.ContentDocument.Title;
            if (title.startsWith('[') && title.contains(']')) {
                String tag = title.substringBetween('[', ']').toUpperCase();
                // Si hay varios archivos con el mismo TAG, nos quedamos con el más reciente
                if (!states.containsKey(tag)) {
                    states.put(tag, l.ContentDocumentId);
                }
            }
        }
        return states;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEvidenceGallery(Id opportunityId) {
        List<Map<String, Object>> gallery = new List<Map<String, Object>>();
        try {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :opportunityId]) {
                docIds.add(cdl.ContentDocumentId);
            }

            if (!docIds.isEmpty()) {
                for (ContentVersion cv : [SELECT Id, Title, FileExtension, ContentDocumentId, CreatedDate FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true ORDER BY CreatedDate DESC]) {
                    String title = cv.Title;
                    // Detectar si tiene etiqueta [TAG]
                    if (title.startsWith('[') && title.contains(']')) {
                        String tag = title.substringBetween('[', ']');
                        String cleanTitle = title.substringAfter(']').replace('-', '').trim();
                        String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
                        Boolean isImg = new Set<String>{'png', 'jpg', 'jpeg', 'gif'}.contains(ext);

                        gallery.add(new Map<String, Object>{
                            'id' => cv.ContentDocumentId,
                            'versionId' => cv.Id,
                            'tag' => tag.toUpperCase(),
                            'title' => cleanTitle,
                            'ext' => ext,
                            'isImage' => isImg,
                            'previewUrl' => isImg ? '/sfc/servlet.shepherd/version/download/' + cv.Id : null,
                            'date' => cv.CreatedDate
                        });
                    }
                }
            }
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
        return gallery;
    }

    @AuraEnabled
    public static void renameUploadedFile(Id documentId, String docType) {
        try {
            // 1. Identificar el archivo con su etiqueta
            ContentDocument doc = [SELECT Id, Title FROM ContentDocument WHERE Id = :documentId LIMIT 1];
            doc.Title = '[' + docType.toUpperCase() + '] - ' + doc.Title;
            update doc;

            // 2. Lógica de Vinculación Inteligente
            if (docType.toUpperCase().startsWith('PY_')) {
                // Documento Maestro de Pyatz -> Vincular a Repositorio Global
                Id pyatzId = getOrCreatePyatzMasterAccount();
                linkDocumentToEntity(documentId, pyatzId);
            } else {
                // Documento de Cliente o Proyecto -> Vincular a Cuenta del Cliente
                Id oppId = getOppIdFromDocument(documentId);
                if (oppId != null) {
                    Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
                    if (opp.AccountId != null) {
                        linkDocumentToEntity(documentId, opp.AccountId);
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al procesar archivo maestro: ' + e.getMessage());
        }
    }

    private static Id getOrCreatePyatzMasterAccount() {
        List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Pyatz Corporativo' LIMIT 1];
        if (!accs.isEmpty()) return accs[0].Id;
        
        Account pyatz = new Account(
            Name = 'Pyatz Corporativo', 
            Type = 'Other', 
            Description = 'Repositorio Maestro de Documentos Legales de Pyatz'
        );
        insert pyatz;
        return pyatz.Id;
    }

    private static Id getOppIdFromDocument(Id docId) {
        List<ContentDocumentLink> currentLinks = [SELECT LinkedEntityId FROM ContentDocumentLink 
                                                 WHERE ContentDocumentId = :docId];
        for (ContentDocumentLink cdl : currentLinks) {
            if (cdl.LinkedEntityId.getSObjectType().getDescribe().getName() == 'Opportunity') {
                return cdl.LinkedEntityId;
            }
        }
        return null;
    }

    private static void linkDocumentToEntity(Id docId, Id entityId) {
        List<ContentDocumentLink> existing = [SELECT Id FROM ContentDocumentLink 
                                              WHERE ContentDocumentId = :docId AND LinkedEntityId = :entityId];
        if (existing.isEmpty()) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = docId;
            cdl.LinkedEntityId = entityId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCalendarData(Id recordId, String startDate, String endDate) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            Date startDt = Date.valueOf(startDate);
            Date endDt = Date.valueOf(endDate);

            // 1. Obtener Recursos de Servicio activos
            List<ServiceResource> resList = [SELECT Id, Name, ResourceType, RelatedRecord.SmallPhotoUrl FROM ServiceResource WHERE IsActive = true LIMIT 50];
            result.put('resources', resList);
            
            // 2. Obtener TODAS las Citas de Servicio en el rango (Asignadas y No Asignadas)
            List<ServiceAppointment> allApps = [
                SELECT Id, Subject, SchedStartTime, SchedEndTime, Status, Duration, AppointmentNumber, Account.Name,
                       (SELECT ServiceResourceId FROM ServiceResources)
                FROM ServiceAppointment 
                WHERE SchedStartTime >= :startDt AND SchedStartTime <= :endDt
                ORDER BY SchedStartTime ASC
            ];

            List<Map<String, Object>> appList = new List<Map<String, Object>>();
            for (ServiceAppointment sa : allApps) {
                Map<String, Object> app = new Map<String, Object>();
                app.put('Id', sa.Id);
                app.put('Folio', sa.AppointmentNumber);
                app.put('Subject', sa.Subject);
                app.put('AccountName', sa.Account.Name != null ? sa.Account.Name : 'Sin Cliente');
                app.put('SchedStartTime', sa.SchedStartTime);
                app.put('SchedEndTime', sa.SchedEndTime);
                app.put('Status', sa.Status);
                app.put('Duration', sa.Duration != null ? sa.Duration : 0);
                
                if (!sa.ServiceResources.isEmpty()) {
                    app.put('ServiceResourceId', sa.ServiceResources[0].ServiceResourceId);
                } else {
                    app.put('ServiceResourceId', 'UNASSIGNED');
                }
                appList.add(app);
            }
            
            result.put('appointments', appList);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static void deleteDocument(Id documentId) {
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
        } catch (Exception e) {
            throw new AuraHandledException('Error al eliminar: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getHistoricalPL(Id quoteId) {
        Map<String, Decimal> history = new Map<String, Decimal>{ 'current' => 0, 'previous' => 0 };
        try {
            Quote q = [SELECT AccountId FROM Quote WHERE Id = :quoteId LIMIT 1];
            Id accId = q.AccountId;
            Integer currentYear = Date.today().year();
            
            // Año Actual (Facturación Ganada)
            AggregateResult curr = [SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = :accId AND IsWon = true AND CALENDAR_YEAR(CloseDate) = :currentYear];
            history.put('current', (Decimal)curr.get('total') != null ? (Decimal)curr.get('total') : 0);
            
            // Año Anterior
            AggregateResult prev = [SELECT SUM(Amount) total FROM Opportunity WHERE AccountId = :accId AND IsWon = true AND CALENDAR_YEAR(CloseDate) = :(currentYear - 1)];
            history.put('previous', (Decimal)prev.get('total') != null ? (Decimal)prev.get('total') : 0);
        } catch (Exception e) {}
        return history;
    }

    @AuraEnabled
    public static Id cloneQuote(Id quoteId, Map<String, Object> options, Id targetSedeId, Id targetProspectoId) {
        try {
            Quote source = [SELECT Name, OpportunityId, Pricebook2Id, ExpirationDate, Introduction_Text__c, Warranty_Text__c, Markers_Data__c, Business_Lines_Selected__c, Technical_Sedes__c, Show_Introduction__c, Show_Warranty__c, Description FROM Quote WHERE Id = :quoteId];
            Quote target = source.clone(false, true, false, false);
            target.Name = 'CLON - ' + source.Name;
            target.Status = 'Draft';
            insert target;
            
            Boolean copyItems = options != null && options.containsKey('copyLineItems') ? (Boolean)options.get('copyLineItems') : true;
            if (copyItems) {
                List<QuoteLineItem> qlis = [SELECT PricebookEntryId, Quantity, UnitPrice, Description, Discount, ServiceDate FROM QuoteLineItem WHERE QuoteId = :quoteId];
                if (!qlis.isEmpty()) {
                    List<QuoteLineItem> newQlis = new List<QuoteLineItem>();
                    for (QuoteLineItem qli : qlis) {
                        QuoteLineItem newQli = qli.clone(false, true, false, false);
                        newQli.QuoteId = target.Id;
                        newQlis.add(newQli);
                    }
                    insert newQlis;
                }
            }
            return target.Id;
        } catch (Exception e) { throw new AuraHandledException('Error clonación: ' + e.getMessage()); }
    }
}