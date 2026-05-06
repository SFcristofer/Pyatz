/**
 * Servicio encargado de la lógica técnica: Soluciones, Memorias y Sincronización de Levantamientos.
 */
public with sharing class SurveyService {

    public static List<Map<String, Object>> getOpportunitySolutions(Id oppId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Levantamiento_Tecnico__c l : [SELECT Id, Name, Tipo_Servicio__c, Area_Cocina_Banos__c, Nivel__c, (SELECT Id, Name, Descripcion_Detallada__c, Observaciones_Comerciales__c FROM Soluciones_Tecnicas__r ORDER BY CreatedDate ASC) FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY Tipo_Servicio__c, CreatedDate ASC]) {
            if (l.Soluciones_Tecnicas__r.isEmpty()) continue;
            Map<String, Object> levMap = new Map<String, Object>{'id' => l.Id, 'name' => l.Name, 'label' => l.Tipo_Servicio__c + ' - ' + (l.Area_Cocina_Banos__c != null ? l.Area_Cocina_Banos__c : l.Nivel__c)};
            List<Map<String, Object>> solList = new List<Map<String, Object>>();
            for (Solucion_Tecnica__c s : l.Soluciones_Tecnicas__r) solList.add(new Map<String, Object>{'id' => s.Id, 'name' => s.Name, 'techDesc' => s.Descripcion_Detallada__c, 'commObs' => s.Observaciones_Comerciales__c});
            levMap.put('solutions', solList); result.add(levMap);
        }
        return result;
    }

    public static Id saveSolucion(Id levantamientoId, Id solucionId, String nombre, String descripcion, String observaciones) {
        Solucion_Tecnica__c sol = new Solucion_Tecnica__c(Id = solucionId, Levantamiento_Tecnico__c = (solucionId == null ? levantamientoId : null), Name = nombre, Descripcion_Detallada__c = descripcion, Observaciones_Comerciales__c = observaciones);
        upsert sol; return sol.Id;
    }

    public static void deleteSolucion(Id solucionId) {
        delete [SELECT Id FROM Solucion_Tecnica__c WHERE Id = :solucionId];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getInspectionQuestions(String serviceType) {
        List<Map<String, Object>> questions = new List<Map<String, Object>>();
        for (Plantilla_Inspeccion__mdt q : [SELECT Orden__c, Pregunta__c, Respuesta_Esperada__c, Area_Oportunidad__c 
                                           FROM Plantilla_Inspeccion__mdt 
                                           WHERE Tipo_Servicio__c = :serviceType 
                                           ORDER BY Orden__c ASC]) {
            questions.add(new Map<String, Object>{
                'order' => q.Orden__c,
                'question' => q.Pregunta__c,
                'expected' => q.Respuesta_Esperada__c,
                'deficiency' => q.Area_Oportunidad__c
            });
        }
        return questions;
    }

    @AuraEnabled
    public static void saveInspectionResult(Id saId, String payloadJson, String deficiencies) {
        try {
            Inspeccion_Tecnica__c it = [SELECT Id FROM Inspeccion_Tecnica__c WHERE Cita_Servicio__c = :saId LIMIT 1];
            it.Respuestas_JSON__c = payloadJson;
            it.Deficiencias_Detectadas__c = deficiencies;
            update it;
        } catch (Exception e) {
            throw new AuraHandledException('Error al guardar inspección: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInspectionData(Id saId) {
        if (saId == null) return new Map<String, Object>();
        try {
            ServiceAppointment sa = [SELECT Id, Subject, AppointmentNumber, WorkTypeId, (SELECT Id, Tipo_Reporte__c, Respuestas_JSON__c, Levantamiento_Tecnico__r.Tipo_Servicio__c FROM Inspecciones_Tecnicas__r LIMIT 1) 
                                   FROM ServiceAppointment WHERE Id = :saId LIMIT 1];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('saNumber', sa.AppointmentNumber);
            result.put('saSubject', sa.Subject);
            
            if (!sa.Inspecciones_Tecnicas__r.isEmpty()) {
                Inspeccion_Tecnica__c insp = sa.Inspecciones_Tecnicas__r[0];
                result.put('inspectionId', insp.Id);
                
                String rType = insp.Tipo_Reporte__c;
                if (String.isBlank(rType) && insp.Levantamiento_Tecnico__c != null) {
                    rType = insp.Levantamiento_Tecnico__r.Tipo_Servicio__c;
                }
                
                result.put('reportType', rType);
                result.put('existingData', insp.Respuestas_JSON__c);
            }
            return result;
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    @AuraEnabled
    public static void tagLatestPhotos(Id recordId, String tag) {
        try {
            // Buscamos archivos subidos en los últimos 5 minutos a este registro
            Datetime window = Datetime.now().addMinutes(-5);
            List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
            if (links.isEmpty()) return;
            
            Set<Id> docIds = new Set<Id>();
            for(ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);
            
            List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE ContentDocumentId IN :docIds AND CreatedDate >= :window AND IsLatest = true];
            List<ContentVersion> toUpdate = new List<ContentVersion>();
            
            for(ContentVersion cv : cvs) {
                if(!cv.Title.startsWith('[') ) {
                    cv.Title = '[' + tag.toUpperCase() + '] ' + cv.Title;
                    toUpdate.add(cv);
                }
            }
            if(!toUpdate.isEmpty()) update toUpdate;
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }
}