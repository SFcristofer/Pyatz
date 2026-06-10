/**
 * Servicio encargado de la lógica operativa: Tareas, Notas, Historial Táctico y Seguimiento de Etapas.
 */
public with sharing class OperationsService {

    /**
     * Motor de Historial Consolidado (360°): Captura Tareas, Eventos, Correos, Notas y Archivos.
     * Blindado contra nulos y normalizado para evitar errores de zona horaria en LWC.
     */
    public static List<Map<String, Object>> getTacticalHistory(Id oppId) {
        List<Map<String, Object>> history = new List<Map<String, Object>>();
        if (oppId == null) return history;

        // --- 1. TAREAS Y ACTIVIDADES (Log a Call, Tasks) ---
        for (Task t : [SELECT Id, Subject, Status, Description, TaskSubtype, CreatedDate, Owner.Name 
                        FROM Task WHERE WhatId = :oppId ORDER BY CreatedDate DESC LIMIT 50]) {
            String subType = t.TaskSubtype != null ? t.TaskSubtype : 'Task';
            String icon = subType == 'Call' ? 'standard:log_a_call' : (subType == 'Email' ? 'standard:email' : 'standard:task');
            history.add(new Map<String, Object>{ 
                'id' => t.Id, 'type' => 'Actividad', 'label' => subType, 'subject' => String.isNotBlank(t.Subject) ? t.Subject : '(Sin Asunto)',
                'date' => t.CreatedDate.getTime(), 'icon' => icon, 'desc' => t.Description, 'status' => t.Status, 'isTask' => (subType != 'Email'),
                'owner' => t.Owner != null ? t.Owner.Name : 'Sistema'
            });
        }

        // --- 2. EVENTOS DEL CALENDARIO (Visitas, Reuniones) ---
        for (Event e : [SELECT Id, Subject, Description, StartDateTime, Owner.Name 
                         FROM Event WHERE WhatId = :oppId ORDER BY StartDateTime DESC LIMIT 20]) {
            history.add(new Map<String, Object>{ 
                'id' => e.Id, 'type' => 'Evento', 'label' => 'Calendario', 'subject' => String.isNotBlank(e.Subject) ? e.Subject : 'Cita Agendada',
                'date' => e.StartDateTime.getTime(), 'icon' => 'standard:event', 'desc' => e.Description, 'owner' => e.Owner != null ? e.Owner.Name : 'N/A'
            });
        }

        // --- 3. CORREOS ELECTRÓNICOS (EmailMessages) ---
        for (EmailMessage em : [SELECT Id, Subject, TextBody, MessageDate, FromAddress, ToAddress 
                                 FROM EmailMessage WHERE RelatedToId = :oppId ORDER BY MessageDate DESC LIMIT 20]) {
            history.add(new Map<String, Object>{ 
                'id' => em.Id, 'type' => 'Email', 'label' => 'Correo', 'subject' => em.Subject,
                'date' => em.MessageDate.getTime(), 'icon' => 'standard:email', 'desc' => 'De: ' + em.FromAddress + '\nPara: ' + em.ToAddress, 'owner' => 'Email'
            });
        }

        // --- 4. LEVANTAMIENTOS TÉCNICOS ---
        for (Levantamiento_Tecnico__c lev : [SELECT Id, Name, Tipo_Servicio__c, CreatedDate, CreatedBy.Name 
                                             FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY CreatedDate DESC]) {
            history.add(new Map<String, Object>{ 
                'id' => lev.Id, 'type' => 'Levantamiento', 'label' => 'Técnico', 'subject' => 'Levantamiento: ' + lev.Tipo_Servicio__c, 
                'date' => lev.CreatedDate.getTime(), 'icon' => 'standard:survey', 'desc' => 'Hallazgos registrados en sitio.', 'owner' => lev.CreatedBy.Name
            });
        }

        // --- 5. ARCHIVOS Y NOTAS (ContentDocumentLink) ---
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType, ContentDocument.CreatedDate, ContentDocument.Owner.Name 
                                        FROM ContentDocumentLink WHERE LinkedEntityId = :oppId ORDER BY ContentDocument.CreatedDate DESC LIMIT 30]) {
            String fType = cdl.ContentDocument.FileType;
            String typeLabel = (fType == 'SNOTE') ? 'Nota' : 'Archivo';
            String icon = (fType == 'SNOTE') ? 'standard:note' : ((fType == 'PDF') ? 'doctype:pdf' : (new Set<String>{'PNG','JPG','JPEG'}.contains(fType) ? 'doctype:image' : 'doctype:attachment'));
            
            Map<String, Object> docItem = new Map<String, Object>{
                'id' => cdl.ContentDocumentId, 'type' => typeLabel, 'label' => typeLabel, 'subject' => cdl.ContentDocument.Title,
                'date' => cdl.ContentDocument.CreatedDate.getTime(), 'icon' => icon, 'desc' => 'Documento vinculado al expediente.',
                'owner' => cdl.ContentDocument.Owner != null ? cdl.ContentDocument.Owner.Name : 'N/A'
            };
            if (icon == 'doctype:image') docItem.put('previewUrl', '/sfc/servlet.shepherd/document/download/' + cdl.ContentDocumentId);
            history.add(docItem);
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