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
        @AuraEnabled public String  templateId;
        @AuraEnabled public String  status;
        @AuraEnabled public String  fecha;
        @AuraEnabled public String  tecnico;
        @AuraEnabled public Boolean isCompleted;
        @AuraEnabled public String  cardClass;
        @AuraEnabled public String  badgeClass;
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
            SELECT Id, Name, Numero_Revision__c, Tipo_Reporte__c, Plantilla_de_Formulario__c,
                   Status__c, Fecha_Revision__c, Tecnico__r.Name
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :saId
            ORDER BY Numero_Revision__c ASC NULLS LAST
        ];

        Integer completadas = 0;
        List<RevisionSummary> revList = new List<RevisionSummary>();
        for (Revision_Cita_Servicio__c r : revs) {
            RevisionSummary rs = new RevisionSummary();
            rs.id          = r.Id;
            rs.name        = r.Name;
            rs.numero      = r.Numero_Revision__c != null ? Integer.valueOf(r.Numero_Revision__c) : 0;
            rs.tipo        = r.Tipo_Reporte__c;
            rs.templateId  = r.Plantilla_de_Formulario__c;
            rs.status      = r.Status__c;
            rs.isCompleted = r.Status__c == 'Completada';
            rs.fecha       = r.Fecha_Revision__c != null
                ? r.Fecha_Revision__c.format('dd/MM/yyyy HH:mm')
                : '';
            rs.tecnico     = r.Tecnico__r != null ? r.Tecnico__r.Name : '';
            
            // Estilos para LWC
            rs.cardClass   = 'rev-card ' + (rs.isCompleted ? 'rev-card--done' : 'rev-card--pending');
            rs.badgeClass  = 'rev-card__badge ' + (rs.isCompleted ? 'rev-card__badge--done' : 'rev-card__badge--pending');
            
            revList.add(rs);
            if (r.Status__c == 'Completada') completadas++;
        }

        Integer maxRev = sa.Revisiones__c != null ? Integer.valueOf(sa.Revisiones__c) : 0;

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
        info.canCreateRevision     = (maxRev > 0 && completadas < maxRev);
        info.revisionesList        = revList;
        info.techName              = techName;
        info.techInitials          = techInitials;
        return info;
    }

    // ─── Revision CRUD ────────────────────────────────────────────────────────

    @AuraEnabled
    public static Id createRevision(Id saId, Integer revisionNumber) {
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c();
        rev.Cita_Servicio__c    = saId;
        rev.Numero_Revision__c  = revisionNumber;
        rev.Status__c           = 'En Proceso';
        rev.Fecha_Revision__c   = Datetime.now();
        rev.Tecnico__c          = UserInfo.getUserId();
        insert rev;
        updateSAStatusToInProgress(saId);
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
        
        if (tipoReporte instanceof Id) {
            rev.Plantilla_de_Formulario__c = (Id)tipoReporte;
            // Opcional: llenar el nombre en el campo de texto para reportes viejos
            Form_Template__c temp = [SELECT Tipo_Reporte__c FROM Form_Template__c WHERE Id = :tipoReporte LIMIT 1];
            rev.Tipo_Reporte__c = temp.Tipo_Reporte__c;
        } else {
            rev.Tipo_Reporte__c = tipoReporte;
        }
        
        rev.Datos_Formulario__c = datosFormulario;
        rev.Observaciones__c    = observaciones;
        rev.Status__c           = 'Completada';
        update rev;
        updateSAStatus(rev.Cita_Servicio__c);
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

    private static void updateSAStatusToInProgress(Id saId) {
        ServiceAppointment sa = [SELECT Id, Status FROM ServiceAppointment WHERE Id = :saId LIMIT 1];
        if (sa.Status != 'En curso' && sa.Status != 'Completado') {
            sa.Status = 'En curso';
            update sa;
        }
    }

    private static void updateSAStatus(Id saId) {
        ServiceAppointment sa = [
            SELECT Id, Revisiones__c
            FROM ServiceAppointment
            WHERE Id = :saId
            LIMIT 1
        ];
        Integer total       = sa.Revisiones__c != null ? Integer.valueOf(sa.Revisiones__c) : 0;
        Integer completadas = [
            SELECT COUNT() FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :saId AND Status__c = 'Completada'
        ];

        String newStatus;
        if (total > 0 && completadas >= total) {
            newStatus = 'Completado';
        } else if (completadas > 0) {
            newStatus = 'En curso';
        } else {
            return;
        }

        sa.Status = newStatus;
        try { update sa; } catch (Exception e) { /* status transition validation may fail */ }
    }

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