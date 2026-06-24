/**
 * Controlador de dominio para Levantamientos Técnicos, Soluciones y Memorias.
 */
public with sharing class SurveyController {

    private static Id resolveOppId(Id recordId) {
        if (recordId == null) return null;
        if (recordId.getSObjectType().getDescribe().getName() == 'Quote') {
            return [SELECT OpportunityId FROM Quote WHERE Id = :recordId].OpportunityId;
        }
        return recordId;
    }

    @AuraEnabled
    public static void saveSurveyData(Id oppId, String type, String surveyDataJson, String diagDataJson) {
        LevantamientoService.saveSurveyData(oppId, type, surveyDataJson, diagDataJson);
    }

    @AuraEnabled
    public static List<Levantamiento_Tecnico__c> getLevantamientoDetails(Id recordId) {
        return LevantamientoService.getLevantamientoDetails(recordId);
    }

    @AuraEnabled
    public static List<Map<String, Object>> getOpportunitySolutions(Id oppId) {
        return SurveyService.getOpportunitySolutions(oppId);
    }

    // --- NUEVOS MÉTODOS PARA ARQUITECTURA MUCHOS A MUCHOS ---
    @AuraEnabled
    public static List<Solucion_Tecnica__c> getSolucionesOpp(Id recordId) {
        Id oppId = resolveOppId(recordId);
        return [SELECT Id, Name, Descripcion_Detallada__c, Observaciones_Comerciales__c,
                (SELECT Id FROM Enlaces_Hallazgos__r) 
                FROM Solucion_Tecnica__c 
                WHERE Oportunidad__c = :oppId ORDER BY CreatedDate ASC];
    }

    @AuraEnabled
    public static Id saveSolucionOpp(Id recordId, Id solucionId, String nombre, String descripcion) {
        Id oppId = resolveOppId(recordId);
        Solucion_Tecnica__c sol = new Solucion_Tecnica__c(
            Id = solucionId, 
            Name = nombre, 
            Descripcion_Detallada__c = descripcion
        );
        if (solucionId == null) {
            sol.Oportunidad__c = oppId;
        }
        upsert sol; 
        return sol.Id;
    }

    @AuraEnabled
    public static List<Id> getEnlacesForSolucion(Id solucionId) {
        List<Enlace_Solucion__c> enlaces = [SELECT Levantamiento_Tecnico__c FROM Enlace_Solucion__c WHERE Solucion_Tecnica__c = :solucionId];
        List<Id> ids = new List<Id>();
        for(Enlace_Solucion__c e : enlaces) ids.add(e.Levantamiento_Tecnico__c);
        return ids;
    }

    @AuraEnabled
    public static void saveEnlaces(Id solucionId, List<Id> hallazgosIds) {
        if (solucionId == null) return;
        List<Enlace_Solucion__c> existing = [SELECT Id, Levantamiento_Tecnico__c FROM Enlace_Solucion__c WHERE Solucion_Tecnica__c = :solucionId];
        Set<Id> existingIds = new Set<Id>();
        for(Enlace_Solucion__c e : existing) existingIds.add(e.Levantamiento_Tecnico__c);
        
        Set<Id> newIds = new Set<Id>(hallazgosIds);
        List<Enlace_Solucion__c> toDelete = new List<Enlace_Solucion__c>();
        for(Enlace_Solucion__c e : existing) {
            if(!newIds.contains(e.Levantamiento_Tecnico__c)) toDelete.add(e);
        }
        
        List<Enlace_Solucion__c> toInsert = new List<Enlace_Solucion__c>();
        for(Id hId : newIds) {
            if(!existingIds.contains(hId)) {
                toInsert.add(new Enlace_Solucion__c(Solucion_Tecnica__c = solucionId, Levantamiento_Tecnico__c = hId));
            }
        }
        
        if(!toDelete.isEmpty()) delete toDelete;
        if(!toInsert.isEmpty()) insert toInsert;
    }

    // --- MÉTODOS LEGACY MANTENIDOS ---
    @AuraEnabled
    public static List<Solucion_Tecnica__c> getSoluciones(Id levantamientoId) {
        return [SELECT Id, Name, Descripcion_Detallada__c FROM Solucion_Tecnica__c WHERE Levantamiento_Tecnico__c = :levantamientoId ORDER BY CreatedDate ASC];
    }

    @AuraEnabled
    public static Id saveSolucion(Id levantamientoId, Id solucionId, String nombre, String descripcion, String observaciones) {
        return SurveyService.saveSolucion(levantamientoId, solucionId, nombre, descripcion, observaciones);
    }

    @AuraEnabled
    public static void deleteSolucion(Id solucionId) {
        SurveyService.deleteSolucion(solucionId);
    }

    @AuraEnabled
    public static void saveMemoria(Id recordId, String text) {
        try {
            String sType = recordId.getSObjectType().getDescribe().getName();
            if (sType == 'Quote') update new Quote(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Opportunity') update new Opportunity(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Levantamiento_Tecnico__c') update new Levantamiento_Tecnico__c(Id = recordId, Memoria_Descriptiva__c = text);
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
}