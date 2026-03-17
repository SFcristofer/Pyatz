public with sharing class QuoteTechnicalController {
    
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
        
        // 2. Tareas y Llamadas (Solo de la Oportunidad para no saturar)
        for (Task t : [SELECT Id, Subject, Status, Description, TaskSubtype, CreatedDate FROM Task WHERE WhatId = :oppId ORDER BY CreatedDate DESC LIMIT 20]) {
            String icon = t.TaskSubtype == 'Call' ? 'standard:log_a_call' : 'standard:task';
            String color = t.TaskSubtype == 'Call' ? 'background: #e1f5fe;' : 'background: #fff3e0;';
            history.add(new Map<String, Object>{ 'id' => t.Id, 'type' => 'Actividad', 'label' => t.TaskSubtype == 'Call' ? 'Llamada' : 'Tarea', 'subject' => t.Subject, 'date' => t.CreatedDate, 'icon' => icon, 'color' => color, 'desc' => t.Description });
        }

        // 3. Correos
        for (EmailMessage em : [SELECT Id, Subject, MessageDate, IsOpened, ToAddress FROM EmailMessage WHERE RelatedToId = :oppId ORDER BY MessageDate DESC LIMIT 20]) {
            history.add(new Map<String, Object>{ 'id' => em.Id, 'type' => 'Email', 'label' => 'Correo', 'subject' => em.Subject, 'date' => em.MessageDate, 'icon' => 'standard:email', 'color' => 'background: #e8f5e9;', 'desc' => 'Para: ' + em.ToAddress + (em.IsOpened ? ' (Abierto)' : ' (No leído)') });
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
    public static List<Map<String, Object>> getQuotesList() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(Quote q : [SELECT Id, QuoteNumber, Name, Account.Name, Status, GrandTotal, CreatedDate, CreatedBy.Name 
                       FROM Quote ORDER BY CreatedDate DESC LIMIT 50]) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', q.Id);
            row.put('folio', q.QuoteNumber);
            row.put('asunto', q.Name);
            row.put('cliente', q.Account.Name);
            row.put('generadoPor', q.CreatedBy.Name);
            row.put('fecha', q.CreatedDate);
            row.put('monto', q.GrandTotal);
            row.put('estado', q.Status);
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
                           Technical_Sedes__c, Show_Introduction__c, Show_Warranty__c, CreatedBy.Name, CreatedDate
                           FROM Quote WHERE Id = :recordId];
                accountId = q.AccountId;
                result.put('quote', q);
                result.put('agenteNombre', q.CreatedBy.Name);
            } else if(sType == 'Opportunity') {
                Opportunity opp = [SELECT Id, Name, AccountId, Account.Name, Pricebook2Id FROM Opportunity WHERE Id = :recordId];
                accountId = opp.AccountId;
                result.put('opportunity', opp);
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
        String soql = 'SELECT Id, Product2Id, Product2.Name, Product2.Description, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pbId AND (Product2.Name LIKE :query OR Product2.ProductCode LIKE :query) AND IsActive = true ';
        if (!allowOtherLines && businessLines != null && !businessLines.isEmpty()) soql += 'AND Product2.Family IN :businessLines ';
        for (PricebookEntry pbe : Database.query(soql + ' LIMIT 15')) {
            results.add(new Map<String, Object>{ 'id' => pbe.Id, 'productId' => pbe.Product2Id, 'name' => pbe.Product2.Name, 'description' => pbe.Product2.Description, 'unitPrice' => pbe.UnitPrice });
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
            if (q.Account != null && q.Account.Name != null) {
                finalBody = finalBody.replace('[[CUENTA]]', q.Account.Name).replace('[[CLIENTE]]', q.Account.Name);
            }
            finalBody = finalBody.replace('[[SEDES]]', q.Technical_Sedes__c != null ? q.Technical_Sedes__c : '');
            finalBody = finalBody.replace('[[FOLIO]]', q.QuoteNumber);
            return finalBody;
        } catch (Exception e) { throw new AuraHandledException('Error render: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static Id saveTechnicalData(Map<String, Object> data) {
        try {
            Map<String, Object> p = data.containsKey('data') ? (Map<String, Object>)data.get('data') : data;
            Id rid = (Id)p.get('quoteId');
            String itemsJson = (String)p.get('lineItems');
            String status = (String)p.get('status');
            
            Quote q;
            if (rid != null && rid.getSObjectType().getDescribe().getName() == 'Quote') {
                q = [SELECT Id FROM Quote WHERE Id = :rid LIMIT 1];
                q.Name = (String)p.get('name');
                q.Status = status;
                q.Introduction_Text__c = (String)p.get('intro');
                q.Warranty_Text__c = (String)p.get('warranty');
                q.Markers_Data__c = (String)p.get('markersData');
                q.Technical_Sedes__c = (String)p.get('technicalSedes');
                q.Description = (String)p.get('observacionesPago');
                q.Show_Introduction__c = true; q.Show_Warranty__c = true;
                update q;
            } else {
                Id oppId = (rid != null && rid.getSObjectType().getDescribe().getName() == 'Opportunity') ? rid : null;
                Id pbId;
                if (oppId != null) pbId = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1].Pricebook2Id;
                if (pbId == null) try { pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1].Id; } catch(Exception e) {}
                q = new Quote();
                q.Name = (String)p.get('name'); q.OpportunityId = oppId; q.Pricebook2Id = pbId; q.Status = status;
                q.Introduction_Text__c = (String)p.get('intro'); q.Warranty_Text__c = (String)p.get('warranty');
                q.Markers_Data__c = (String)p.get('markersData'); q.Technical_Sedes__c = (String)p.get('technicalSedes');
                q.Description = (String)p.get('observacionesPago'); q.Show_Introduction__c = true; q.Show_Warranty__c = true;
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
            delete [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId AND Tipo_Servicio__c = :typeUpper];
            List<Levantamiento_Tecnico__c> toInsert = new List<Levantamiento_Tecnico__c>();
            for (Object obj : rows) {
                Map<String, Object> row = (Map<String, Object>)obj;
                Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(Oportunidad__c = oppId, Tipo_Servicio__c = typeUpper, Nivel__c = (String)row.get('nivel'), Area_Cocina_Banos__c = (String)row.get('area'), Zona_Genero__c = (String)row.get('zona'), Observaciones_Tecnicas__c = (String)row.get('obs'));
                if (typeUpper == 'INTIMA') {
                    lev.GM_Usuarias_Internas__c = diag.get('gmUsuariasInt') != null ? Decimal.valueOf(String.valueOf(diag.get('gmUsuariasInt'))) : 0;
                    lev.GM_Sanitarios_Totales__c = diag.get('gmSanitarios') != null ? Decimal.valueOf(String.valueOf(diag.get('gmSanitarios'))) : 0;
                    lev.GM_Frecuencia_Uso__c = (String)diag.get('gmFreqUso');
                }
                if (typeUpper == 'BIOENZIMÁTICO') { lev.Cantidad_Principal__c = (row.get('ve') != null) ? Decimal.valueOf(String.valueOf(row.get('ve'))) : 0; lev.Estado_Instalacion__c = (String)row.get('instala'); }
                else if (typeUpper == 'GRASAS') { lev.Estado_Instalacion__c = (String)row.get('estado'); lev.Frecuencia__c = (String)row.get('frecuencia'); }
                else if (typeUpper == 'INTIMA') { lev.Cantidad_Principal__c = (row.get('wc') != null) ? Decimal.valueOf(String.valueOf(row.get('wc'))) : 0; }
                else if (typeUpper == 'VACTOR') { lev.Metros_Lineales__c = (row.get('mtLineal') != null) ? Decimal.valueOf(String.valueOf(row.get('mtLineal'))) : 0; }
                else if (typeUpper == 'DESAZOLVE MECANICO') { lev.Cantidad_Principal__c = (row.get('wc') != null) ? Decimal.valueOf(String.valueOf(row.get('wc'))) : 0; }
                toInsert.add(lev);
            }
            if (!toInsert.isEmpty()) insert toInsert;
        } catch (Exception e) { throw new AuraHandledException('Error levantamiento: ' + e.getMessage()); }
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

        List<ContentDocumentLink> links = [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId = :opportunityId];
        
        String[] docKeys = new String[]{'INE', 'CURP', 'CSF', 'IMSS', 'VIGENCIA', 'DC3_ALTURAS', 'DC3_CONFINADOS', 'DC3_QUIMICOS', 'DC3_EXT1', 'DC3_EXT2'};
        
        for (String key : docKeys) {
            String foundId = null;
            for (ContentDocumentLink l : links) {
                if (l.ContentDocument.Title.toUpperCase().startsWith('[' + key + ']')) {
                    foundId = l.ContentDocumentId;
                    break;
                }
            }
            states.put(key, foundId);
        }
        return states;
    }

    @AuraEnabled
    public static void renameUploadedFile(Id documentId, String docType) {
        try {
            ContentDocument doc = [SELECT Id, Title FROM ContentDocument WHERE Id = :documentId LIMIT 1];
            doc.Title = '[' + docType.toUpperCase() + '] - ' + doc.Title;
            update doc;
        } catch (Exception e) {
            throw new AuraHandledException('Error al renombrar: ' + e.getMessage());
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