public with sharing class QuoteContractPDFController {
    public Quote quoteRecord {get; set;}
    public List<QuoteLineItem> selectedLineItems {get; set;}
    public Map<String, Boolean> config {get; set;}
    public String fechaHoy {get; set;}
    public Decimal totalContrato {get; set;}
    
    // Nuevas variables para firmas
    public String firmanteNombre {get; set;}
    public String firmanteCargo {get; set;}
    public String firmanteCliente {get; set;}

    public QuoteContractPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        this.fechaHoy = Date.today().format();
        this.totalContrato = 0;
        
        this.quoteRecord = [SELECT Id, Name, QuoteNumber, Account.Name, Account.BillingStreet, Account.BillingCity, 
                                   Contact.Name, CreatedBy.Name, CreatedBy.Email, CreatedDate,
                                   TotalPrice, Business_Lines_Selected__c, Technical_Sedes__c,
                                   Introduction_Text__c, Warranty_Text__c, Description, Subtotal
                            FROM Quote WHERE Id = :quoteId];

        Map<String, String> params = ApexPages.currentPage().getParameters();
        this.config = new Map<String, Boolean>();
        List<String> keys = new List<String>{'show_total', 'show_line_prices'};
        for (String key : keys) {
            this.config.put(key, !params.containsKey(key) || params.get(key) == 'true');
        }

        // 1. Filtrar partidas
        String selectedIdsParam = params.get('selectedItems');
        if (String.isNotBlank(selectedIdsParam)) {
            this.selectedLineItems = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, 
                                             Discount, Description FROM QuoteLineItem 
                                      WHERE QuoteId = :quoteId AND Id IN :selectedIdsParam.split(',')];
            for(QuoteLineItem item : this.selectedLineItems) {
                this.totalContrato += (item.TotalPrice != null ? item.TotalPrice : 0) * 1.16;
            }
        }

        // 2. Lógica de Firmas Dinámica
        String creatorId = params.get('createdBy');
        String managerId = params.get('managedBy');
        String sigSource = params.get('sigSource');
        Id targetUserId = (sigSource == 'manager' && String.isNotBlank(managerId)) ? (Id)managerId : (Id)creatorId;

        if (targetUserId != null) {
            User u = [SELECT Name, Title FROM User WHERE Id = :targetUserId LIMIT 1];
            this.firmanteNombre = u.Name;
            this.firmanteCargo = u.Title != null ? u.Title : 'Representante Comercial';
        } else {
            this.firmanteNombre = quoteRecord.CreatedBy.Name;
            this.firmanteCargo = 'Gerencia Comercial';
        }

        this.firmanteCliente = params.get('clientSigner');
        if (String.isBlank(this.firmanteCliente)) {
            this.firmanteCliente = quoteRecord.Contact.Name;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
        return [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, 
                       ListPrice, Description, Discount, Quote.Technical_Sedes__c
                FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY CreatedDate ASC];
    }
}