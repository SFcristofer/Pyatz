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
}