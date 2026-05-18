public with sharing class ServiceReviewController {

    // ─── Inner classes ────────────────────────────────────────────────────────

    public class SAInfo {
        @AuraEnabled public String  saId;
        @AuraEnabled public String  saNumber;
        @AuraEnabled public String  saStatus;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  workOrderNumber;
        @AuraEnabled public String  workOrderId;
        @AuraEnabled public Decimal maxRevisiones;
        @AuraEnabled public Integer revisionesCompletadas;
        @AuraEnabled public Integer revisionesTotales;
        @AuraEnabled public Boolean canCreateRevision;
        @AuraEnabled public List<RevisionSummary> revisionesList;
        @AuraEnabled public String  techName;
        @AuraEnabled public String  techInitials;
    }

    public class RevisionSummary {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public Integer numero;
        @AuraEnabled public String  tipo;
        @AuraEnabled public String  status;
        @AuraEnabled public String  fecha;
        @AuraEnabled public String  tecnico;
        @AuraEnabled public Boolean isCompleted;
        @AuraEnabled public Integer photoCount;
        @AuraEnabled public Boolean hasFirma;
        @AuraEnabled public String  plantillaNombre;
    }

    public class PhotoInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String thumbBase64;
        @AuraEnabled public String createdDate;
    }

    // ─── SA Info ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static SAInfo getServiceAppointmentInfo(Id saId) {
        ServiceAppointment sa = [
            SELECT Id, AppointmentNumber, Status, Subject,
                   ParentRecordId, Revisiones__c
            FROM ServiceAppointment
            WHERE Id = :saId
            LIMIT 1
        ];

        String accountName   = '';
        String workOrderNum  = '';
        if (sa.ParentRecordId != null) {
            try {
                WorkOrder wo = [
                    SELECT Id, WorkOrderNumber, Account.Name
                    FROM WorkOrder
                    WHERE Id = :sa.ParentRecordId
                    LIMIT 1
                ];
                accountName  = wo.Account != null ? wo.Account.Name : '';
                workOrderNum = wo.WorkOrderNumber;
            } catch (Exception e) { /* WO not accessible */ }
        }

        List<Revision_Cita_Servicio__c> revs = [
            SELECT Id, Name, Numero_Revision__c, Tipo_Reporte__c,
                   Status__c, Fecha_Revision__c, Tecnico__r.Name,
                   Plantilla_de_Formulario__r.Tipo_Reporte__c
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :saId
            ORDER BY Numero_Revision__c ASC NULLS LAST
        ];

        // ── Photos & signature counts per revision ────────────────────────────
        Set<Id> revIds = new Set<Id>();
        for (Revision_Cita_Servicio__c r : revs) revIds.add(r.Id);

        Map<Id, Integer> photoCountMap = new Map<Id, Integer>();
        Map<Id, Boolean> hasFirmaMap   = new Map<Id, Boolean>();
        for (Id rid : revIds) { photoCountMap.put(rid, 0); hasFirmaMap.put(rid, false); }

        if (!revIds.isEmpty()) {
            List<ContentDocumentLink> cdls = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :revIds
            ];
            if (!cdls.isEmpty()) {
                Map<Id, Id> docToRev = new Map<Id, Id>();
                for (ContentDocumentLink cdl : cdls) docToRev.put(cdl.ContentDocumentId, cdl.LinkedEntityId);

                for (ContentVersion cv : [
                    SELECT ContentDocumentId, Title
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docToRev.keySet()
                      AND IsLatest = true
                ]) {
                    Id rid = docToRev.get(cv.ContentDocumentId);
                    if (rid == null) continue;
                    String t = cv.Title;
                    if (t.startsWith('GeoFoto_') && !t.startsWith('Thumb_')) {
                        photoCountMap.put(rid, photoCountMap.get(rid) + 1);
                    } else if (t.startsWith('Firma_') && !t.startsWith('Thumb_')) {
                        hasFirmaMap.put(rid, true);
                    }
                }
            }
        }
        // ─────────────────────────────────────────────────────────────────────

        Integer completadas = 0;
        List<RevisionSummary> revList = new List<RevisionSummary>();
        for (Revision_Cita_Servicio__c r : revs) {
            RevisionSummary rs = new RevisionSummary();
            rs.id          = r.Id;
            rs.name        = r.Name;
            rs.numero      = r.Numero_Revision__c != null ? Integer.valueOf(r.Numero_Revision__c) : 0;
            rs.tipo        = r.Tipo_Reporte__c;
            rs.status      = r.Status__c;
            rs.isCompleted = r.Status__c == 'Completada';
            rs.fecha       = r.Fecha_Revision__c != null
                ? r.Fecha_Revision__c.format('dd/MM/yyyy HH:mm')
                : '';
            rs.tecnico        = r.Tecnico__r != null ? r.Tecnico__r.Name : '';
            rs.photoCount     = photoCountMap.get(r.Id);
            rs.hasFirma       = hasFirmaMap.get(r.Id);
            rs.plantillaNombre = r.Plantilla_de_Formulario__r != null
                && r.Plantilla_de_Formulario__r.Tipo_Reporte__c != null
                ? r.Plantilla_de_Formulario__r.Tipo_Reporte__c : '';
            revList.add(rs);
            if (r.Status__c == 'Completada') completadas++;
        }

        User u = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String techName = u.Name;
        String techInitials = buildInitials(techName);

        SAInfo info = new SAInfo();
        info.saId                  = sa.Id;
        info.saNumber              = sa.AppointmentNumber;
        info.saStatus              = sa.Status;
        info.subject               = sa.Subject;
        info.accountName           = accountName;
        info.workOrderNumber       = workOrderNum;
        info.workOrderId           = sa.ParentRecordId;
        info.maxRevisiones         = sa.Revisiones__c != null ? sa.Revisiones__c : 0;
        info.revisionesCompletadas = completadas;
        info.revisionesTotales     = revList.size();
        info.canCreateRevision     = true;
        info.revisionesList        = revList;
        info.techName              = techName;
        info.techInitials          = techInitials;
        return info;
    }

    // ─── Revision CRUD ────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static Map<String, String> getRevisionData(Id revisionId) {
        Revision_Cita_Servicio__c rev = [
            SELECT Id, Tipo_Reporte__c, Datos_Formulario__c, Observaciones__c, Status__c,
                   Plantilla_de_Formulario__c, Plantilla_de_Formulario__r.Tipo_Reporte__c
            FROM Revision_Cita_Servicio__c
            WHERE Id = :revisionId
            LIMIT 1
        ];
        Map<String, String> result = new Map<String, String>();
        result.put('tipoReporte',      rev.Tipo_Reporte__c     != null ? rev.Tipo_Reporte__c     : '');
        result.put('datosFormulario',  rev.Datos_Formulario__c != null ? rev.Datos_Formulario__c : '');
        result.put('observaciones',    rev.Observaciones__c   != null ? rev.Observaciones__c   : '');
        result.put('status',           rev.Status__c          != null ? rev.Status__c          : '');
        result.put('plantillaId',      rev.Plantilla_de_Formulario__c != null
                                            ? String.valueOf(rev.Plantilla_de_Formulario__c) : '');
        result.put('plantillaNombre',  rev.Plantilla_de_Formulario__r != null
                                       && rev.Plantilla_de_Formulario__r.Tipo_Reporte__c != null
                                            ? rev.Plantilla_de_Formulario__r.Tipo_Reporte__c : '');
        return result;
    }

    @AuraEnabled
    public static void setRevisionTemplate(Id revisionId, Id templateId) {
        update new Revision_Cita_Servicio__c(
            Id = revisionId,
            Plantilla_de_Formulario__c = templateId
        );
    }

    @AuraEnabled
    public static Id createRevision(Id saId, Integer revisionNumber) {
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c();
        rev.Cita_Servicio__c    = saId;
        rev.Numero_Revision__c  = revisionNumber;
        rev.Status__c           = 'En Proceso';
        rev.Fecha_Revision__c   = Datetime.now();
        rev.Tecnico__c          = UserInfo.getUserId();
        insert rev;
        return rev.Id;
    }

    @AuraEnabled
    public static void saveRevisionData(Id revisionId, String tipoReporte, String datosFormulario, String observaciones) {
        Revision_Cita_Servicio__c rev = [
            SELECT Id, Cita_Servicio__c
            FROM Revision_Cita_Servicio__c
            WHERE Id = :revisionId
            LIMIT 1
        ];
        rev.Tipo_Reporte__c     = tipoReporte;
        rev.Datos_Formulario__c = datosFormulario;
        rev.Observaciones__c    = observaciones;
        rev.Status__c           = 'Completada';
        update rev;
    }

    @AuraEnabled
    public static void cancelRevision(Id revisionId) {
        try {
            delete [SELECT Id FROM Revision_Cita_Servicio__c WHERE Id = :revisionId LIMIT 1];
        } catch (Exception e) { /* already deleted or no permission */ }
    }

    // ─── Photos ───────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String savePhoto(Id revisionId, String base64, String base64Thumb,
                                   String filename, Decimal latitude, Decimal longitude, Integer accuracy) {
        String gpsDesc = buildGpsDesc(latitude, longitude, accuracy);
        Id mainId      = insertCVAndLink(filename, base64, gpsDesc, revisionId);

        if (String.isNotBlank(base64Thumb)) {
            insertCVAndLink('Thumb_' + filename, base64Thumb, gpsDesc, revisionId);
        }
        return mainId;
    }

    @AuraEnabled(cacheable=false)
    public static List<PhotoInfo> getRevisionPhotos(Id revisionId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :revisionId
        ];
        if (links.isEmpty()) return new List<PhotoInfo>();

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        List<PhotoInfo> result = new List<PhotoInfo>();
        for (ContentVersion cv : [
            SELECT Id, Title, VersionData, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Title LIKE 'Thumb_GeoFoto_%'
              AND IsLatest = true
            ORDER BY CreatedDate ASC
        ]) {
            PhotoInfo p = new PhotoInfo();
            p.id          = cv.Id;
            p.title       = cv.Title.removeStart('Thumb_GeoFoto_');
            p.thumbBase64 = EncodingUtil.base64Encode(cv.VersionData);
            p.createdDate = cv.CreatedDate.format('dd/MM/yyyy HH:mm');
            result.add(p);
        }
        return result;
    }

    @AuraEnabled
    public static void deletePhoto(String contentVersionId) {
        ContentVersion cv = [
            SELECT ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        String thumbTitle = cv.Title.startsWith('Thumb_') ? cv.Title : 'Thumb_' + cv.Title;
        String mainTitle  = cv.Title.startsWith('Thumb_') ? cv.Title.removeStart('Thumb_') : cv.Title;

        Set<Id> docIds = new Set<Id>();
        docIds.add(cv.ContentDocumentId);
        for (ContentVersion other : [
            SELECT ContentDocumentId FROM ContentVersion
            WHERE Title IN (:thumbTitle, :mainTitle)
              AND Id != :contentVersionId
              AND IsLatest = true
            LIMIT 5
        ]) {
            docIds.add(other.ContentDocumentId);
        }
        delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
    }

    // ─── Signature ────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveSignature(Id revisionId, String base64Clean, String base64Info,
                                     String base64Thumb, String filenameClean,
                                     String filenameInfo, String signerName) {
        insertCVAndLink(filenameClean, base64Clean, signerName, revisionId);
        insertCVAndLink(filenameInfo,  base64Info,  signerName, revisionId);
        if (String.isNotBlank(base64Thumb)) {
            insertCVAndLink('Thumb_' + filenameInfo, base64Thumb, signerName, revisionId);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, String> getRevisionSignature(Id revisionId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :revisionId
        ];
        if (links.isEmpty()) return new Map<String, String>();

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        Map<String, String> result = new Map<String, String>();
        for (ContentVersion cv : [
            SELECT Id, Title, Description, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Title LIKE 'Thumb_Firma_%'
              AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]) {
            result.put('thumbBase64',  EncodingUtil.base64Encode(cv.VersionData));
            result.put('signerName',   cv.Description);
        }
        return result;
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    private static Id insertCVAndLink(String filename, String base64Data, String description, Id linkedEntityId) {
        ContentVersion cv = new ContentVersion();
        cv.Title         = filename;
        cv.PathOnClient  = '/' + filename;
        cv.VersionData   = EncodingUtil.base64Decode(base64Data);
        cv.Description   = description;
        insert cv;

        ContentVersion cvQ = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cvQ.ContentDocumentId;
        cdl.LinkedEntityId    = linkedEntityId;
        cdl.ShareType         = 'V';
        insert cdl;

        return cv.Id;
    }

    private static String buildGpsDesc(Decimal lat, Decimal lon, Integer accuracy) {
        if (lat == null) return '';
        return lat + ',' + lon + ' ±' + (accuracy != null ? accuracy : 0) + 'm';
    }

    private static String buildInitials(String fullName) {
        if (String.isBlank(fullName)) return '';
        List<String> parts = fullName.split(' ');
        String initials = '';
        for (String p : parts) {
            if (String.isNotBlank(p)) initials += p.substring(0, 1).toUpperCase();
            if (initials.length() >= 3) break;
        }
        return initials;
    }
}