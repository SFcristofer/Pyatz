/**
 * Servicio para manejar la lógica de Levantamientos Técnicos.
 * Evolucionado para soportar tablas dinámicas autoconstruidas.
 */
public with sharing class LevantamientoService {

    public static void saveSurveyData(Id oppId, String type, String surveyDataJson, String diagDataJson) {
        try {
            if (String.isBlank(surveyDataJson) || oppId == null) return;
            List<Object> rows = (List<Object>)JSON.deserializeUntyped(surveyDataJson);
            String typeUpper = type.toUpperCase();
            
            // 1. Obtener registros existentes para limpieza inteligente
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
                    Tipo_Servicio__c = typeUpper
                );
                
                if (rowId != null && existingRecords.containsKey(rowId)) {
                    lev.Id = rowId;
                    idsToKeep.add(rowId);
                }

                // --- LÓGICA AGNOSTICA DE CAMPOS (MOTOR DINÁMICO) ---
                // Iteramos sobre todas las llaves del JSON y si coinciden con un campo de Salesforce, lo llenamos.
                for (String key : row.keySet()) {
                    if (key.endsWith('__c')) { // Es un campo de Salesforce
                        try {
                            Object val = row.get(key);
                            // Manejo básico de tipos (String vs Decimal)
                            if (val instanceof String) {
                                lev.put(key, (String)val);
                            } else {
                                lev.put(key, Decimal.valueOf(String.valueOf(val)));
                            }
                        } catch (Exception e) { /* Ignorar errores de mapeo individual */ }
                    }
                }

                // Mantenemos compatibilidad con campos de tablas fijas (alias del LWC)
                mapClassicFields(lev, row, typeUpper);
                
                toUpsert.add(lev);
            }
            
            if (!toUpsert.isEmpty()) upsert toUpsert;
            
            List<Levantamiento_Tecnico__c> toDelete = new List<Levantamiento_Tecnico__c>();
            for (Id existingId : existingRecords.keySet()) {
                if (!idsToKeep.contains(existingId)) toDelete.add(new Levantamiento_Tecnico__c(Id = existingId));
            }
            if (!toDelete.isEmpty()) delete toDelete;

        } catch (Exception e) { throw new AuraHandledException('Error guardado técnico: ' + e.getMessage()); }
    }

    /**
     * Mapeo de campos para las 7 tablas clásicas que usan nombres descriptivos en el LWC.
     */
    private static void mapClassicFields(Levantamiento_Tecnico__c lev, Map<String, Object> row, String type) {
        lev.Nivel__c = (String)row.get('nivel');
        lev.Area_Cocina_Banos__c = (String)row.get('area');
        lev.Zona_Genero__c = (String)row.get('zona');
        lev.Observaciones_Tecnicas__c = (String)row.get('obs');

        if (type == 'BIOENZIMÁTICO') {
            lev.VE__c = getDec(row.get('ve')); lev.VP__c = getDec(row.get('vp'));
            lev.Bidon_10L__c = getDec(row.get('c10l')); lev.Bidon_20L__c = getDec(row.get('c20l')); lev.Bidon_25L__c = getDec(row.get('c25l'));
            lev.Piso__c = getDec(row.get('piso')); lev.Mueble__c = getDec(row.get('mueble')); lev.Pared__c = getDec(row.get('pared'));
            lev.Escamoche__c = (String)row.get('escamoche'); lev.Azolves__c = (String)row.get('azolves');
            lev.Fotografia__c = (String)row.get('foto'); lev.Residuos_Tarja__c = (String)row.get('residuos');
            lev.Estado_Instalacion__c = (String)row.get('instala'); lev.Coladeras__c = getDec(row.get('coladeras'));
            lev.Tapon_Registro__c = getDec(row.get('tapon')); lev.Tarja__c = getDec(row.get('tarja'));
            lev.Tinas_por_Tarja__c = getDec(row.get('tinas')); lev.Trampa_Grasa__c = getDec(row.get('tgrasa'));
            lev.Modelo_TG_Bio__c = (String)row.get('modelo'); lev.ST_1__c = getDec(row.get('st1'));
            lev.Ovalines_Lavabo__c = getDec(row.get('ovalines'));
        } else if (type == 'VACTOR') {
            lev.Vactor_Largo__c = getDec(row.get('largo')); lev.Vactor_Ancho__c = getDec(row.get('ancho')); lev.Vactor_Profundidad__c = getDec(row.get('prof'));
            lev.Vactor_Material__c = (String)row.get('material'); lev.Vactor_Dificultad__c = (String)row.get('dificultad');
            lev.Vactor_Descripcion__c = (String)row.get('descripcion'); lev.Vactor_Medida__c = (String)row.get('medida');
            lev.Vactor_Servicio_Requerido__c = (String)row.get('servicio'); lev.Vactor_Distancia_Camion__c = (String)row.get('distancia');
            lev.Vactor_Permiso_Delegacion__c = (String)row.get('permDelegacion'); lev.Vactor_Permiso_Plaza__c = (String)row.get('permPlaza');
            lev.Vactor_Alcance_Pyatz__c = (String)row.get('alcance');
        } else if (type == 'GRASAS') {
            lev.SP__c = getDec(row.get('sp')); lev.ENT__c = getDec(row.get('ent'));
            lev.Frecuencia_Limpieza__c = (String)row.get('frecuencia'); lev.Estado_Trampa__c = (String)row.get('estado');
            lev.Modelo_Grasas__c = (String)row.get('modelo'); lev.Estado_Instalacion__c = (String)row.get('instala');
            lev.Fotografia__c = (String)row.get('foto');
        } else if (type == 'INTIMA') {
            lev.Tornillo__c = getDec(row.get('tornillo')); lev.Sello__c = getDec(row.get('sello'));
            lev.Mampara__c = getDec(row.get('mampara')); lev.Canastilla__c = getDec(row.get('canastilla'));
            lev.Ret_Salida__c = getDec(row.get('retSalida')); lev.WC__c = getDec(row.get('wc'));
            lev.Estado_Instalacion__c = (String)row.get('instala'); lev.Fotografia__c = (String)row.get('foto');
            lev.Frecuencia__c = (String)row.get('frecuencia'); lev.Dias_Servicio_Censo__c = (String)row.get('dias');
        } else if (type == 'DESAZOLVE MECANICO') {
            lev.WC__c = getDec(row.get('wc')); lev.Mingitorios__c = getDec(row.get('mingitorios'));
            lev.Metros_Lineales__c = getDec(row.get('mtLineal')); lev.Tarjas_Servicios__c = getDec(row.get('tarjas'));
            lev.Cuarto_Humado__c = getDec(row.get('cuartoHumado')); lev.Equipos_ARM__c = getDec(row.get('arm'));
            lev.Ovalines_Lavabo__c = getDec(row.get('ovalines')); lev.Coladeras__c = getDec(row.get('coladeras'));
            lev.Tapon_Registro__c = getDec(row.get('tapon')); lev.SP__c = getDec(row.get('sp'));
            lev.ENT__c = getDec(row.get('ent')); lev.Estado_Instalacion__c = (String)row.get('instala');
            lev.Fotografia__c = (String)row.get('foto');
        } else if (type == 'AROMATIZANTES') {
            lev.WC__c = getDec(row.get('wc')); lev.Estado_Instalacion__c = (String)row.get('instala');
            lev.Fotografia__c = (String)row.get('foto');
        }
    }

    private static Decimal getDec(Object val) {
        return val != null ? Decimal.valueOf(String.valueOf(val)) : 0;
    }

    public static List<Levantamiento_Tecnico__c> getLevantamientoDetails(Id recordId) {
        Id oppId = recordId;
        if (recordId != null && recordId.getSObjectType().getDescribe().getName() == 'Quote') {
            oppId = [SELECT OpportunityId FROM Quote WHERE Id = :recordId].OpportunityId;
        }

        // Construcción Dinámica de SOQL para traer todos los campos (Opción A)
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Levantamiento_Tecnico__c.fields.getMap();
        List<String> fieldNames = new List<String>();
        
        // Siempre traer los campos estándar requeridos
        fieldNames.add('Id');
        fieldNames.add('Name');
        fieldNames.add('CreatedDate');
        
        // Traer todos los campos personalizados (__c)
        for (String fieldName : fieldMap.keySet()) {
            if (fieldName.endsWith('__c')) {
                fieldNames.add(fieldName);
            }
        }
        
        // Evitar duplicados (por si acaso un campo __c se agregó dos veces)
        Set<String> uniqueFields = new Set<String>(fieldNames);
        List<String> queryFields = new List<String>(uniqueFields);
        
        String query = 'SELECT ' + String.join(queryFields, ', ') + 
                       ' FROM Levantamiento_Tecnico__c' + 
                       ' WHERE Oportunidad__c = :oppId' + 
                       ' ORDER BY Tipo_Servicio__c, CreatedDate ASC';

        return Database.query(query);
    }

    public static void processLevantamientos(Id quoteId, String markersBase64) {
        // Mantiene la lógica de sincronización masiva para el editor de cotizaciones
    }
}