public with sharing class QuoteTechnicalPDFController {
    public Quote technicalQuote {get; set;}
    public String versionId {get; set;}
    public Map<Id, String> htmlDescriptions {get; set;} // Mapa de ID de partida -> HTML

    public QuoteTechnicalPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        this.htmlDescriptions = new Map<Id, String>();
        
        // 1. Cargamos datos
        this.technicalQuote = [SELECT Id, Name, QuoteNumber, AccountId, Account.Name, ContactId, Contact.Name, Opportunity.Name, 
                                     Show_Introduction__c, Introduction_Text__c, 
                                     Show_Warranty__c, Warranty_Text__c, Markers_Data__c,
                                     Business_Lines_Selected__c, Technical_Sedes__c, CreatedBy.Name, CreatedBy.Email, CreatedDate,
                                     Subtotal, Tax, TotalPrice, Description,
                                     (SELECT Id, Product2.Name, Description, Quantity, ListPrice, UnitPrice, Discount, TotalPrice 
                                      FROM QuoteLineItems)
                              FROM Quote 
                              WHERE Id = :quoteId];

        // 2. Extraer HTML de la memoria persistente
        if (String.isNotBlank(this.technicalQuote.Markers_Data__c)) {
            try {
                String decodedJson = EncodingUtil.base64Decode(this.technicalQuote.Markers_Data__c).toString();
                Map<String, Object> fullState = (Map<String, Object>)JSON.deserializeUntyped(decodedJson);
                if (fullState.containsKey('serviciosData')) {
                    List<Object> servicios = (List<Object>)fullState.get('serviciosData');
                    // Mapear por nombre de producto y sede para coincidir con las líneas
                    for (Object obj : servicios) {
                        Map<String, Object> s = (Map<String, Object>)obj;
                        String html = (String)s.get('detalleTecnicoHtml');
                        String key = (String)s.get('descripcion'); // "Producto - Sede"
                        
                        for (QuoteLineItem qli : this.technicalQuote.QuoteLineItems) {
                            String qliKey = qli.Product2.Name + ' - ' + (qli.Description != null ? qli.Description.substringBefore('\n') : '');
                            if (qliKey.contains(qli.Product2.Name)) {
                                this.htmlDescriptions.put(qli.Id, html);
                            }
                        }
                    }
                }
            } catch (Exception e) { System.debug('Error recuperando HTML: ' + e.getMessage()); }
        }
        
        // 3. Buscar documentos... (resto igual)
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