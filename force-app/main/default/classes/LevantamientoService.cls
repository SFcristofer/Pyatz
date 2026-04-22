/**
 * @description Clase de servicio para manejar la lógica de Levantamientos Técnicos (Vactor, RME, Gestión Menstrual, etc.)
 *              Extraída de QuoteTechnicalController para mejorar la mantenibilidad.
 */
public with sharing class LevantamientoService {

    /**
     * Guarda los datos de un levantamiento integral desde el LWC techLevantamientoManager.
     */
    public static void saveSurveyData(Id oppId, String type, String surveyDataJson, String diagDataJson) {
        try {
            if (String.isBlank(surveyDataJson) || oppId == null) return;
            List<Object> rows = (List<Object>)JSON.deserializeUntyped(surveyDataJson);
            Map<String, Object> diag = String.isNotBlank(diagDataJson) ? (Map<String, Object>)JSON.deserializeUntyped(diagDataJson) : new Map<String, Object>();
            String typeUpper = type.toUpperCase();
            
            Map<Id, Levantamiento_Tecnico__c> existingRecords = new Map<Id, Levantamiento_Tecnico__c>(
                [SELECT Id FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId AND Tipo_Servicio__c = :typeUpper]
            );
            
            List<Levantamiento_Tecnico__c> toUpsert = new List<Levantamiento_Tecnico__c>();
            Set<Id> idsToKeep = new Set<Id>();

            for (Object obj : rows) {
                Map<String, Object> row = (Map<String, Object>)obj;
                String rawId = (row.get('id') != null) ? String.valueOf(row.get('id')) : null;
                Id rowId = null;
                
                if (String.isNotBlank(rawId) && (rawId.length() == 15 || rawId.length() == 18) && !rawId.contains('.')) {
                    try { rowId = (Id)rawId; } catch (Exception e) { rowId = null; }
                }
                
                Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(
                    Oportunidad__c = oppId,
                    Tipo_Servicio__c = typeUpper,
                    Nivel__c = (String)row.get('nivel'),
                    Area_Cocina_Banos__c = (String)row.get('area'),
                    Zona_Genero__c = (String)row.get('zona'),
                    Observaciones_Tecnicas__c = (String)row.get('obs')
                );
                
                if (rowId != null && existingRecords.containsKey(rowId)) {
                    lev.Id = rowId;
                    idsToKeep.add(rowId);
                }

                if (typeUpper == 'BIOENZIMÁTICO') {
                    lev.VE__c = row.get('ve') != null ? Decimal.valueOf(String.valueOf(row.get('ve'))) : 0;
                    lev.VP__c = row.get('vp') != null ? Decimal.valueOf(String.valueOf(row.get('vp'))) : 0;
                    lev.Bidon_10L__c = row.get('c10l') != null ? Decimal.valueOf(String.valueOf(row.get('c10l'))) : 0;
                    lev.Bidon_20L__c = row.get('c20l') != null ? Decimal.valueOf(String.valueOf(row.get('c20l'))) : 0;
                    lev.Bidon_25L__c = row.get('c25l') != null ? Decimal.valueOf(String.valueOf(row.get('c25l'))) : 0;
                    lev.Piso__c = row.get('piso') != null ? Decimal.valueOf(String.valueOf(row.get('piso'))) : 0;
                    lev.Mueble__c = row.get('mueble') != null ? Decimal.valueOf(String.valueOf(row.get('mueble'))) : 0;
                    lev.Pared__c = row.get('pared') != null ? Decimal.valueOf(String.valueOf(row.get('pared'))) : 0;
                    lev.Residuos_Tarja__c = (String)row.get('residuos');
                    lev.Escamoche__c = (String)row.get('escamoche');
                    lev.Estado_Instalacion__c = (String)row.get('instala');
                    lev.Azolves__c = (String)row.get('azolves');
                    lev.Coladeras__c = row.get('coladeras') != null ? Decimal.valueOf(String.valueOf(row.get('coladeras'))) : 0;
                    lev.Tapon_Registro__c = row.get('tapon') != null ? Decimal.valueOf(String.valueOf(row.get('tapon'))) : 0;
                    lev.Tarja__c = row.get('tarja') != null ? Decimal.valueOf(String.valueOf(row.get('tarja'))) : 0;
                    lev.Tinas_por_Tarja__c = row.get('tinas') != null ? Decimal.valueOf(String.valueOf(row.get('tinas'))) : 0;
                    lev.Trampa_Grasa__c = row.get('tgrasa') != null ? Decimal.valueOf(String.valueOf(row.get('tgrasa'))) : 0;
                    lev.Modelo_TG_Bio__c = (String)row.get('modelo');
                    lev.ST_1__c = row.get('st1') != null ? Decimal.valueOf(String.valueOf(row.get('st1'))) : 0;
                    lev.Ovalines_Lavabo__c = row.get('ovalines') != null ? Decimal.valueOf(String.valueOf(row.get('ovalines'))) : 0;
                }
                else if (typeUpper == 'GRASAS') {
                    lev.SP__c = row.get('sp') != null ? Decimal.valueOf(String.valueOf(row.get('sp'))) : 0;
                    lev.ENT__c = row.get('ent') != null ? Decimal.valueOf(String.valueOf(row.get('ent'))) : 0;
                    lev.Modelo_Grasas__c = (String)row.get('modelo');
                    lev.Frecuencia_Limpieza__c = (String)row.get('frecuencia');
                    lev.Estado_Trampa__c = (String)row.get('estado');
                    lev.Tornillo__c = row.get('tornillo') != null ? Decimal.valueOf(String.valueOf(row.get('tornillo'))) : 0;
                    lev.Sello__c = row.get('sello') != null ? Decimal.valueOf(String.valueOf(row.get('sello'))) : 0;
                    lev.Mampara__c = row.get('mampara') != null ? Decimal.valueOf(String.valueOf(row.get('mampara'))) : 0;
                    lev.Canastilla__c = row.get('canastilla') != null ? Decimal.valueOf(String.valueOf(row.get('canastilla'))) : 0;
                    lev.Ret_Salida__c = row.get('retSalida') != null ? Decimal.valueOf(String.valueOf(row.get('retSalida'))) : 0;
                }
                else if (typeUpper == 'INTIMA') {
                    lev.WC__c = row.get('wc') != null ? Decimal.valueOf(String.valueOf(row.get('wc'))) : 0;
                    lev.Frecuencia__c = (String)row.get('frecuencia');
                    lev.Dias_Servicio_Censo__c = (String)row.get('dias');
                    lev.GM_Usuarias_Internas__c = diag.get('gmUsuariasInt') != null ? Decimal.valueOf(String.valueOf(diag.get('gmUsuariasInt'))) : 0;
                    lev.GM_Usuarias_Externas__c = diag.get('gmUsuariasExt') != null ? Decimal.valueOf(String.valueOf(diag.get('gmUsuariasExt'))) : 0;
                    lev.GM_Frecuencia_Uso__c = (String)diag.get('gmFreqUso');
                    lev.GM_Sanitarios_Totales__c = diag.get('gmSanitarios') != null ? Decimal.valueOf(String.valueOf(diag.get('gmSanitarios'))) : 0;
                    lev.GM_Cubiculos_Totales__c = diag.get('gmCubiculos') != null ? Decimal.valueOf(String.valueOf(diag.get('gmCubiculos'))) : 0;
                    lev.GM_Contenedores_Sugeridos__c = diag.get('gmContSugeridos') != null ? Decimal.valueOf(String.valueOf(diag.get('gmContSugeridos'))) : 0;
                    lev.GM_Frecuencia_Recoleccion__c = (String)diag.get('gmFreqRec');
                    lev.GM_Dias_Servicio__c = (String)diag.get('gmDiasServ');
                    lev.GM_Horario_Servicio__c = (String)diag.get('gmHorario');
                    lev.GM_Permisos_Acceso__c = (String)diag.get('gmPermisos');
                    lev.GM_Consideraciones_Especiales__c = (String)diag.get('gmConsideraciones');
                    lev.GM_Requiere_Capacitacion__c = (String)diag.get('gmCapacitacion');
                    lev.GM_Presupuesto_Asignado__c = (String)diag.get('gmPresupuesto');
                    lev.GM_Motivo_Necesidad__c = (String)diag.get('gmMotivo');
                    lev.GM_Permite_Levantamiento_Foto__c = (String)diag.get('gmPermiteLev');
                }
                else if (typeUpper == 'DESAZOLVE MECANICO') {
                    lev.Ovalines_Lavabo__c = row.get('ovalines') != null ? Decimal.valueOf(String.valueOf(row.get('ovalines'))) : 0;
                    lev.Coladeras__c = row.get('coladeras') != null ? Decimal.valueOf(String.valueOf(row.get('coladeras'))) : 0;
                    lev.Tapon_Registro__c = row.get('tapon') != null ? Decimal.valueOf(String.valueOf(row.get('tapon'))) : 0;
                    lev.Mingitorios__c = row.get('mingitorios') != null ? Decimal.valueOf(String.valueOf(row.get('mingitorios'))) : 0;
                    lev.WC__c = row.get('wc') != null ? Decimal.valueOf(String.valueOf(row.get('wc'))) : 0;
                    lev.Metros_Lineales__c = row.get('mtLineal') != null ? Decimal.valueOf(String.valueOf(row.get('mtLineal'))) : 0;
                    lev.Tarjas_Servicios__c = row.get('tarjas') != null ? Decimal.valueOf(String.valueOf(row.get('tarjas'))) : 0;
                    lev.Cuarto_Humado__c = row.get('cuartoHumado') != null ? Decimal.valueOf(String.valueOf(row.get('cuartoHumado'))) : 0;
                }
                else if (typeUpper == 'AROMATIZANTES') {
                    lev.Equipos_ARM__c = row.get('arm') != null ? Decimal.valueOf(String.valueOf(row.get('arm'))) : 0;
                }
                else if (typeUpper == 'VACTOR') {
                    lev.Vactor_Descripcion__c = (String)row.get('descripcion');
                    lev.Vactor_Medida__c = (String)row.get('medida');
                    lev.Vactor_Material__c = (String)row.get('material');
                    lev.Vactor_Servicio_Requerido__c = (String)row.get('servicio');
                    lev.Vactor_Largo__c = row.get('largo') != null ? Decimal.valueOf(String.valueOf(row.get('largo'))) : 0;
                    lev.Vactor_Ancho__c = row.get('ancho') != null ? Decimal.valueOf(String.valueOf(row.get('ancho'))) : 0;
                    lev.Vactor_Profundidad__c = row.get('prof') != null ? Decimal.valueOf(String.valueOf(row.get('prof'))) : 0;
                    lev.Metros_Lineales__c = row.get('mtLineal') != null ? Decimal.valueOf(String.valueOf(row.get('mtLineal'))) : 0;
                    lev.Vactor_Distancia_Camion__c = (String)row.get('distancia');
                    lev.Vactor_Permiso_Delegacion__c = (String)row.get('permDelegacion');
                    lev.Vactor_Permiso_Plaza__c = (String)row.get('permPlaza');
                    lev.Vactor_Dificultad__c = (String)row.get('dificultad');
                    lev.Vactor_Alcance_Pyatz__c = (String)row.get('alcance');
                }
                
                toUpsert.add(lev);
            }
            
            if (!toUpsert.isEmpty()) upsert toUpsert;
            
            List<Levantamiento_Tecnico__c> toDelete = new List<Levantamiento_Tecnico__c>();
            for (Id existingId : existingRecords.keySet()) {
                if (!idsToKeep.contains(existingId)) toDelete.add(new Levantamiento_Tecnico__c(Id = existingId));
            }
            if (!toDelete.isEmpty()) delete toDelete;

        } catch (Exception e) { throw new AuraHandledException('Error levantamiento integral: ' + e.getMessage()); }
    }

    /**
     * Recupera los detalles de levantamiento para una Cotización u Oportunidad.
     */
    public static List<Levantamiento_Tecnico__c> getLevantamientoDetails(Id recordId) {
        try {
            Id oppId = recordId;
            if (recordId != null && recordId.getSObjectType().getDescribe().getName() == 'Quote') {
                oppId = [SELECT OpportunityId FROM Quote WHERE Id = :recordId].OpportunityId;
            }
            return [SELECT Id, Name, Tipo_Servicio__c, Nivel__c, Area_Cocina_Banos__c, Zona_Genero__c, Cantidad_Principal__c, Estado_Instalacion__c, Frecuencia__c, Metros_Lineales__c, Observaciones_Tecnicas__c, Memoria_Descriptiva__c, CreatedDate,
                    VE__c, VP__c, Bidon_10L__c, Bidon_20L__c, Bidon_25L__c, Piso__c, Mueble__c, Pared__c, Fotografia__c, Residuos_Tarja__c, Escamoche__c, Instalaciones__c, Azolves__c, Coladeras__c, Tapon_Registro__c, Tarja__c, Tinas_por_Tarja__c, Trampa_Grasa__c, Modelo_TG_Bio__c, ST_1__c, Ovalines_Lavabo__c,
                    SP__c, ENT__c, Modelo_Grasas__c, Frecuencia_Limpieza__c, Estado_Trampa__c, Tornillo__c, Sello__c, Mampara__c, Canastilla__c, Ret_Salida__c,
                    GM_Usuarias_Internas__c, GM_Usuarias_Externas__c, GM_Frecuencia_Uso__c, GM_Sanitarios_Totales__c, GM_Cubiculos_Totales__c, GM_Contenedores_Sugeridos__c, GM_Frecuencia_Recoleccion__c, GM_Dias_Servicio__c, GM_Horario_Servicio__c, GM_Permisos_Acceso__c, GM_Consideraciones_Especiales__c, GM_Requiere_Capacitacion__c, GM_Presupuesto_Asignado__c, GM_Motivo_Necesidad__c, GM_Permite_Levantamiento_Foto__c,
                    WC__c, Dias_Servicio_Censo__c, Mingitorios__c, Tarjas_Servicios__c, Cuarto_Humado__c, Equipos_ARM__c,
                    Vactor_Descripcion__c, Vactor_Medida__c, Vactor_Material__c, Vactor_Servicio_Requerido__c, Vactor_Largo__c, Vactor_Ancho__c, Vactor_Profundidad__c, Vactor_Distancia_Camion__c, Vactor_Permiso_Delegacion__c, Vactor_Permiso_Plaza__c, Vactor_Dificultad__c, Vactor_Alcance_Pyatz__c,
                    (SELECT Id FROM Soluciones_Tecnicas__r LIMIT 1) 
                    FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId ORDER BY Tipo_Servicio__c, CreatedDate ASC];
        } catch (Exception e) { throw new AuraHandledException(e.getMessage()); }
    }

    /**
     * Procesa la sincronización de levantamientos basada en los markers de la Cotización.
     */
    public static void processLevantamientos(Id quoteId, String markersBase64) {
        try {
            Id oppId = [SELECT OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1].OpportunityId;
            String jsonStr = EncodingUtil.urlDecode(EncodingUtil.base64Decode(markersBase64).toString(), 'UTF-8');
            Map<String, Object> markers = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
            if (!markers.containsKey('surveyData')) return;
            List<Object> rows = (List<Object>)markers.get('surveyData');
            String type = markers.containsKey('surveyType') ? (String)markers.get('surveyType') : '';
            
            // Mantenemos la lógica de borrar registros asociados al presupuesto específico antes de recrearlos
            delete [SELECT Id FROM Levantamiento_Tecnico__c WHERE Presupuesto__c = :quoteId];
            
            List<Levantamiento_Tecnico__c> records = new List<Levantamiento_Tecnico__c>();
            for (Object obj : rows) {
                Map<String, Object> r = (Map<String, Object>)obj;
                Levantamiento_Tecnico__c lev = new Levantamiento_Tecnico__c(
                    Presupuesto__c = quoteId, 
                    Oportunidad__c = oppId, 
                    Tipo_Servicio__c = type.toUpperCase(), 
                    Nivel__c = (String)r.get('nivel'), 
                    Area_Cocina_Banos__c = (String)r.get('area'), 
                    Zona_Genero__c = (String)r.get('zona'), 
                    Observaciones_Tecnicas__c = (String)r.get('obs')
                );
                
                if (type.equalsIgnoreCase('Bioenzimatico')) {
                    lev.Cantidad_Principal__c = (r.get('ve') != null) ? Decimal.valueOf(String.valueOf(r.get('ve'))) : 0;
                    lev.Estado_Instalacion__c = (String)r.get('instala');
                }
                else if (type.equalsIgnoreCase('Grasas')) {
                    lev.Estado_Instalacion__c = (String)r.get('estado');
                    lev.Frecuencia__c = (String)r.get('frecuencia');
                }
                else if (type.equalsIgnoreCase('Intima')) {
                    lev.Cantidad_Principal__c = (r.get('wc') != null) ? Decimal.valueOf(String.valueOf(r.get('wc'))) : 0;
                }
                records.add(lev);
            }
            if (!records.isEmpty()) insert records;
        } catch (Exception e) {
            System.debug('Error en processLevantamientos: ' + e.getMessage());
        }
    }
}
