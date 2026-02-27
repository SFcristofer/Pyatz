public with sharing class QuoteContractPDFController {
    public Quote quoteRecord {get; set;}
    public List<QuoteLineItem> selectedLineItems {get; set;}
    public Map<String, Boolean> config {get; set;}
    public String frecuencia {get; set;}
    public String fechaHoy {get; set;}
    public Decimal totalContrato {get; set;}

    public QuoteContractPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        this.fechaHoy = Date.today().format();
        this.totalContrato = 0;
        
        // 1. Cargar datos de la cotización
        this.quoteRecord = [SELECT Id, Name, QuoteNumber, Account.Name, Account.BillingStreet, Account.BillingCity, 
                                   Contact.Name, CreatedBy.Name, CreatedBy.Email, CreatedDate,
                                   TotalPrice, Business_Lines_Selected__c, Technical_Sedes__c,
                                   Introduction_Text__c, Warranty_Text__c, Description, Subtotal
                            FROM Quote WHERE Id = :quoteId];

        // 2. Leer configuración de la URL
        Map<String, String> params = ApexPages.currentPage().getParameters();
        this.config = new Map<String, Boolean>();
        
        List<String> keys = new List<String>{
            'legal_clauses', 'confidentiality', 'data_protection', 
            'technical_summary', 'photo_gallery', 'equipment_list', 
            'annual_calendar', 'access_protocol', 'tax_retentions', 
            'payment_conditions', 'company_seal'
        };

        for (String key : keys) {
            this.config.put(key, params.containsKey(key) && params.get(key) == 'true');
        }

        this.frecuencia = params.containsKey('frecuencia') ? params.get('frecuencia') : 'mensual';

        // 3. Filtrar partidas seleccionadas
        String selectedIdsParam = params.get('selectedItems');
        if (String.isNotBlank(selectedIdsParam)) {
            List<String> selectedIds = selectedIdsParam.split(',');
            this.selectedLineItems = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, 
                                             Discount, Description, ListPrice, ServiceDate
                                      FROM QuoteLineItem 
                                      WHERE QuoteId = :quoteId AND Id IN :selectedIds
                                      ORDER BY CreatedDate ASC];
            
            for(QuoteLineItem item : this.selectedLineItems) {
                this.totalContrato += item.TotalPrice;
            }
        } else {
            this.selectedLineItems = new List<QuoteLineItem>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
        return [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, 
                       ListPrice, Description, Discount, Quote.Technical_Sedes__c
                FROM QuoteLineItem 
                WHERE QuoteId = :quoteId
                ORDER BY CreatedDate ASC];
    }
}