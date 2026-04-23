/**
 * Controlador para funciones administrativas de Pyatz.
 * Maneja la introspección de campos y la gestión de configuraciones dinámicas.
 */
public with sharing class AdminController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableFields() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Levantamiento_Tecnico__c.fields.getMap();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (dfr.isCustom() && dfr.isUpdateable()) {
                options.add(new Map<String, String>{ 'label' => dfr.getLabel(), 'value' => dfr.getName() });
            }
        }
        return options;
    }

    /**
     * Recupera las configuraciones de tablas dinámicas con sus columnas procesadas.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTableConfigs() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (Configuracion_Tabla_Pyatz__c config : [SELECT Name, Campos_API__c, Etiquetas_Columnas__c, Activa__c 
                                                   FROM Configuracion_Tabla_Pyatz__c 
                                                   ORDER BY Name ASC]) {
            Map<String, Object> c = new Map<String, Object>();
            c.put('label', config.Name);
            c.put('value', config.Name.toUpperCase());
            c.put('fields', config.Campos_API__c != null ? config.Campos_API__c.split(',') : new List<String>());
            c.put('labels', config.Etiquetas_Columnas__c != null ? config.Etiquetas_Columnas__c.split(',') : new List<String>());
            c.put('active', config.Activa__c);
            results.add(c);
        }
        return results;
    }

    /**
     * Guarda permanentemente una configuración de tabla.
     */
    @AuraEnabled
    public static void saveTableConfig(String label, String apiNames, String columnLabels) {
        try {
            Configuracion_Tabla_Pyatz__c config;
            List<Configuracion_Tabla_Pyatz__c> existing = [SELECT Id FROM Configuracion_Tabla_Pyatz__c WHERE Name = :label LIMIT 1];
            
            if (existing.isEmpty()) {
                config = new Configuracion_Tabla_Pyatz__c(Name = label, Activa__c = true);
            } else {
                config = existing[0];
            }
            
            config.Campos_API__c = apiNames;
            config.Etiquetas_Columnas__c = columnLabels;
            upsert config;
        } catch (Exception e) {
            throw new AuraHandledException('Error al guardar diseño: ' + e.getMessage());
        }
    }

    /**
     * Desactiva lógicamente una configuración de tabla para que no aparezca en nuevas selecciones.
     */
    @AuraEnabled
    public static void toggleTableStatus(String label, Boolean isActive) {
        try {
            Configuracion_Tabla_Pyatz__c config = [SELECT Id FROM Configuracion_Tabla_Pyatz__c WHERE Name = :label LIMIT 1];
            config.Activa__c = isActive;
            update config;
        } catch (Exception e) {
            throw new AuraHandledException('Error al cambiar estado: ' + e.getMessage());
        }
    }
}