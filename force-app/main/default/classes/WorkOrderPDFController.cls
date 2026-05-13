public with sharing class WorkOrderPDFController {

    public WorkOrder workOrderRecord  {get; set;}
    public List<SAWrapper>  saWrappers       {get; set;}
    public String workOrderNumberShort       {get; set;}
    public String fechaEjecucion             {get; set;}
    public String pyatzSignatureUrl          {get; set;}
    public String clientSigUrl               {get; set;}
    public String clientSigName              {get; set;}
    public String techSigUrl                 {get; set;}
    public String techSigName                {get; set;}
    public String territorio                 {get; set;}

    public Integer totalCitas          {get; set;}
    public Integer citasCompletadas    {get; set;}
    public Integer citasConIncidencia  {get; set;}
    public Integer totalFotos          {get; set;}
    public Integer totalPuntos         {get; set;}

    // ─── Wrappers ─────────────────────────────────────────────────────────────

    public class PhotoWrapper {
        public String url   {get; set;}
        public String title {get; set;}
        public PhotoWrapper(String url, String title) { this.url = url; this.title = title; }
    }

    public class SAWrapper {
        public ServiceAppointment sa      {get; set;}
        public List<PhotoWrapper> photos  {get; set;}
        public String saSignatureUrl      {get; set;}
        public String saSignatureName     {get; set;}
        public Boolean hasObservation     {get; set;}
        public Boolean hasPhotos          {get; set;}
        public Boolean isCompleted        {get; set;}
        public Boolean isIncident         {get; set;}

        public SAWrapper(ServiceAppointment sa) {
            this.sa             = sa;
            this.photos         = new List<PhotoWrapper>();
            this.hasPhotos      = false;
            this.hasObservation = String.isNotBlank(sa.Description);
            String s = (sa.Status != null ? sa.Status : '').toLowerCase();
            this.isCompleted    = s.contains('complet');
            this.isIncident     = s.contains('inciden') || s.contains('cannot') || s.contains('incident');
        }
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    public WorkOrderPDFController(ApexPages.StandardController stdCtrl) {
        Id workOrderId = stdCtrl.getId();

        // 1. WorkOrder principal
        this.workOrderRecord = [
            SELECT Id, WorkOrderNumber, Subject, Status, Priority,
                   Account.Name, WorkType.Name,
                   CreatedBy.Name, CreatedDate
            FROM WorkOrder
            WHERE Id = :workOrderId
        ];

        // 2. Número sin ceros
        if (String.isNotBlank(this.workOrderRecord.WorkOrderNumber)) {
            String digits = this.workOrderRecord.WorkOrderNumber.replaceAll('[^0-9]', '');
            String prefix = this.workOrderRecord.WorkOrderNumber.replaceAll('[0-9]', '');
            this.workOrderNumberShort = String.isNotBlank(digits)
                ? prefix + String.valueOf(Integer.valueOf(digits))
                : this.workOrderRecord.WorkOrderNumber;
        }

        // 3. Fecha "03 / Mayo / 2026"
        Datetime dt = this.workOrderRecord.CreatedDate;
        String[] meses = new String[]{'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                                      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'};
        String d = String.valueOf(dt.day());
        this.fechaEjecucion = (d.length() == 1 ? '0' + d : d) + ' / '
                            + meses[dt.month() - 1] + ' / '
                            + String.valueOf(dt.year());

        // 4. Service Appointments
        List<ServiceAppointment> saList = [
            SELECT Id, AppointmentNumber, Subject, Status, Description,
                   ServiceTerritory.Name
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY AppointmentNumber ASC
        ];

        this.saWrappers = new List<SAWrapper>();
        Map<Id, SAWrapper> wrapperById = new Map<Id, SAWrapper>();
        Set<Id> saIds = new Set<Id>();

        for (ServiceAppointment sa : saList) {
            SAWrapper w = new SAWrapper(sa);
            this.saWrappers.add(w);
            wrapperById.put(sa.Id, w);
            saIds.add(sa.Id);
            if (this.territorio == null && sa.ServiceTerritory != null) {
                this.territorio = sa.ServiceTerritory.Name;
            }
        }

        // 5. Fotos y firmas ligadas a cada SA
        if (!saIds.isEmpty()) {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :saIds
            ];

            Set<Id> docIds = new Set<Id>();
            Map<Id, List<Id>> entityToDocs = new Map<Id, List<Id>>();
            Map<Id, Set<Id>> docToEntities = new Map<Id, Set<Id>>();

            for (ContentDocumentLink l : links) {
                docIds.add(l.ContentDocumentId);
                if (!entityToDocs.containsKey(l.LinkedEntityId))
                    entityToDocs.put(l.LinkedEntityId, new List<Id>());
                entityToDocs.get(l.LinkedEntityId).add(l.ContentDocumentId);
                if (!docToEntities.containsKey(l.ContentDocumentId))
                    docToEntities.put(l.ContentDocumentId, new Set<Id>());
                docToEntities.get(l.ContentDocumentId).add(l.LinkedEntityId);
            }

            if (!docIds.isEmpty()) {
                for (ContentVersion cv : [
                    SELECT Id, Title, ContentDocumentId, Description
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds
                    AND (Title LIKE 'GeoFoto_%' OR Title LIKE 'SignClean_%')
                    AND IsLatest = true
                    ORDER BY CreatedDate ASC
                ]) {
                    Set<Id> entities = docToEntities.get(cv.ContentDocumentId);
                    if (entities == null) continue;
                    String dlUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;

                    for (Id entityId : entities) {
                        SAWrapper w = wrapperById.get(entityId);
                        if (w == null) continue;
                        if (cv.Title.startsWith('GeoFoto_')) {
                            w.photos.add(new PhotoWrapper(dlUrl, cv.Title.removeStart('GeoFoto_')));
                            w.hasPhotos = true;
                        } else if (cv.Title.startsWith('SignClean_')) {
                            w.saSignatureUrl  = dlUrl;      // la más reciente (última en ASC) gana
                            w.saSignatureName = cv.Description;
                        }
                    }
                }
            }
        }

        // 6. Firmas de la Orden (para el Certificado)
        List<ContentDocumentLink> woLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :workOrderId
        ];
        Set<Id> woDocIds = new Set<Id>();
        for (ContentDocumentLink l : woLinks) woDocIds.add(l.ContentDocumentId);

        // Firma de técnico / Pyatz desde WO (si existe)
        if (!woDocIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, Title, Description
                FROM ContentVersion
                WHERE ContentDocumentId IN :woDocIds
                AND Title LIKE 'SignClean_%'
                AND IsLatest = true
                ORDER BY CreatedDate ASC
                LIMIT 10
            ]) {
                String url = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                if (this.techSigUrl == null) {
                    this.techSigUrl  = url;
                    this.techSigName = cv.Description;
                }
            }
        }

        // Firma del CLIENTE: viene de la primera SA que tenga SignClean_
        for (SAWrapper w : this.saWrappers) {
            if (w.saSignatureUrl != null) {
                this.clientSigUrl  = w.saSignatureUrl;
                this.clientSigName = w.saSignatureName;
                break;
            }
        }

        // 7. Firma Pyatz desde Static Resources
        this.pyatzSignatureUrl = findSignatureUrl(this.workOrderRecord.CreatedBy.Name);

        // 8. Estadísticas para el Certificado
        this.totalCitas         = this.saWrappers.size();
        this.citasCompletadas   = 0;
        this.citasConIncidencia = 0;
        this.totalFotos         = 0;
        this.totalPuntos        = 0;
        Set<String> uniqueSubjects = new Set<String>();

        for (SAWrapper w : this.saWrappers) {
            if (w.isCompleted)  this.citasCompletadas++;
            if (w.isIncident)   this.citasConIncidencia++;
            this.totalFotos += w.photos.size();
            if (String.isNotBlank(w.sa.Subject)) uniqueSubjects.add(w.sa.Subject);
        }
        this.totalPuntos = uniqueSubjects.size() > 0 ? uniqueSubjects.size() : this.totalCitas;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static String findSignatureUrl(String fullName) {
        if (String.isBlank(fullName)) return null;
        String normalized = fullName
            .replace('á','a').replace('é','e').replace('í','i').replace('ó','o').replace('ú','u')
            .replace('Á','A').replace('É','E').replace('Í','I').replace('Ó','O').replace('Ú','U')
            .replace('ñ','n').replace('Ñ','N').replace('ü','u').replace('Ü','U')
            .toUpperCase().normalizeSpace();
        List<String> words = normalized.split(' ');
        List<StaticResource> srs = [SELECT Name, SystemModstamp FROM StaticResource
                                     WHERE Name != 'HeaderPDF' AND Name != 'FooterPDF' AND Name != 'WatermarPDF'
                                     ORDER BY Name];
        for (StaticResource sr : srs) {
            Boolean allMatch = true;
            for (String word : words) {
                if (!sr.Name.contains(word)) { allMatch = false; break; }
            }
            if (allMatch) return '/resource/' + sr.SystemModstamp.getTime() + '/' + sr.Name;
        }
        return null;
    }
}