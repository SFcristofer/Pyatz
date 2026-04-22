/**
 * Servicio encargado de la lógica operativa: Tareas, Notas, Historial Táctico y Seguimiento de Etapas.
 */
public with sharing class OperationsService {

    public static List<Map<String, Object>> getTacticalHistory(Id oppId) {
        List<Map<String, Object>> history = new List<Map<String, Object>>();
        if (oppId == null) return history;

        Set<Id> allRelatedIds = new Set<Id>{oppId};
        for (Levantamiento_Tecnico__c lev : [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId]) allRelatedIds.add(lev.Id);
        for (Solucion_Tecnica__c sol : [SELECT Id FROM Solucion_Tecnica__c WHERE Levantamiento_Tecnico__r.Oportunidad__c = :oppId]) allRelatedIds.add(sol.Id);
        
        for (Task t : [SELECT Id, Subject, Status, Description, TaskSubtype, CreatedDate FROM Task WHERE WhatId = :oppId ORDER BY CreatedDate DESC LIMIT 40]) {
            String subType = t.TaskSubtype != null ? t.TaskSubtype : 'Task';
            String icon = subType == 'Call' ? 'standard:log_a_call' : (subType == 'Email' ? 'standard:email' : 'standard:task');
            history.add(new Map<String, Object>{ 'id' => t.Id, 'type' => 'Actividad', 'label' => subType, 'subject' => t.Subject, 'date' => t.CreatedDate, 'icon' => icon, 'desc' => t.Description, 'status' => t.Status, 'isTask' => (subType != 'Email') });
        }

        for (Levantamiento_Tecnico__c lev : [SELECT Id, Name, Tipo_Servicio__c, CreatedDate FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY CreatedDate DESC]) {
            history.add(new Map<String, Object>{ 'id' => lev.Id, 'type' => 'Levantamiento', 'label' => 'Auditoría Técnica', 'subject' => 'Levantamiento: ' + lev.Tipo_Servicio__c, 'date' => lev.CreatedDate, 'icon' => 'standard:survey', 'desc' => 'Se registraron hallazgos técnicos en la sede cliente.' });
        }
        
        return history;
    }

    public static void updateTaskActivity(Id taskId, String newStatus, String observation) {
        Task t = [SELECT Id, Status, Description FROM Task WHERE Id = :taskId LIMIT 1];
        if (String.isNotBlank(newStatus)) t.Status = newStatus;
        if (String.isNotBlank(observation)) {
            String timestamp = '[' + System.now().format('dd/MM/yyyy HH:mm') + ' - ' + UserInfo.getName() + ']: ';
            t.Description = (t.Description != null ? t.Description : '') + '\n' + timestamp + observation;
        }
        update t;
    }

    public static void saveStageTracking(Id opportunityId, String stage, String subStage, String status) {
        Seguimiento_Etapas_Pyatz__c track = new Seguimiento_Etapas_Pyatz__c(Oportunidad__c = opportunityId, Etapa__c = stage, Subetapa__c = subStage, Estado__c = status, Clave_Unica__c = opportunityId + '_' + stage + '_' + subStage);
        upsert track Clave_Unica__c;
    }

    public static Id saveNote(Id parentId, String title, String content) {
        ContentNote cn = new ContentNote();
        cn.Title = title;
        cn.Content = Blob.valueOf(content.escapeHtml4());
        insert cn;
        
        ContentDocumentLink cdl = new ContentDocumentLink(ContentDocumentId = cn.Id, LinkedEntityId = parentId, ShareType = 'V', Visibility = 'AllUsers');
        insert cdl;
        return cn.Id;
    }
}
