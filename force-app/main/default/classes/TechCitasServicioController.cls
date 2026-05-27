public with sharing class TechCitasServicioController {

    public class RevisionInfo {
        @AuraEnabled public Id      id                  {get; set;}
        @AuraEnabled public String  name                {get; set;}
        @AuraEnabled public Decimal numeroRev           {get; set;}
        @AuraEnabled public String  status              {get; set;}
        @AuraEnabled public String  tipoReporte         {get; set;}
        @AuraEnabled public Integer totalFotos          {get; set;}
        @AuraEnabled public Integer totalNoConformidades {get; set;}
    }

    public class CitaWrapper {
        @AuraEnabled public Id                 id                    {get; set;}
        @AuraEnabled public String             appointmentNumber     {get; set;}
        @AuraEnabled public String             zonasTratar           {get; set;}
        @AuraEnabled public String             status                {get; set;}
        @AuraEnabled public Integer            totalRevisiones       {get; set;}
        @AuraEnabled public Integer            revisionesCompletadas {get; set;}
        @AuraEnabled public List<RevisionInfo> revisiones            {get; set;}
    }

    @AuraEnabled(cacheable=true)
    public static List<CitaWrapper> getCitasServicio(Id workOrderId) {
        List<ServiceAppointment> sas = [
            SELECT Id, AppointmentNumber, Status, Zonas_a_Tratar__c
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY AppointmentNumber ASC
        ];

        if (sas.isEmpty()) return new List<CitaWrapper>();

        Set<Id> saIds = new Set<Id>();
        Map<Id, CitaWrapper> wrapBySA = new Map<Id, CitaWrapper>();

        for (ServiceAppointment sa : sas) {
            saIds.add(sa.Id);
            CitaWrapper w           = new CitaWrapper();
            w.id                    = sa.Id;
            w.appointmentNumber     = sa.AppointmentNumber;
            w.zonasTratar           = sa.Zonas_a_Tratar__c;
            w.status                = sa.Status;
            w.totalRevisiones       = 0;
            w.revisionesCompletadas = 0;
            w.revisiones            = new List<RevisionInfo>();
            wrapBySA.put(sa.Id, w);
        }

        Set<Id> revIds = new Set<Id>();
        Map<Id, RevisionInfo> revById = new Map<Id, RevisionInfo>();

        for (Revision_Cita_Servicio__c r : [
            SELECT Id, Name, Numero_Revision__c, Status__c, Cita_Servicio__c,
                   Tipo_Reporte__c, Datos_Formulario__c,
                   Plantilla_de_Formulario__r.Name
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :saIds
            ORDER BY Cita_Servicio__c, Numero_Revision__c ASC NULLS LAST
        ]) {
            CitaWrapper w = wrapBySA.get(r.Cita_Servicio__c);
            if (w == null) continue;

            RevisionInfo ri          = new RevisionInfo();
            ri.id                    = r.Id;
            ri.name                  = r.Name;
            ri.numeroRev             = r.Numero_Revision__c;
            ri.status                = r.Status__c;
            ri.tipoReporte           = r.Plantilla_de_Formulario__r != null
                                        ? r.Plantilla_de_Formulario__r.Name
                                        : r.Tipo_Reporte__c;
            ri.totalFotos            = 0;
            ri.totalNoConformidades  = countNoConformidades(r.Datos_Formulario__c);

            w.revisiones.add(ri);
            w.totalRevisiones++;
            if (r.Status__c == 'Completada') w.revisionesCompletadas++;

            revIds.add(r.Id);
            revById.put(r.Id, ri);
        }

        // ── Contar fotos por revisión ────────────────────────────────────────
        if (!revIds.isEmpty()) {
            Map<Id, Set<Id>> docsByRev = new Map<Id, Set<Id>>();
            Set<Id> allDocIds = new Set<Id>();

            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :revIds
            ]) {
                if (!docsByRev.containsKey(cdl.LinkedEntityId))
                    docsByRev.put(cdl.LinkedEntityId, new Set<Id>());
                docsByRev.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
                allDocIds.add(cdl.ContentDocumentId);
            }

            if (!allDocIds.isEmpty()) {
                Set<Id> geoFotoDocIds = new Set<Id>();
                for (ContentVersion cv : [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :allDocIds
                      AND Title LIKE 'GeoFoto_%'
                      AND IsLatest = true
                ]) {
                    geoFotoDocIds.add(cv.ContentDocumentId);
                }

                for (Id revId : docsByRev.keySet()) {
                    RevisionInfo ri = revById.get(revId);
                    if (ri == null) continue;
                    for (Id docId : docsByRev.get(revId)) {
                        if (geoFotoDocIds.contains(docId)) ri.totalFotos++;
                    }
                }
            }
        }

        List<CitaWrapper> result = new List<CitaWrapper>();
        for (ServiceAppointment sa : sas) result.add(wrapBySA.get(sa.Id));
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getVerificationStatus(Id workOrderId) {
        WorkOrder wo = [
            SELECT Verificado__c, Verificado_Por__c, Fecha_Verificacion__c,
                   Nombre_Firmante__c, Cargo_Firmante__c
            FROM WorkOrder WHERE Id = :workOrderId LIMIT 1
        ];
        String fechaFmt = null;
        if (wo.Fecha_Verificacion__c != null) {
            String[] meses = new String[]{
                'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
            };
            Datetime d = wo.Fecha_Verificacion__c;
            fechaFmt = d.day() + ' / ' + meses[d.month() - 1] + ' / ' + d.year()
                     + ' ' + String.valueOf(d.hour()).leftPad(2,'0')
                     + ':' + String.valueOf(d.minute()).leftPad(2,'0');
        }
        return new Map<String, Object>{
            'verificado'         => wo.Verificado__c,
            'verificadoPor'      => wo.Verificado_Por__c,
            'fechaVerificacion'  => fechaFmt,
            'nombreFirmante'     => wo.Nombre_Firmante__c,
            'cargoFirmante'      => wo.Cargo_Firmante__c
        };
    }

    @AuraEnabled
    public static void verificarODT(Id workOrderId, String nombreFirmante, String cargoFirmante) {
        update new WorkOrder(
            Id                    = workOrderId,
            Verificado__c         = true,
            Verificado_Por__c     = UserInfo.getName(),
            Fecha_Verificacion__c = Datetime.now(),
            Nombre_Firmante__c    = nombreFirmante,
            Cargo_Firmante__c     = cargoFirmante
        );
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getSAHistory(Id saId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            for (ServiceAppointmentHistory h : [
                SELECT CreatedDate, CreatedBy.Name, Field, OldValue, NewValue
                FROM ServiceAppointmentHistory
                WHERE ServiceAppointmentId = :saId
                  AND Field = 'Status'
                ORDER BY CreatedDate DESC
                LIMIT 50
            ]) {
                result.add(new Map<String, Object>{
                    'fecha'    => h.CreatedDate.format('dd/MM/yyyy HH:mm'),
                    'usuario'  => h.CreatedBy.Name,
                    'anterior' => h.OldValue != null ? String.valueOf(h.OldValue) : '—',
                    'nuevo'    => h.NewValue != null ? String.valueOf(h.NewValue) : '—'
                });
            }
        } catch (Exception e) {
            // Historial no disponible o sin permisos
        }
        return result;
    }

    @AuraEnabled
    public static void desverificarODT(Id workOrderId) {
        update new WorkOrder(
            Id                    = workOrderId,
            Verificado__c         = false,
            Verificado_Por__c     = null,
            Fecha_Verificacion__c = null,
            Nombre_Firmante__c    = null,
            Cargo_Firmante__c     = null
        );
    }

    private static Integer countNoConformidades(String jsonStr) {
        if (String.isBlank(jsonStr)) return 0;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
            List<Object> respuestas  = (List<Object>) root.get('respuestas');
            if (respuestas == null) return 0;
            Integer count = 0;
            for (Object obj : respuestas) {
                Map<String, Object> m = (Map<String, Object>) obj;
                if (String.isNotBlank((String) m.get('deficiencia'))) count++;
            }
            return count;
        } catch (Exception e) { return 0; }
    }
}
