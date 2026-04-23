/**
 * Controlador de dominio para la gestión comercial: Presupuestos, Productos y P&L.
 */
public with sharing class QuoteController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRelatedFiles(Id recordId) {
        return FileService.getRelatedFiles(recordId);
    }

    @AuraEnabled
    public static Map<String, Object> getInitialData(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        Id accountId;
        if(recordId != null) {
            String sType = recordId.getSObjectType().getDescribe().getName();
            if(sType == 'Quote') {
                Quote q = QuoteSelector.getQuoteById(recordId);
                accountId = q.AccountId;
                result.put('quote', q); result.put('opportunityName', q.Opportunity.Name); result.put('agenteNombre', q.CreatedBy.Name);
            } else if(sType == 'Opportunity') {
                Opportunity opp = QuoteSelector.getOpportunityById(recordId);
                accountId = opp.AccountId;
                result.put('opportunity', opp); result.put('opportunityName', opp.Name); result.put('agenteNombre', UserInfo.getName());
            }
        }
        if (accountId != null) result.put('locations', QuoteSelector.getSedesByParentId(accountId, 50));
        return result;
    }

    @AuraEnabled
    public static Id saveTechnicalData(Map<String, Object> data) {
        return QuoteEngineService.saveTechnicalData(data);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchProducts(String searchTerm, Id quoteId, List<String> businessLines, Boolean allowOtherLines) {
        return QuoteEngineService.searchProducts(searchTerm, quoteId, businessLines, allowOtherLines);
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
    public static List<Map<String, Object>> getProductPrices(Id product2Id) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (PricebookEntry pbe : [SELECT Id, Pricebook2.Name, UnitPrice FROM PricebookEntry WHERE Product2Id = :product2Id AND IsActive = true AND Pricebook2.IsActive = true]) {
            results.add(new Map<String, Object>{ 'pbeId' => pbe.Id, 'pricebookName' => pbe.Pricebook2.Name, 'unitPrice' => pbe.UnitPrice });
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getProductInfoByPBE(Id pbeId) {
        PricebookEntry pbe = [SELECT Id, Product2Id, UnitPrice, Product2.Name, Product2.Description, Product2.Family FROM PricebookEntry WHERE Id = :pbeId LIMIT 1];
        return new Map<String, Object>{ 'productId' => pbe.Product2Id, 'name' => pbe.Product2.Name, 'unitPrice' => pbe.UnitPrice, 'description' => pbe.Product2.Description, 'family' => pbe.Product2.Family };
    }

    @AuraEnabled
    public static Id cloneQuote(Id quoteId, Map<String, Object> options, Id targetSedeId, Id targetProspectoId) {
        try {
            Quote source = QuoteSelector.getQuoteById(quoteId);
            Quote target = source.clone(false, true, false, false);
            target.Name = 'CLON - ' + source.Name; target.Status = 'Draft'; insert target;
            if (options == null || (Boolean)options.get('copyLineItems')) {
                List<QuoteLineItem> newQlis = new List<QuoteLineItem>();
                for (QuoteLineItem qli : QuoteSelector.getLineItemsByQuoteId(quoteId)) {
                    QuoteLineItem n = qli.clone(false, true, false, false); n.QuoteId = target.Id; newQlis.add(n);
                }
                if (!newQlis.isEmpty()) insert newQlis;
            }
            return target.Id;
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

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
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchParentAccounts(String searchTerm) {
        String key = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE :key AND ParentId = null LIMIT 10]) results.add(new Map<String, String>{'id' => a.Id, 'name' => a.Name});
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchSedes(String searchTerm) {
        String key = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Account a : [SELECT Id, Name FROM Account WHERE Name LIKE :key AND ParentId != null LIMIT 10]) results.add(new Map<String, String>{'id' => a.Id, 'name' => a.Name});
        return results;
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
    public static List<Map<String, String>> searchNecesidades(String searchTerm) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        String query = '%' + searchTerm + '%';
        for (Necesidades__c n : [SELECT Id, Name, Linea_de_negocio__c FROM Necesidades__c WHERE Name LIKE :query LIMIT 10]) results.add(new Map<String, String>{'id' => n.Id, 'name' => n.Name + ' (' + n.Linea_de_negocio__c + ')'});
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getQuotesList(Id opportunityId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        String query = 'SELECT Id, QuoteNumber, Name, Account.Name, Status, GrandTotal, CreatedDate, CreatedBy.Name, Technical_Sedes__c FROM Quote ';
        if (opportunityId != null) query += 'WHERE OpportunityId = :opportunityId ';
        query += 'ORDER BY CreatedDate DESC LIMIT 50';
        for(Quote q : Database.query(query)) {
            Map<String, Object> row = new Map<String, Object>{ 'id' => q.Id, 'folio' => q.QuoteNumber, 'asunto' => q.Name, 'cliente' => q.Account.Name, 'sede' => q.Technical_Sedes__c, 'generadoPor' => q.CreatedBy.Name, 'fecha' => q.CreatedDate, 'monto' => q.GrandTotal, 'estado' => q.Status };
            result.add(row);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getQuoteStats() {
        Map<String, Integer> stats = new Map<String, Integer>{ 'Total' => 0, 'Aprobada' => 0, 'Pendiente' => 0, 'Rechazada' => 0 };
        for (AggregateResult ar : [SELECT Status, COUNT(Id) total FROM Quote GROUP BY Status]) {
            String status = (String)ar.get('Status'); Integer count = (Integer)ar.get('total');
            stats.put('Total', stats.get('Total') + count);
            if (status == 'Approved' || status == 'Aprobada') stats.put('Aprobada', count);
            else if (status == 'Rejected' || status == 'Rechazada') stats.put('Rechazada', count);
            else stats.put('Pendiente', stats.get('Pendiente') + count);
        }
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchProspectos(String searchTerm) {
        String key = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (Lead l : [SELECT Id, Name, Company FROM Lead WHERE (Name LIKE :key OR Company LIKE :key) AND IsConverted = false LIMIT 10]) results.add(new Map<String, String>{'id' => l.Id, 'name' => l.Name + ' (' + l.Company + ')'});
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContractInitialData(Id oppId) {
        Map<String, Object> result = new Map<String, Object>();
        Opportunity opp = QuoteSelector.getOpportunityById(oppId);
        result.put('opportunity', opp);
        result.put('quotes', [SELECT Id, QuoteNumber, Name, GrandTotal, Status, CreatedDate FROM Quote WHERE OpportunityId = :oppId ORDER BY CreatedDate DESC]);
        result.put('syncedQuoteId', opp.SyncedQuoteId);
        if (opp.SyncedQuoteId != null) result.put('selectedQuote', QuoteSelector.getQuoteById(opp.SyncedQuoteId));
        return result;
    }

    @AuraEnabled
    public static String saveContractData(Id quoteId, Map<String, Object> contractData) {
        try {
            Quote q = QuoteSelector.getQuoteById(quoteId);
            String scName = 'Contrato: ' + q.QuoteNumber + ' - ' + q.Name;
            ServiceContract sc = new ServiceContract(Name = scName, AccountId = q.AccountId, Pricebook2Id = q.Pricebook2Id);
            if (contractData.containsKey('fechaInicioContrato')) sc.StartDate = Date.valueOf((String)contractData.get('fechaInicioContrato'));
            insert sc; update new Quote(Id = quoteId, Status = 'In Review'); return sc.Id;
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchUsers(String searchTerm) {
        String query = '%' + searchTerm + '%';
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (User u : [SELECT Id, Name, Title FROM User WHERE Name LIKE :query AND IsActive = true LIMIT 5]) results.add(new Map<String, String>{ 'id' => u.Id, 'name' => u.Name, 'title' => u.Title != null ? u.Title : 'Colaborador' });
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolder(String folderName) {
        return EmailService.getEmailTemplatesByFolders(new List<String>{folderName});
    }

    @AuraEnabled
    public static String renderTemplate(Id templateId, Id quoteId) {
        return EmailService.renderTemplate(templateId, quoteId);
    }

    @AuraEnabled
    public static Boolean validatePLPassword(String password) {
        return password == System.Label.PL_Access_Password;
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> getFilteredSedes(String searchTerm, Id parentAccountId, Boolean isGlobal) {
        String key = '%' + searchTerm + '%';
        if (isGlobal) return [SELECT Id, Name, BillingStreet, BillingCity, Phone, Parent.Name FROM Account WHERE Name LIKE :key LIMIT 100];
        if (parentAccountId == null) return new List<Account>();
        return [SELECT Id, Name, BillingStreet, BillingCity, Phone FROM Account WHERE ParentId = :parentAccountId AND (Name LIKE :key OR BillingCity LIKE :key) LIMIT 200];
    }
}