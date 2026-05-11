public with sharing class ServiceReviewPDFController {

    public ServiceAppointment saRecord          {get; set;}
    public String             accountName       {get; set;}
    public String             workOrderNum      {get; set;}
    public String             fechaSA           {get; set;}
    public Integer            totalRevs         {get; set;}
    public Integer            totalFotos        {get; set;}
    public Integer            totalDeficiencias {get; set;}
    public Integer            totalFirmadas     {get; set;}
    public String             clientSigUrl      {get; set;}
    public String             clientSigName     {get; set;}
    public String             pyatzSignatureUrl {get; set;}
    public String             techName          {get; set;}
    public List<RevWrapper>   revWrappers       {get; set;}

    // ─── Wrappers ─────────────────────────────────────────────────────────────

    public class PhotoWrapper {
        public String url   {get; set;}
        public String title {get; set;}
        public PhotoWrapper(String url, String title) { this.url = url; this.title = title; }
    }

    public class RespuestaWrapper {
        public String  label        {get; set;}
        public String  respuesta    {get; set;}
        public String  deficiencia  {get; set;}
        public Boolean hasDefic     {get; set;}
    }

    public class RevWrapper {
        public Revision_Cita_Servicio__c rev          {get; set;}
        public String                    fecha        {get; set;}
        public String                    tecnico      {get; set;}
        public List<RespuestaWrapper>    answers      {get; set;}
        public List<RespuestaWrapper>    answersLeft  {get; set;}
        public List<RespuestaWrapper>    answersRight {get; set;}
        public List<RespuestaWrapper>    deficsLeft   {get; set;}
        public List<RespuestaWrapper>    deficsRight  {get; set;}
        public List<PhotoWrapper>        photos       {get; set;}
        public List<List<PhotoWrapper>>  photoRows    {get; set;}
        public String                    sigUrl       {get; set;}
        public String                    sigName      {get; set;}
        public Boolean                   hasPhotos     {get; set;}
        public Boolean                   hasSignature  {get; set;}
        public Boolean                   hasAnswers    {get; set;}
        public Boolean                   hasDefics     {get; set;}
        public Boolean                   hasObs        {get; set;}
        public Boolean                   isFirst       {get; set;}
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    public ServiceReviewPDFController() {
        Id saId = ApexPages.currentPage().getParameters().get('id');
        if (saId == null) return;

        this.saRecord = [
            SELECT Id, AppointmentNumber, Status, Subject, ParentRecordId
            FROM ServiceAppointment
            WHERE Id = :saId
            LIMIT 1
        ];

        if (this.saRecord.ParentRecordId != null) {
            try {
                WorkOrder wo = [
                    SELECT WorkOrderNumber, Account.Name
                    FROM WorkOrder WHERE Id = :this.saRecord.ParentRecordId LIMIT 1
                ];
                this.accountName  = wo.Account != null ? wo.Account.Name : '';
                this.workOrderNum = wo.WorkOrderNumber;
            } catch (Exception e) {}
        }

        String[] meses = new String[]{
            'Enero','Febrero','Marzo','Abril','Mayo','Junio',
            'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
        };
        Datetime now = Datetime.now();
        this.fechaSA = now.day() + ' / ' + meses[now.month() - 1] + ' / ' + now.year();

        List<Revision_Cita_Servicio__c> revs = [
            SELECT Id, Name, Numero_Revision__c, Tipo_Reporte__c, Status__c,
                   Fecha_Revision__c, Tecnico__r.Name, Observaciones__c, Datos_Formulario__c
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :saId
            ORDER BY Numero_Revision__c ASC NULLS LAST
        ];

        this.totalRevs         = revs.size();
        this.totalFotos        = 0;
        this.totalDeficiencias = 0;
        this.totalFirmadas     = 0;
        this.revWrappers = new List<RevWrapper>();

        if (revs.isEmpty()) return;

        Set<Id> revIds = new Set<Id>();
        for (Revision_Cita_Servicio__c r : revs) revIds.add(r.Id);

        // Content links
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :revIds
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

        Map<Id, List<PhotoWrapper>> revPhotos = new Map<Id, List<PhotoWrapper>>();
        Map<Id, String[]>           revSigs   = new Map<Id, String[]>(); // [url, name]

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
                    if (!revIds.contains(entityId)) continue;
                    if (cv.Title.startsWith('GeoFoto_')) {
                        if (!revPhotos.containsKey(entityId))
                            revPhotos.put(entityId, new List<PhotoWrapper>());
                        revPhotos.get(entityId).add(
                            new PhotoWrapper(dlUrl, cv.Title.removeStart('GeoFoto_'))
                        );
                        this.totalFotos++;
                    } else if (cv.Title.startsWith('SignClean_')) {
                        revSigs.put(entityId, new String[]{ dlUrl, cv.Description });
                    }
                }
            }
        }

        for (Revision_Cita_Servicio__c r : revs) {
            RevWrapper w = new RevWrapper();
            w.rev       = r;
            w.fecha     = r.Fecha_Revision__c != null
                ? r.Fecha_Revision__c.format('dd/MM/yyyy HH:mm')
                : '';
            w.tecnico   = r.Tecnico__r != null ? r.Tecnico__r.Name : '';
            w.photos    = revPhotos.containsKey(r.Id) ? revPhotos.get(r.Id) : new List<PhotoWrapper>();
            w.hasPhotos = !w.photos.isEmpty();

            w.photoRows = new List<List<PhotoWrapper>>();
            List<PhotoWrapper> currentRow = new List<PhotoWrapper>();
            for (PhotoWrapper ph : w.photos) {
                currentRow.add(ph);
                if (currentRow.size() == 2) {
                    w.photoRows.add(currentRow);
                    currentRow = new List<PhotoWrapper>();
                }
            }
            if (!currentRow.isEmpty()) w.photoRows.add(currentRow);

            if (revSigs.containsKey(r.Id)) {
                w.sigUrl       = revSigs.get(r.Id)[0];
                w.sigName      = revSigs.get(r.Id)[1];
                w.hasSignature = true;
            } else {
                w.hasSignature = false;
            }

            w.hasObs  = String.isNotBlank(r.Observaciones__c);
            w.answers = parseFormData(r.Datos_Formulario__c);
            w.hasAnswers = !w.answers.isEmpty();
            w.hasDefics  = false;
            for (RespuestaWrapper rw : w.answers) {
                if (rw.hasDefic) { w.hasDefics = true; break; }
            }

            // Split answers into two halves for two-column checklist
            Integer mid = (w.answers.size() + 1) / 2;
            w.answersLeft  = new List<RespuestaWrapper>();
            w.answersRight = new List<RespuestaWrapper>();
            for (Integer i = 0; i < w.answers.size(); i++) {
                if (i < mid) w.answersLeft.add(w.answers[i]);
                else         w.answersRight.add(w.answers[i]);
            }

            // Split deficiencies into two columns
            List<RespuestaWrapper> allDefics = new List<RespuestaWrapper>();
            for (RespuestaWrapper rw : w.answers) {
                if (rw.hasDefic) allDefics.add(rw);
            }
            Integer defMid = (allDefics.size() + 1) / 2;
            w.deficsLeft  = new List<RespuestaWrapper>();
            w.deficsRight = new List<RespuestaWrapper>();
            for (Integer i = 0; i < allDefics.size(); i++) {
                if (i < defMid) w.deficsLeft.add(allDefics[i]);
                else            w.deficsRight.add(allDefics[i]);
            }

            if (w.hasDefics)    this.totalDeficiencias++;
            if (w.hasSignature) this.totalFirmadas++;

            w.isFirst = this.revWrappers.isEmpty();
            this.revWrappers.add(w);
        }

        // Firma del cliente: primera revisión completada con firma
        for (RevWrapper w : this.revWrappers) {
            if (w.hasSignature && w.rev.Status__c == 'Completada') {
                this.clientSigUrl  = w.sigUrl;
                this.clientSigName = w.sigName;
                break;
            }
        }

        // Técnico y firma Pyatz
        for (RevWrapper w : this.revWrappers) {
            if (String.isNotBlank(w.tecnico)) {
                this.techName = w.tecnico;
                break;
            }
        }
        this.pyatzSignatureUrl = findSignatureUrl(this.techName);
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
        for (StaticResource sr : [SELECT Name, SystemModstamp FROM StaticResource
                                   WHERE Name != 'HeaderPDF' AND Name != 'FooterPDF'
                                   AND Name != 'WatermarkPDF' ORDER BY Name]) {
            Boolean allMatch = true;
            for (String word : words) {
                if (!sr.Name.contains(word)) { allMatch = false; break; }
            }
            if (allMatch) return '/resource/' + sr.SystemModstamp.getTime() + '/' + sr.Name;
        }
        return null;
    }

    private static List<RespuestaWrapper> parseFormData(String jsonStr) {
        List<RespuestaWrapper> result = new List<RespuestaWrapper>();
        if (String.isBlank(jsonStr)) return result;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
            List<Object> respuestas  = (List<Object>) root.get('respuestas');
            if (respuestas == null) return result;
            for (Object obj : respuestas) {
                Map<String, Object> m = (Map<String, Object>) obj;
                RespuestaWrapper rw   = new RespuestaWrapper();
                rw.label       = (String) m.get('label');
                rw.respuesta   = (String) m.get('respuesta');
                rw.deficiencia = (String) m.get('deficiencia');
                rw.hasDefic    = String.isNotBlank(rw.deficiencia);
                if (String.isNotBlank(rw.label)) result.add(rw);
            }
        } catch (Exception e) { /* malformed JSON */ }
        return result;
    }
}