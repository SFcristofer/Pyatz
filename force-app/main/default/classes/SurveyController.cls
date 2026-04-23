/**
 * Controlador de dominio para Levantamientos Técnicos, Soluciones y Memorias.
 */
public with sharing class SurveyController {

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
        // Delegación directa a actualización de registro
        try {
            String sType = recordId.getSObjectType().getDescribe().getName();
            if (sType == 'Quote') update new Quote(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Opportunity') update new Opportunity(Id = recordId, Memoria_Descriptiva__c = text);
            else if (sType == 'Levantamiento_Tecnico__c') update new Levantamiento_Tecnico__c(Id = recordId, Memoria_Descriptiva__c = text);
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
}