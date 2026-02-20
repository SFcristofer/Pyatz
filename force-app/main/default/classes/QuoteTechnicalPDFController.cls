public with sharing class QuoteTechnicalPDFController {
    public Quote technicalQuote {get; set;}
    public String versionId {get; set;}

    public QuoteTechnicalPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        
        // 1. Cargamos datos y partidas
        this.technicalQuote = [SELECT Id, Name, QuoteNumber, AccountId, Account.Name, ContactId, Contact.Name, Opportunity.Name, 
                                     Show_Introduction__c, Introduction_Text__c, 
                                     Show_Warranty__c, Warranty_Text__c,
                                     Business_Lines_Selected__c, Technical_Sedes__c, CreatedBy.Name, CreatedBy.Email, CreatedDate,
                                     Subtotal, Tax, TotalPrice, Description,
                                     (SELECT Id, Product2.Name, Description, Quantity, ListPrice, UnitPrice, Discount, TotalPrice 
                                      FROM QuoteLineItems)
                              FROM Quote 
                              WHERE Id = :quoteId];
        
        // 2. Buscamos el documento de forma multinivel para asegurar encontrarlo
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :quoteId];
        if(!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for(ContentDocumentLink cdl : links) docIds.add(cdl.ContentDocumentId);
            
            List<ContentVersion> versions = [SELECT Id FROM ContentVersion 
                                             WHERE ContentDocumentId IN :docIds 
                                             AND Title = 'Levantamiento_Tecnico_Snapshot' 
                                             AND IsLatest = true 
                                             ORDER BY CreatedDate DESC LIMIT 1];
            if(!versions.isEmpty()) {
                this.versionId = versions[0].Id;
            }
        }
    }
}