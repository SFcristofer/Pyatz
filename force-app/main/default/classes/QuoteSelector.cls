/**
 * Clase dedicada a la extracción de datos (SOQL) para el ecosistema de presupuestos y proyectos.
 * Centraliza las consultas para optimizar el rendimiento y evitar límites de transacción.
 */
public with sharing class QuoteSelector {

    /**
     * Recupera información detallada de una cotización técnica.
     */
    public static Quote getQuoteById(Id quoteId) {
        if (quoteId == null) return null;
        return [SELECT Id, Name, QuoteNumber, AccountId, Account.Name, ContactId, Contact.Name, Status, 
                       Description, Markers_Data__c, Introduction_Text__c, Warranty_Text__c, 
                       Business_Lines_Selected__c, Technical_Sedes__c, Show_Introduction__c, 
                       Show_Warranty__c, CreatedBy.Name, CreatedDate, OpportunityId, Opportunity.Name,
                       Pricebook2Id, GrandTotal, ExpirationDate
                FROM Quote 
                WHERE Id = :quoteId 
                LIMIT 1];
    }

    /**
     * Recupera información de una oportunidad para la inicialización del editor.
     */
    public static Opportunity getOpportunityById(Id oppId) {
        if (oppId == null) return null;
        return [SELECT Id, Name, AccountId, Account.Name, Pricebook2Id, SyncedQuoteId, Amount, CloseDate, StageName, Owner.Name 
                FROM Opportunity 
                WHERE Id = :oppId 
                LIMIT 1];
    }

    /**
     * Recupera la lista de partidas (QuoteLineItems) asociadas a una cotización.
     */
    public static List<QuoteLineItem> getLineItemsByQuoteId(Id quoteId) {
        return [SELECT Id, PricebookEntryId, Quantity, UnitPrice, Description, Discount, ServiceDate, 
                       Product2Id, Product2.Name, Descripcion_Detallada__c, ListPrice, TotalPrice
                FROM QuoteLineItem 
                WHERE QuoteId = :quoteId 
                ORDER BY CreatedDate ASC];
    }

    /**
     * Recupera las sedes (cuentas hijas) relacionadas a un cliente.
     */
    public static List<Account> getSedesByParentId(Id parentAccountId, Integer queryLimit) {
        return [SELECT Id, Name, BillingStreet, BillingCity, Phone 
                FROM Account 
                WHERE ParentId = :parentAccountId 
                LIMIT :queryLimit];
    }

    /**
     * Recupera el análisis P&L asociado a un presupuesto.
     */
    public static List<Analisis_PL__c> getPLAnalysisByQuoteId(Id quoteId) {
        return [SELECT Anio__c, Costo_Inversion__c, Margen_Esperado__c, Gastos_Indirectos__c,
                       Comision_Venta__c, Comision_Venta_2__c, Regalias__c, Dias_Financiamiento__c
                FROM Analisis_PL__c
                WHERE Presupuesto__c = :quoteId
                ORDER BY Anio__c ASC];
    }
}
