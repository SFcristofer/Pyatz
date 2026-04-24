/**
 * Controlador de dominio para Operaciones de Campo, Calendario y Seguimiento Táctico.
 */
public with sharing class OperationsController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpportunitiesList() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for(Opportunity o : [SELECT Id, Name, Account.Name, StageName, Amount, CloseDate, Owner.Name FROM Opportunity ORDER BY CreatedDate DESC LIMIT 50]) {
            result.add(new Map<String, Object>{ 'id' => o.Id, 'name' => o.Name, 'account' => o.Account.Name, 'owner' => o.Owner.Name, 'closeDate' => o.CloseDate, 'amount' => o.Amount, 'stageName' => o.StageName });
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpportunitiesByAccount(Id accountId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Opportunity o : [SELECT Id, Name, StageName, Amount, CloseDate, Owner.Name, Account.Name, Subetapa__c, Estado_Subetapa__c FROM Opportunity WHERE AccountId = :accountId ORDER BY CreatedDate DESC]) {
            results.add(new Map<String, Object>{ 'id' => o.Id, 'name' => o.Name, 'account' => o.Account.Name, 'stageName' => o.StageName, 'amount' => o.Amount != null ? o.Amount : 0, 'closeDate' => o.CloseDate, 'owner' => o.Owner.Name, 'subetapa' => o.Subetapa__c, 'estado' => o.Estado_Subetapa__c });
        }
        return results;
    }

    @AuraEnabled
    public static Id saveTechnicalData(Map<String, Object> data) {
        return QuoteEngineService.saveTechnicalData(data);
    }

    @AuraEnabled
    public static List<Map<String, Object>> getChecklist(Id opportunityId, String category) {
        return FileService.getChecklist(opportunityId, category);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEvidenceGallery(Id opportunityId) {
        return FileService.getEvidenceGallery(opportunityId);
    }

    @AuraEnabled
    public static void renameUploadedFile(Id documentId, String docType) {
        FileService.renameAndLinkFile(documentId, docType);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCalendarData(Id recordId, String startDate, String endDate) {
        return CalendarService.getCalendarData(startDate, endDate);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTacticalHistory(Id oppId) {
        return OperationsService.getTacticalHistory(oppId);
    }

    @AuraEnabled
    public static void updateTaskActivity(Id taskId, String newStatus, String observation) {
        OperationsService.updateTaskActivity(taskId, newStatus, observation);
    }

    @AuraEnabled
    public static void saveStageTracking(Id opportunityId, String stage, String subStage, String status) {
        OperationsService.saveStageTracking(opportunityId, stage, subStage, status);
    }

    @AuraEnabled
    public static List<Map<String, Object>> getActionTimeline(Id opportunityId) {
        return CalendarService.getActionTimeline(opportunityId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Seguimiento_Etapas_Pyatz__c> getProcessHistory(Id opportunityId) {
        return [SELECT Etapa__c, Subetapa__c, Estado__c, LastModifiedDate FROM Seguimiento_Etapas_Pyatz__c WHERE Oportunidad__c = :opportunityId ORDER BY CreatedDate ASC];
    }

    @AuraEnabled
    public static Id saveNote(Id parentId, String title, String content) {
        return OperationsService.saveNote(parentId, title, content);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOpenOpportunities() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(Opportunity o : [SELECT Id, Name FROM Opportunity WHERE IsClosed = false ORDER BY Name ASC LIMIT 100]) {
            options.add(new Map<String, String>{'label' => o.Name, 'value' => o.Id});
        }
        return options;
    }
}