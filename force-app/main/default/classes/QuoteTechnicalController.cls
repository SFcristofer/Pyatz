public with sharing class QuoteTechnicalController {
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchUsers(String searchTerm) {
        String query = '%' + searchTerm + '%';
        List<User> users = [SELECT Id, Name, Title FROM User WHERE Name LIKE :query AND IsActive = true LIMIT 5];
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (User u : users) {
            results.add(new Map<String, String>{
                'id' => u.Id, 'name' => u.Name, 'title' => u.Title != null ? u.Title : 'Colaborador'
            });
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
                           Technical_Sedes__c, Show_Introduction__c, Show_Warranty__c, ExpirationDate, CreatedBy.Name, CreatedDate,
                           (SELECT Id, Product2.Name, PricebookEntryId, Quantity, UnitPrice, ListPrice, Discount, Description, TotalPrice FROM QuoteLineItems)
                           FROM Quote WHERE Id = :recordId];
                accountId = q.AccountId;
                result.put('quote', q);
                result.put('clienteNombre', q.Account.Name);
                result.put('agenteNombre', q.CreatedBy.Name);
            } else if(sType == 'Opportunity') {
                Opportunity opp = [SELECT Id, Name, AccountId, Account.Name, Pricebook2Id FROM Opportunity WHERE Id = :recordId];
                accountId = opp.AccountId;
                result.put('opportunity', opp);
                result.put('agenteNombre', UserInfo.getName());
            }
        }
        
        if (accountId != null) {
            result.put('necesidades', [SELECT Id, Name, Linea_de_negocio__c FROM Necesidades__c WHERE Cuenta__c = :accountId LIMIT 20]);
            result.put('locations', [SELECT Id, Name, BillingStreet, BillingCity, Phone FROM Account WHERE ParentId = :accountId LIMIT 50]);
            result.put('contacts', [SELECT Id, Name, Phone, Email, AccountId FROM Contact WHERE AccountId = :accountId LIMIT 100]);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBusinessLineOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(Schema.PicklistEntry f : Product2.Family.getDescribe().getPicklistValues()) {
            if(f.isActive()) {
                options.add(new Map<String, String>{'label' => f.getLabel(), 'value' => f.getValue()});
            }
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
        if (pbId == null) {
            try { pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id; } catch(Exception e) {}
        }
        String query = '%' + searchTerm + '%';
        String soql = 'SELECT Id, Product2Id, Product2.Name, Product2.Description, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :pbId AND (Product2.Name LIKE :query OR Product2.ProductCode LIKE :query) AND IsActive = true ';
        if (!allowOtherLines && businessLines != null && !businessLines.isEmpty()) soql += 'AND Product2.Family IN :businessLines ';
        soql += 'LIMIT 15';
        for (PricebookEntry pbe : Database.query(soql)) {
            results.add(new Map<String, Object>{
                'id' => pbe.Id, 'productId' => pbe.Product2Id, 'name' => pbe.Product2.Name, 'description' => pbe.Product2.Description, 'unitPrice' => pbe.UnitPrice
            });
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getProductPrices(Id product2Id) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (PricebookEntry pbe : [SELECT Id, Pricebook2.Name, UnitPrice FROM PricebookEntry WHERE Product2Id = :product2Id AND IsActive = true AND Pricebook2.IsActive = true ORDER BY Pricebook2.Name ASC]) {
            results.add(new Map<String, Object>{'pbeId' => pbe.Id, 'pricebookName' => pbe.Pricebook2.Name, 'unitPrice' => pbe.UnitPrice});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchNecesidades(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Necesidades__c n : [SELECT Id, Name, Linea_de_negocio__c FROM Necesidades__c WHERE Name LIKE :query OR Linea_de_negocio__c LIKE :query LIMIT 10]) {
            results.add(new Map<String, String>{'id' => n.Id, 'name' => n.Name + ' (' + n.Linea_de_negocio__c + ')'});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolder(String folderName) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (EmailTemplate et : [SELECT Id, Name, Description FROM EmailTemplate WHERE Folder.Name = :folderName AND IsActive = true ORDER BY Name ASC]) {
            results.add(new Map<String, String>{'id' => et.Id, 'name' => et.Name, 'description' => et.Description});
        }
        return results;
    }

    @AuraEnabled
    public static String renderTemplate(Id templateId, Id quoteId) {
        try {
            Quote q = [SELECT ContactId, AccountId FROM Quote WHERE Id = :quoteId LIMIT 1];
            Id conId = q.ContactId;
            if (conId == null) {
                List<Contact> cs = [SELECT Id FROM Contact WHERE AccountId = :q.AccountId LIMIT 1];
                if (!cs.isEmpty()) conId = cs[0].Id;
            }
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, conId, quoteId);
            String body = rendered.getHtmlBody();
            if (body != null && body.contains('<body')) {
                body = body.substringAfter('>');
                if (body.contains('</body>')) body = body.substringBeforeLast('</body>');
            }
            return body != null ? body.trim() : rendered.getPlainTextBody();
        } catch (Exception e) { throw new AuraHandledException('Error render: ' + e.getMessage()); }
    }

    @AuraEnabled
    public static Boolean validatePLPassword(String passwordAttempt) {
        return passwordAttempt == System.Label.PL_Access_Password;
    }

    @AuraEnabled
    public static Id saveTechnicalData(Map<String, Object> data) {
        try {
            Map<String, Object> p = data.containsKey('data') ? (Map<String, Object>)data.get('data') : data;
            Id rid = (Id)p.get('quoteId');
            Id aid = (Id)p.get('accountId');
            Id cid = (Id)p.get('contactId');
            String status = (String)p.get('status');
            String itemsJson = (String)p.get('lineItems');
            
            Quote q;
            if (rid != null && rid.getSObjectType().getDescribe().getName() == 'Quote') {
                q = new Quote(Id = rid, Name = (String)p.get('name'), Status = status, Introduction_Text__c = (String)p.get('intro'), Warranty_Text__c = (String)p.get('warranty'), Business_Lines_Selected__c = (String)p.get('businessLines'), Technical_Sedes__c = (String)p.get('technicalSedes'), Show_Introduction__c = (Boolean)p.get('showIntro'), Show_Warranty__c = (Boolean)p.get('showWarranty'), Description = (String)p.get('observacionesPago'), Markers_Data__c = (String)p.get('markersData'));
                if (cid != null && String.valueOf(cid).startsWith('003')) q.ContactId = cid;
                update q;
            } else {
                Id pbId;
                try { pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1].Id; } catch(Exception e) {
                    List<Pricebook2> pbs = [SELECT Id FROM Pricebook2 WHERE IsActive = true LIMIT 1];
                    if(!pbs.isEmpty()) pbId = pbs[0].Id;
                }
                Id oppId;
                if (rid != null && rid.getSObjectType().getDescribe().getName() == 'Opportunity') oppId = rid;
                else if (aid != null) {
                    Opportunity o = new Opportunity(Name = 'Op. Técnica - ' + (String)p.get('name'), AccountId = aid, StageName = 'Prospecting', CloseDate = Date.today().addDays(30), Pricebook2Id = pbId);
                    insert o; oppId = o.Id;
                }
                q = new Quote(Name = (String)p.get('name'), Status = status, Introduction_Text__c = (String)p.get('intro'), Warranty_Text__c = (String)p.get('warranty'), Business_Lines_Selected__c = (String)p.get('businessLines'), Technical_Sedes__c = (String)p.get('technicalSedes'), Show_Introduction__c = (Boolean)p.get('showIntro'), Show_Warranty__c = (Boolean)p.get('showWarranty'), Description = (String)p.get('observacionesPago'), Pricebook2Id = pbId, Markers_Data__c = (String)p.get('markersData'), ExpirationDate = Date.today().addDays(30), OpportunityId = oppId);
                if (cid != null && String.valueOf(cid).startsWith('003')) q.ContactId = cid;
                insert q; rid = q.Id;
            }

            if (String.isNotBlank(itemsJson)) {
                List<Object> items = (List<Object>)JSON.deserializeUntyped(itemsJson);
                delete [SELECT Id FROM QuoteLineItem WHERE QuoteId = :rid];
                
                List<QuoteLineItem> qlis = new List<QuoteLineItem>();
                Id firstPbId = null;
                
                for (Object obj : items) {
                    Map<String, Object> it = (Map<String, Object>)obj;
                    if (it.get('isSeparator') == true) continue;
                    Object pIdObj = it.get('productId');
                    if (pIdObj == null || String.valueOf(pIdObj) == '' || String.valueOf(pIdObj) == 'null') continue;
                    
                    Id pbeId = (Id)pIdObj;
                    // Detectar lista de precios del primer item
                    if (firstPbId == null) {
                        firstPbId = [SELECT Pricebook2Id FROM PricebookEntry WHERE Id = :pbeId LIMIT 1].Pricebook2Id;
                    }

                    String sCan = String.valueOf(it.get('cantidad'));
                    String sUp = String.valueOf(it.get('importeUnitario'));
                    String sDesc = String.valueOf(it.get('descuento'));
                    Decimal canVal = (String.isNotBlank(sCan) && sCan != 'null') ? Decimal.valueOf(sCan) : 0;
                    Decimal upVal = (String.isNotBlank(sUp) && sUp != 'null') ? Decimal.valueOf(sUp) : 0;
                    Decimal descuentoVal = (String.isNotBlank(sDesc) && sDesc != 'null') ? Decimal.valueOf(sDesc) : 0;
                    
                    qlis.add(new QuoteLineItem(QuoteId = rid, PricebookEntryId = pbeId, Quantity = canVal, UnitPrice = upVal, Description = (String)it.get('detalleTecnico'), Discount = descuentoVal));
                }
                
                // Sincronizar lista de precios de la Quote con los items
                if (firstPbId != null) {
                    update new Quote(Id = rid, Pricebook2Id = firstPbId);
                }
                
                if (!qlis.isEmpty()) insert qlis;
            }
            return rid;
        } catch (Exception e) { throw new AuraHandledException('Error Apex: ' + e.getMessage() + ' | Línea: ' + e.getLineNumber()); }
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

    @AuraEnabled(cacheable=true)
    public static List<Account> getFilteredSedes(String searchTerm, Id parentAccountId, Boolean isGlobal) {
        String key = '%' + searchTerm + '%';
        if (isGlobal) return [SELECT Id, Name, BillingStreet, BillingCity, Phone FROM Account WHERE Name LIKE :key LIMIT 200];
        return [SELECT Id, Name, BillingStreet, BillingCity, Phone FROM Account WHERE ParentId = :parentAccountId AND Name LIKE :key LIMIT 200];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchSedes(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Account acc : [SELECT Id, Name, BillingCity FROM Account WHERE Name LIKE :query OR Parent.Name LIKE :query LIMIT 10]) {
            results.add(new Map<String, String>{'id' => acc.Id, 'name' => acc.Name + (acc.BillingCity != null ? ' - ' + acc.BillingCity : '')});
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchProspectos(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Lead l : [SELECT Id, Name, Company, City FROM Lead WHERE Name LIKE :query OR Company LIKE :query LIMIT 10]) {
            results.add(new Map<String, String>{'id' => l.Id, 'name' => l.Name + ' (' + l.Company + ') - ' + (l.City != null ? l.City : 'N/A')});
        }
        return results;
    }

    @AuraEnabled
    public static Id cloneQuote(Id quoteId, Map<String, Boolean> options, Id targetSedeId, Id targetProspectoId) {
        try {
            Quote orig = [SELECT Id, Name, AccountId, OpportunityId, Pricebook2Id, Introduction_Text__c, Warranty_Text__c, Business_Lines_Selected__c, Technical_Sedes__c, Show_Introduction__c, Show_Warranty__c, Description, (SELECT Id, PricebookEntryId, Quantity, UnitPrice, Discount, Description FROM QuoteLineItems) FROM Quote WHERE Id = :quoteId];
            Quote cl = orig.clone(false, true, false, false);
            cl.Name = 'CLON: ' + orig.Name; cl.Status = 'Draft'; cl.Source_Quote__c = orig.Id;
            insert cl;
            List<QuoteLineItem> items = new List<QuoteLineItem>();
            for(QuoteLineItem i : orig.QuoteLineItems) items.add(new QuoteLineItem(QuoteId = cl.Id, PricebookEntryId = i.PricebookEntryId, Quantity = i.Quantity, UnitPrice = i.UnitPrice, Discount = i.Discount, Description = i.Description));
            insert items;
            return cl.Id;
        } catch (Exception e) { throw new AuraHandledException('Clonación: ' + e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getCloneCount(Id quoteId) {
        return [SELECT COUNT() FROM Quote WHERE Source_Quote__c = :quoteId];
    }
}