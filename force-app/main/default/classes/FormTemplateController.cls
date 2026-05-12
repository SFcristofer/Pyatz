public with sharing class FormTemplateController {

    // ─── Inner classes ─────────────────────────────────────────────────────────

    public class TemplateMetadata {
        @AuraEnabled public String  tipo;
        @AuraEnabled public String  icono;
        @AuraEnabled public Integer questionCount;
        @AuraEnabled public Boolean hasTemplate;
        @AuraEnabled public Boolean activo;
        @AuraEnabled public Integer orden;
        @AuraEnabled public String  id;
    }

    public class TemplateDetail {
        @AuraEnabled public String  id;
        @AuraEnabled public String  tipo;
        @AuraEnabled public String  icono;
        @AuraEnabled public String  preguntas;
        @AuraEnabled public Boolean activo;
        @AuraEnabled public Integer orden;
    }

    // ─── Lectura para el técnico ───────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<TemplateMetadata> getFormTemplates() {
        List<TemplateMetadata> result = new List<TemplateMetadata>();
        for (Form_Template__c t : [
            SELECT Id, Tipo_Reporte__c, Icono__c, Preguntas__c, Activo__c, Orden__c
            FROM Form_Template__c
            WHERE Activo__c = true
            ORDER BY Orden__c ASC NULLS LAST, Tipo_Reporte__c ASC
        ]) {
            TemplateMetadata m = new TemplateMetadata();
            m.id            = t.Id;
            m.tipo          = t.Tipo_Reporte__c;
            m.icono         = String.isNotBlank(t.Icono__c) ? t.Icono__c : 'utility:form';
            m.activo        = t.Activo__c;
            m.orden         = t.Orden__c != null ? Integer.valueOf(t.Orden__c) : 99;
            m.hasTemplate   = String.isNotBlank(t.Preguntas__c) && t.Preguntas__c != '[]';
            m.questionCount = countQuestions(t.Preguntas__c);
            result.add(m);
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static String getFormTemplate(String tipoReporte) {
        if (String.isBlank(tipoReporte)) return '[]';
        
        List<Form_Template__c> rows;
        if (tipoReporte instanceof Id) {
            rows = [SELECT Preguntas__c FROM Form_Template__c WHERE Id = :tipoReporte AND Activo__c = true LIMIT 1];
        } else {
            rows = [SELECT Preguntas__c FROM Form_Template__c WHERE Tipo_Reporte__c = :tipoReporte AND Activo__c = true LIMIT 1];
        }
        
        if (rows.isEmpty() || String.isBlank(rows[0].Preguntas__c)) return '[]';
        return rows[0].Preguntas__c;
    }

    // ─── CRUD para el admin ────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<TemplateDetail> getAllTemplatesAdmin() {
        List<TemplateDetail> result = new List<TemplateDetail>();
        for (Form_Template__c t : [
            SELECT Id, Name, Tipo_Reporte__c, Icono__c, Preguntas__c, Activo__c, Orden__c
            FROM Form_Template__c
            ORDER BY Orden__c ASC NULLS LAST, Tipo_Reporte__c ASC
        ]) {
            result.add(toDetail(t));
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static TemplateDetail getTemplateById(String templateId) {
        Form_Template__c t = [
            SELECT Id, Name, Tipo_Reporte__c, Icono__c, Preguntas__c, Activo__c, Orden__c
            FROM Form_Template__c
            WHERE Id = :templateId
            LIMIT 1
        ];
        return toDetail(t);
    }

    @AuraEnabled
    public static String upsertTemplate(String templateId, String tipo, String preguntas,
                                        String icono, Integer orden, Boolean activo) {
        Form_Template__c t;
        if (String.isNotBlank(templateId)) {
            t = [SELECT Id FROM Form_Template__c WHERE Id = :templateId LIMIT 1];
        } else {
            t = new Form_Template__c();
            t.Name = tipo;
        }
        t.Tipo_Reporte__c = tipo;
        t.Preguntas__c    = preguntas;
        t.Icono__c        = icono;
        t.Orden__c        = orden;
        t.Activo__c       = activo != null ? activo : true;
        upsert t;
        return t.Id;
    }

    @AuraEnabled
    public static void deleteTemplate(String templateId) {
        delete [SELECT Id FROM Form_Template__c WHERE Id = :templateId LIMIT 1];
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private static TemplateDetail toDetail(Form_Template__c t) {
        TemplateDetail d = new TemplateDetail();
        d.id       = t.Id;
        d.tipo     = t.Tipo_Reporte__c;
        d.icono    = t.Icono__c;
        d.preguntas = String.isNotBlank(t.Preguntas__c) ? t.Preguntas__c : '[]';
        d.activo   = t.Activo__c;
        d.orden    = t.Orden__c != null ? Integer.valueOf(t.Orden__c) : 99;
        return d;
    }

    private static Integer countQuestions(String preguntasJson) {
        if (String.isBlank(preguntasJson) || preguntasJson == '[]') return 0;
        try {
            List<Object> arr = (List<Object>) JSON.deserializeUntyped(preguntasJson);
            return arr.size();
        } catch (Exception e) { return 0; }
    }
}