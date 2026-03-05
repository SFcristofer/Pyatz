public with sharing class QuoteTechnicalController {
    
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
            // ESCENARIO A: ACTUALIZACIÓN
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
            } 
            // ESCENARIO B: CREACIÓN
            else {
                Id oppId = (rid != null && rid.getSObjectType().getDescribe().getName() == 'Opportunity') ? rid : null;
                Id pbId;
                
                if (oppId != null) {
                    Opportunity opp = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1];
                    pbId = opp.Pricebook2Id;
                }
                
                if (pbId == null) {
                    try { pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1].Id; } catch(Exception e) {}
                }
                
                q = new Quote();
                q.Name = (String)p.get('name');
                q.OpportunityId = oppId;
                q.Pricebook2Id = pbId;
                q.Status = status;
                q.Introduction_Text__c = (String)p.get('intro');
                q.Warranty_Text__c = (String)p.get('warranty');
                q.Markers_Data__c = (String)p.get('markersData');
                q.Technical_Sedes__c = (String)p.get('technicalSedes');
                q.Description = (String)p.get('observacionesPago');
                q.Show_Introduction__c = true;
                q.Show_Warranty__c = true;
                q.ExpirationDate = Date.today().addDays(30);
                insert q;
                rid = q.Id;
            }
            
            // PROCESAMIENTO DE PARTIDAS
            if (String.isNotBlank(itemsJson) && rid != null) {
                List<Object> items = (List<Object>)JSON.deserializeUntyped(itemsJson);
                delete [SELECT Id FROM QuoteLineItem WHERE QuoteId = :rid];
                List<QuoteLineItem> qlis = new List<QuoteLineItem>();
                for (Object obj : items) {
                    Map<String, Object> it = (Map<String, Object>)obj;
                    if (it.get('isSeparator') == true) continue;
                    
                    // Priorizar pbeId enviado desde el frontend moderno
                    String pbeIdStr = (String)it.get('pbeId');
                    if (String.isBlank(pbeIdStr) || pbeIdStr == 'null') {
                        // Fallback al campo id si pbeId no existe (compatibilidad)
                        pbeIdStr = (String)it.get('id');
                    }
                    
                    // Validación robusta de ID de Salesforce
                    if (String.isBlank(pbeIdStr) || pbeIdStr.length() < 15) continue;
                    
                    try {
                        Id validPbeId = (Id)pbeIdStr;
                        Decimal can = Decimal.valueOf(String.valueOf(it.get('cantidad') != null ? it.get('cantidad') : 1));
                        Decimal tot = Decimal.valueOf(String.valueOf(it.get('totalSinImpuestos') != null ? it.get('totalSinImpuestos') : 0));
                        
                        // Evitar división por cero
                        Decimal unitPrice = (can > 0) ? (tot/can) : tot;

                        // Capturar descripción técnica completa
                        String fullDesc = (String)it.get('detalleTecnico');
                        // Truncar para el campo estándar por seguridad (255 caracteres)
                        String truncatedDesc = (String.isNotBlank(fullDesc) && fullDesc.length() > 255) ? fullDesc.substring(0, 252) + '...' : fullDesc;

                        QuoteLineItem qli = new QuoteLineItem(
                            QuoteId = rid, 
                            PricebookEntryId = validPbeId, 
                            Quantity = (can > 0 ? can : 1), 
                            UnitPrice = unitPrice,
                            Description = truncatedDesc,
                            Pyatz_Technical_Description__c = fullDesc // Campo nuevo para texto largo
                        );
                        qlis.add(qli);
                    } catch (Exception e) {
                        System.debug('Error procesando partida individual: ' + e.getMessage());
                        continue; // Saltar partidas corruptas sin romper el proceso
                    }
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchParentAccounts(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Account acc : [SELECT Id, Name FROM Account WHERE Name LIKE :query LIMIT 10]) {
            results.add(new Map<String, String>{'id' => acc.Id, 'name' => acc.Name});
        }
        return results;
    }

    @AuraEnabled
    public static Boolean validatePLPassword(String passwordAttempt) { 
        // Usar etiqueta personalizada para mayor seguridad y flexibilidad
        String correctPassword = System.Label.PL_Access_Password;
        return passwordAttempt == correctPassword; 
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchSedes(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Account acc : [SELECT Id, Name FROM Account WHERE Name LIKE :query LIMIT 10]) {
            results.add(new Map<String, String>{'id' => acc.Id, 'name' => acc.Name});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchProspectos(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Lead l : [SELECT Id, Name, Company FROM Lead WHERE (Name LIKE :query OR Company LIKE :query) AND IsConverted = false LIMIT 10]) {
            results.add(new Map<String, String>{'id' => l.Id, 'name' => l.Name + ' (' + l.Company + ')'});
        }
        return results;
    }

    @AuraEnabled
    public static Id cloneQuote(Id quoteId) {
        try {
            Quote orig = [SELECT Id, Name, AccountId, OpportunityId, Pricebook2Id, Introduction_Text__c, Warranty_Text__c, Technical_Sedes__c, Markers_Data__c, Description, (SELECT Id, PricebookEntryId, Quantity, UnitPrice, Discount, Description FROM QuoteLineItems) FROM Quote WHERE Id = :quoteId];
            Quote cl = orig.clone(false, true, false, false);
            cl.Name = 'CLON: ' + orig.Name; cl.Status = 'Draft'; insert cl;
            List<QuoteLineItem> items = new List<QuoteLineItem>();
            for(QuoteLineItem i : orig.QuoteLineItems) items.add(new QuoteLineItem(QuoteId = cl.Id, PricebookEntryId = i.PricebookEntryId, Quantity = i.Quantity, UnitPrice = i.UnitPrice, Description = i.Description));
            insert items;
            return cl.Id;
        } catch (Exception e) { throw new AuraHandledException('Clonación: ' + e.getMessage()); }
    }
}