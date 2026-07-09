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
    public Boolean            isConsolidated    {get; set;}
    public Boolean            verificado        {get; set;}
    public String             verificadoPor     {get; set;}
    public String             fechaVerificacion {get; set;}
    public String             verificacionSigUrl{get; set;}
    public Integer            totalSAs          {get; set;}
    public String             nombreFirmante    {get; set;}
    public String             cargoFirmante     {get; set;}

    // ─── Propiedades del certificado consolidado ──────────────────────────────
    public String             woSubject         {get; set;}
    public String             accountPhone      {get; set;}
    public String             accountDireccion  {get; set;}
    public String             accountMunicipio  {get; set;}
    public String             accountEstado     {get; set;}
    public String             accountActividad  {get; set;}
    public String             accountSede       {get; set;}
    public String             contractNumber    {get; set;}
    public String             contractEndDate   {get; set;}
    public String             contractName      {get; set;}
    public String             firstSaSchedule   {get; set;}
    public String             fechaInicio       {get; set;}
    public String             fechaTermino      {get; set;}
    public Boolean            hasLineItems      {get; set;}
    public List<LineItemWrapper> lineItems       {get; set;}

    // ─── Wrappers ─────────────────────────────────────────────────────────────

    public class LineItemWrapper {
        public String  code             {get; set;}
        public String  nombre           {get; set;}
        public String  descripcion      {get; set;}
        public Boolean isSeparator      {get; set;}
        public Boolean hasDescripcion   {get; set;}
        public String  sectionHeader    {get; set;}
        public Boolean hasSectionHeader {get; set;}
    }

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
        public String                    zona          {get; set;}
        public String                    tratamiento   {get; set;}
        public Boolean                   showTratHeader  {get; set;}
        public Boolean                   showZonaHeader  {get; set;}
        public Boolean                   hasTratamiento  {get; set;}
    }

    private class RevSortKey implements Comparable {
        public RevWrapper w;
        private String sortKey;
        public RevSortKey(RevWrapper w) {
            this.w = w;
            String trat = w.tratamiento != null ? w.tratamiento : '';
            String zona = w.zona        != null ? w.zona        : '';
            String num  = w.rev.Numero_Revision__c != null
                ? String.valueOf(w.rev.Numero_Revision__c.longValue()).leftPad(10, '0')
                : '0000000000';
            this.sortKey = zona + '~~~' + trat + '~~~' + num;
        }
        public Integer compareTo(Object other) {
            return this.sortKey.compareTo(((RevSortKey) other).sortKey);
        }
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    public ServiceReviewPDFController() {
        this.isConsolidated     = false;
        this.verificado         = false;
        this.verificadoPor      = '';
        this.fechaVerificacion  = '';
        this.verificacionSigUrl = null;
        this.totalSAs           = 0;
        this.nombreFirmante     = '';
        this.cargoFirmante      = '';
        this.woSubject          = '';
        this.accountPhone       = '';
        this.accountDireccion   = '';
        this.accountMunicipio   = '';
        this.accountEstado      = '';
        this.accountActividad   = '';
        this.accountSede        = '';
        this.contractNumber     = '';
        this.contractEndDate    = '';
        this.contractName       = '';
        this.firstSaSchedule    = '';
        this.fechaInicio        = '';
        this.fechaTermino       = '';
        this.hasLineItems       = false;
        this.lineItems          = new List<LineItemWrapper>();

        Id workOrderId = ApexPages.currentPage().getParameters().get('workOrderId');
        if (workOrderId != null) {
            loadConsolidated(workOrderId);
            return;
        }

        Id saId = ApexPages.currentPage().getParameters().get('id');
        if (saId == null) return;

        this.saRecord = [
            SELECT Id, AppointmentNumber, Status, Subject, ParentRecordId,
                   Zonas_a_Tratar__c, Cita_Padre__c,
                   Producto_Relacionado__c, Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode,
                   Nombre_Firmante__c, Cargo_Firmante__c
            FROM ServiceAppointment
            WHERE Id = :saId
            LIMIT 1
        ];

        if (this.saRecord.ParentRecordId != null) {
            try {
                WorkOrder wo = [
                    SELECT WorkOrderNumber, Account.Name, Nombre_Firmante__c, Cargo_Firmante__c
                    FROM WorkOrder WHERE Id = :this.saRecord.ParentRecordId LIMIT 1
                ];
                this.accountName    = wo.Account != null ? wo.Account.Name : '';
                this.workOrderNum   = wo.WorkOrderNumber;
                this.nombreFirmante = wo.Nombre_Firmante__c != null ? wo.Nombre_Firmante__c : '';
                this.cargoFirmante  = wo.Cargo_Firmante__c  != null ? wo.Cargo_Firmante__c  : '';
            } catch (Exception e) {}
        }

        // Zona y tratamiento del SA + citas hijas fusionadas
        String saZona = this.saRecord.Zonas_a_Tratar__c != null ? this.saRecord.Zonas_a_Tratar__c : '';
        String saTrat = '';
        if (this.saRecord.Producto_Relacionado__c != null && this.saRecord.Producto_Relacionado__r != null) {
            saTrat = String.isNotBlank(this.saRecord.Producto_Relacionado__r.ProductCode)
                     ? this.saRecord.Producto_Relacionado__r.ProductCode
                     : this.saRecord.Producto_Relacionado__r.Name;
        }
        /*
        for (ServiceAppointment hija : [
            SELECT Id, Zonas_a_Tratar__c, Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode
            FROM ServiceAppointment WHERE Cita_Padre__c = :saId
        ]) {
            String hz = hija.Zonas_a_Tratar__c != null ? hija.Zonas_a_Tratar__c : '';
            if (String.isNotBlank(hz) && !saZona.contains(hz))
                saZona += (String.isNotBlank(saZona) ? '\n' : '') + hz;
            if (hija.Producto_Relacionado__r != null) {
                String ht = String.isNotBlank(hija.Producto_Relacionado__r.ProductCode)
                            ? hija.Producto_Relacionado__r.ProductCode : hija.Producto_Relacionado__r.Name;
                if (String.isNotBlank(ht) && !saTrat.contains(ht))
                    saTrat += (String.isNotBlank(saTrat) ? ', ' : '') + ht;
            }
        }
        */
        Map<Id, String> saZonaMap = new Map<Id, String>{ saId => saZona };
        Map<Id, String> saTratMap = new Map<Id, String>{ saId => saTrat };

        String[] meses = new String[]{
            'Enero','Febrero','Marzo','Abril','Mayo','Junio',
            'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
        };
        Datetime now = Datetime.now();
        this.fechaSA = now.day() + ' / ' + meses[now.month() - 1] + ' / ' + now.year();

        List<Revision_Cita_Servicio__c> revs = [
            SELECT Id, Name, Numero_Revision__c, Tipo_Reporte__c, Status__c,
                   Fecha_Revision__c, Tecnico__r.Name, Observaciones__c, Datos_Formulario__c,
                   Nombre_Firmante__c, Cargo_Firmante__c, Cita_Servicio__c
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

        buildRevWrappers(revs, saZonaMap, saTratMap);

        // Firma del cliente: última revisión completada con firma (Fallback históricos)
        for (RevWrapper w : this.revWrappers) {
            if (w.hasSignature && w.rev.Status__c == 'Completada') {
                this.clientSigUrl   = w.sigUrl;
                this.clientSigName  = w.sigName;
                if (String.isNotBlank(w.rev.Nombre_Firmante__c)) {
                    this.nombreFirmante = w.rev.Nombre_Firmante__c;
                    this.cargoFirmante  = w.rev.Cargo_Firmante__c != null ? w.rev.Cargo_Firmante__c : '';
                }
            }
        }

        // Firma del cliente: buscar en la Cita de Servicio (SA) (Nuevo flujo global)
        List<ContentDocumentLink> saLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :saId];
        if (!saLinks.isEmpty()) {
            Set<Id> cDocIds = new Set<Id>();
            for (ContentDocumentLink l : saLinks) cDocIds.add(l.ContentDocumentId);
            List<ContentVersion> cvs = [SELECT Id, Description FROM ContentVersion WHERE ContentDocumentId IN :cDocIds AND Title LIKE 'SignClean_%' AND IsLatest = true ORDER BY CreatedDate DESC LIMIT 1];
            if (!cvs.isEmpty()) {
                this.clientSigUrl  = '/sfc/servlet.shepherd/version/download/' + cvs[0].Id;
                this.clientSigName = cvs[0].Description;
                if (String.isNotBlank(this.saRecord.Nombre_Firmante__c)) {
                    this.nombreFirmante = this.saRecord.Nombre_Firmante__c;
                    this.cargoFirmante  = this.saRecord.Cargo_Firmante__c != null ? this.saRecord.Cargo_Firmante__c : '';
                }
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

        String safeSA = safeFileName(this.accountName != null ? this.accountName : '');
        String saNum  = this.saRecord != null ? this.saRecord.AppointmentNumber : 'SA';
        ApexPages.currentPage().getHeaders().put('content-disposition',
            'inline; filename="Revision-' + saNum + (String.isNotBlank(safeSA) ? '-' + safeSA : '') + '.pdf"');
    }

    // ─── Modo consolidado (workOrderId) ──────────────────────────────────────

    private void loadConsolidated(Id workOrderId) {
        this.isConsolidated = true;

        WorkOrder wo;
        try {
            wo = [
                SELECT Id, WorkOrderNumber, Subject, ServiceContractId,
                       Account.Name, Account.Phone, Account.Industry,
                       Account.BillingStreet, Account.BillingCity,
                       Account.BillingPostalCode, Account.BillingState,
                       Account.Calle_de_envio__c, Account.No_Ext__c, Account.No_Int__c,
                       Account.Colonia__c, Account.Ciudad_de_envio__c,
                       Account.Codigo_postal_de_envio__c, Account.Estado_o_provincia_de_envio__c,
                       ServiceTerritory.Name,
                       Verificado__c, Verificado_Por__c, Fecha_Verificacion__c,
                       Nombre_Firmante__c, Cargo_Firmante__c
                FROM WorkOrder WHERE Id = :workOrderId LIMIT 1
            ];
        } catch (Exception e) {
            this.revWrappers = new List<RevWrapper>();
            return;
        }

        String[] meses = new String[]{
            'Enero','Febrero','Marzo','Abril','Mayo','Junio',
            'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
        };

        this.accountName  = wo.Account != null ? wo.Account.Name : '';
        this.workOrderNum = wo.WorkOrderNumber;
        this.woSubject    = wo.Subject != null ? wo.Subject : '';

        // ── Datos cuenta ────────────────────────────────────────────────────────
        if (wo.Account != null) {
            this.accountPhone = wo.Account.Phone != null ? wo.Account.Phone : '';
            // Dirección: preferir campos de envío, caer a billing
            String calle    = String.isNotBlank(wo.Account.Calle_de_envio__c)
                              ? wo.Account.Calle_de_envio__c
                              : (wo.Account.BillingStreet != null ? wo.Account.BillingStreet : '');
            String noExt    = wo.Account.No_Ext__c != null ? ' #' + wo.Account.No_Ext__c : '';
            String noInt    = wo.Account.No_Int__c != null && wo.Account.No_Int__c != 'S/N'
                              ? ' Int. ' + wo.Account.No_Int__c : '';
            String colonia  = wo.Account.Colonia__c != null ? wo.Account.Colonia__c : '';
            this.accountDireccion = calle + noExt + noInt
                                  + (String.isNotBlank(colonia) ? ', Col. ' + colonia : '');
            String cp       = String.isNotBlank(wo.Account.Codigo_postal_de_envio__c)
                              ? wo.Account.Codigo_postal_de_envio__c
                              : (wo.Account.BillingPostalCode != null ? wo.Account.BillingPostalCode : '');
            String ciudad   = String.isNotBlank(wo.Account.Ciudad_de_envio__c)
                              ? wo.Account.Ciudad_de_envio__c
                              : (wo.Account.BillingCity != null ? wo.Account.BillingCity : '');
            this.accountMunicipio = (String.isNotBlank(cp) ? cp + ' ' : '') + ciudad;
            this.accountEstado    = String.isNotBlank(wo.Account.Estado_o_provincia_de_envio__c)
                                  ? wo.Account.Estado_o_provincia_de_envio__c
                                  : (wo.Account.BillingState != null ? wo.Account.BillingState : '');
            this.accountActividad = wo.Account.Industry != null ? wo.Account.Industry : '';
        }
        this.accountSede = wo.ServiceTerritory != null && wo.ServiceTerritory.Name != null
                           ? wo.ServiceTerritory.Name : this.accountName;

        Datetime now = Datetime.now();
        this.fechaSA = now.day() + ' / ' + meses[now.month() - 1] + ' / ' + now.year();

        // ── Firmante ────────────────────────────────────────────────────────────
        this.nombreFirmante = wo.Nombre_Firmante__c != null ? wo.Nombre_Firmante__c : '';
        this.cargoFirmante  = wo.Cargo_Firmante__c  != null ? wo.Cargo_Firmante__c  : '';

        // ── Verificación ────────────────────────────────────────────────────────
        this.verificado = wo.Verificado__c;
        if (wo.Verificado__c) {
            this.verificadoPor = wo.Verificado_Por__c;
            if (wo.Fecha_Verificacion__c != null) {
                Datetime d = wo.Fecha_Verificacion__c;
                this.fechaVerificacion = d.day() + ' / ' + meses[d.month() - 1] + ' / ' + d.year()
                    + ' ' + String.valueOf(d.hour()).leftPad(2,'0')
                    + ':' + String.valueOf(d.minute()).leftPad(2,'0');
            }
            if (String.isNotBlank(wo.Verificado_Por__c)) {
                this.verificacionSigUrl = findSignatureUrl(wo.Verificado_Por__c);
            }
        }

        // ── Contrato y productos ─────────────────────────────────────────────────
        if (wo.ServiceContractId != null) {
            try {
                ServiceContract sc = [
                    SELECT Id, ContractNumber, Name, EndDate, Quote_Source__c
                    FROM ServiceContract WHERE Id = :wo.ServiceContractId LIMIT 1
                ];
                this.contractNumber = sc.ContractNumber != null ? sc.ContractNumber : '';
                this.contractName   = sc.Name != null ? sc.Name : '';
                if (sc.EndDate != null) {
                    this.contractEndDate = sc.EndDate.day() + '/' + String.valueOf(sc.EndDate.month()).leftPad(2,'0')
                                        + '/' + String.valueOf(sc.EndDate.year()).right(2);
                }
                if (sc.Quote_Source__c != null) {
                    loadQuoteLineItems(sc.Quote_Source__c);
                }
            } catch (Exception e) { /* sin contrato */ }
        }

        // ── Citas de servicio ────────────────────────────────────────────────────
        List<ServiceAppointment> sas = [
            SELECT Id, AppointmentNumber, Status, Subject, SchedStartTime, SchedEndTime, Duration,
                   Zonas_a_Tratar__c, Cita_Padre__c,
                   Producto_Relacionado__c, Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode,
                   Nombre_Firmante__c, Cargo_Firmante__c
            FROM ServiceAppointment
            WHERE ParentRecordId = :workOrderId
            ORDER BY SchedStartTime ASC NULLS LAST, AppointmentNumber ASC
        ];

        this.totalSAs = sas.size();

        if (!sas.isEmpty()) {
            this.saRecord = sas[0];
            if (sas[0].SchedStartTime != null) {
                String inicio = sas[0].SchedStartTime.format('dd/MM/yy HH:mm');
                if (sas[0].Duration != null) {
                    Datetime fin = sas[0].SchedStartTime.addMinutes(Integer.valueOf(sas[0].Duration));
                    this.firstSaSchedule = inicio + ' - ' + fin.format('HH:mm');
                } else {
                    this.firstSaSchedule = inicio;
                }
            }
            // Fecha/hora inicio de ODT = primera SA con SchedStartTime
            Datetime minStart = null;
            Datetime maxEnd   = null;
            for (ServiceAppointment sa : sas) {
                if (sa.Cita_Padre__c != null) continue;
                if (sa.SchedStartTime != null && (minStart == null || sa.SchedStartTime < minStart))
                    minStart = sa.SchedStartTime;
                Datetime endDt = sa.SchedEndTime != null ? sa.SchedEndTime
                    : (sa.SchedStartTime != null && sa.Duration != null
                        ? sa.SchedStartTime.addMinutes(Integer.valueOf(sa.Duration)) : null);
                if (endDt != null && (maxEnd == null || endDt > maxEnd)) maxEnd = endDt;
            }
            if (minStart != null) this.fechaInicio  = minStart.format('dd/MM/yyyy HH:mm');
            if (maxEnd   != null) this.fechaTermino = maxEnd.format('dd/MM/yyyy HH:mm');
        }

        if (sas.isEmpty()) {
            this.totalRevs = 0; this.totalFotos = 0;
            this.totalDeficiencias = 0; this.totalFirmadas = 0;
            this.revWrappers = new List<RevWrapper>();
            return;
        }

        Set<Id> saIds = new Set<Id>();
        Map<Id, String> saZonaMap = new Map<Id, String>();
        Map<Id, String> saTratMap  = new Map<Id, String>();
        Set<Id> parentCandidates  = new Set<Id>();

        for (ServiceAppointment sa : sas) {
            saIds.add(sa.Id);
            saZonaMap.put(sa.Id, sa.Zonas_a_Tratar__c != null ? sa.Zonas_a_Tratar__c : '');
            String trat = '';
            if (sa.Producto_Relacionado__c != null && sa.Producto_Relacionado__r != null) {
                trat = String.isNotBlank(sa.Producto_Relacionado__r.ProductCode)
                       ? sa.Producto_Relacionado__r.ProductCode : sa.Producto_Relacionado__r.Name;
            }
            saTratMap.put(sa.Id, trat);
            if (sa.Cita_Padre__c == null) parentCandidates.add(sa.Id);
        }

        // Agregar zonas y tratamientos de citas hijas fusionadas
        if (!parentCandidates.isEmpty()) {
            for (ServiceAppointment hija : [
                SELECT Id, Cita_Padre__c, Zonas_a_Tratar__c,
                       Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode
                FROM ServiceAppointment WHERE Cita_Padre__c IN :parentCandidates
            ]) {
                if (!saZonaMap.containsKey(hija.Cita_Padre__c)) continue;
                /* 
                // COMENTADO PARA EVITAR AGRUPACIÓN DE ZONAS EN UNA SOLA LÍNEA
                String hz = hija.Zonas_a_Tratar__c != null ? hija.Zonas_a_Tratar__c : '';
                String pz = saZonaMap.get(hija.Cita_Padre__c);
                if (String.isNotBlank(hz) && !pz.contains(hz))
                    saZonaMap.put(hija.Cita_Padre__c, pz + (String.isNotBlank(pz) ? '\n' : '') + hz);
                */
                if (hija.Producto_Relacionado__r != null) {
                    String ht = String.isNotBlank(hija.Producto_Relacionado__r.ProductCode)
                                ? hija.Producto_Relacionado__r.ProductCode : hija.Producto_Relacionado__r.Name;
                    String pt = saTratMap.get(hija.Cita_Padre__c);
                    if (String.isNotBlank(ht) && !pt.contains(ht))
                        saTratMap.put(hija.Cita_Padre__c, pt + (String.isNotBlank(pt) ? ', ' : '') + ht);
                }
            }
        }

        List<Revision_Cita_Servicio__c> revs = [
            SELECT Id, Name, Numero_Revision__c, Tipo_Reporte__c, Status__c,
                   Fecha_Revision__c, Tecnico__r.Name, Observaciones__c, Datos_Formulario__c,
                   Nombre_Firmante__c, Cargo_Firmante__c, Cita_Servicio__c
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :saIds
            ORDER BY Cita_Servicio__c, Numero_Revision__c ASC NULLS LAST
        ];

        this.totalRevs = revs.size();
        this.totalFotos = 0;
        this.totalDeficiencias = 0;
        this.totalFirmadas = 0;
        this.revWrappers = new List<RevWrapper>();

        if (!revs.isEmpty()) {
            buildRevWrappers(revs, saZonaMap, saTratMap);
            for (RevWrapper w : this.revWrappers) {
                if (String.isNotBlank(w.tecnico)) { this.techName = w.tecnico; break; }
            }
            this.pyatzSignatureUrl = findSignatureUrl(this.techName);
            // Firma cliente: última revisión firmada (Fallback históricos)
            for (RevWrapper w : this.revWrappers) {
                if (w.hasSignature) {
                    this.clientSigUrl  = w.sigUrl;
                    this.clientSigName = w.sigName;
                    if (String.isNotBlank(w.rev.Nombre_Firmante__c)) {
                        this.nombreFirmante = w.rev.Nombre_Firmante__c;
                        this.cargoFirmante  = w.rev.Cargo_Firmante__c != null ? w.rev.Cargo_Firmante__c : '';
                    }
                }
            }

            // Firma cliente: buscar en todas las SAs (Nuevo flujo global)
            List<ContentDocumentLink> saLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :saIds];
            if (!saLinks.isEmpty()) {
                Set<Id> cDocIds = new Set<Id>();
                for (ContentDocumentLink l : saLinks) cDocIds.add(l.ContentDocumentId);
                List<ContentVersion> cvs = [SELECT Id, Description FROM ContentVersion WHERE ContentDocumentId IN :cDocIds AND Title LIKE 'SignClean_%' AND IsLatest = true ORDER BY CreatedDate DESC LIMIT 1];
                if (!cvs.isEmpty()) {
                    this.clientSigUrl  = '/sfc/servlet.shepherd/version/download/' + cvs[0].Id;
                    this.clientSigName = cvs[0].Description;
                    for (ServiceAppointment sa : sas) {
                        if (String.isNotBlank(sa.Nombre_Firmante__c)) {
                            this.nombreFirmante = sa.Nombre_Firmante__c;
                            this.cargoFirmante  = sa.Cargo_Firmante__c != null ? sa.Cargo_Firmante__c : '';
                        }
                    }
                }
            }
        }

        String safeAcct = safeFileName(this.accountName != null ? this.accountName : '');
        ApexPages.currentPage().getHeaders().put('content-disposition',
            'inline; filename="Certificado-OT' + this.workOrderNum
            + (String.isNotBlank(safeAcct) ? '-' + safeAcct : '') + '.pdf"');
    }

    private void loadQuoteLineItems(Id quoteId) {
        List<LineItemWrapper> items = new List<LineItemWrapper>();
        String lastSep = '';
        for (QuoteLineItem qli : [
            SELECT Id, Product2.Name, Product2.ProductCode, Quantity,
                   Description, Descripcion_Detallada__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ]) {
            if (qli.Quantity == null || qli.Quantity == 0) {
                lastSep = qli.Product2 != null ? qli.Product2.Name : '';
            } else {
                LineItemWrapper li = new LineItemWrapper();
                li.isSeparator      = false;
                li.sectionHeader    = lastSep;
                li.hasSectionHeader = String.isNotBlank(lastSep);
                lastSep             = '';
                li.code        = qli.Product2 != null && String.isNotBlank(qli.Product2.ProductCode)
                                 ? qli.Product2.ProductCode : '';
                li.nombre      = qli.Product2 != null ? qli.Product2.Name : '';
                String prodDesc = String.isNotBlank(qli.Descripcion_Detallada__c)
                                 ? qli.Descripcion_Detallada__c
                                 : (String.isNotBlank(qli.Description) ? qli.Description : '');
                if (String.isNotBlank(prodDesc) && !prodDesc.contains('<')) {
                    prodDesc = formatPlainTextToHtml(prodDesc);
                } else if (String.isNotBlank(prodDesc)) {
                    prodDesc = fixListStyles(prodDesc);
                }
                li.descripcion    = prodDesc;
                li.hasDescripcion = String.isNotBlank(prodDesc);
                items.add(li);
            }
        }
        this.lineItems    = items;
        this.hasLineItems = !items.isEmpty();
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private void buildRevWrappers(List<Revision_Cita_Servicio__c> revs, Map<Id, String> saZonaMap, Map<Id, String> saTratMap) {
        Set<Id> revIds = new Set<Id>();
        for (Revision_Cita_Servicio__c r : revs) revIds.add(r.Id);

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
        Map<Id, String[]>           revSigs   = new Map<Id, String[]>();

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
            w.rev     = r;
            w.fecha   = r.Fecha_Revision__c != null
                ? r.Fecha_Revision__c.format('dd/MM/yyyy HH:mm') : '';
            w.tecnico = r.Tecnico__r != null ? r.Tecnico__r.Name : '';
            w.photos  = revPhotos.containsKey(r.Id) ? revPhotos.get(r.Id) : new List<PhotoWrapper>();
            w.hasPhotos = !w.photos.isEmpty();

            w.photoRows = new List<List<PhotoWrapper>>();
            List<PhotoWrapper> currentRow = new List<PhotoWrapper>();
            for (PhotoWrapper ph : w.photos) {
                currentRow.add(ph);
                if (currentRow.size() == 2) { w.photoRows.add(currentRow); currentRow = new List<PhotoWrapper>(); }
            }
            if (!currentRow.isEmpty()) w.photoRows.add(currentRow);

            if (revSigs.containsKey(r.Id)) {
                w.sigUrl = revSigs.get(r.Id)[0]; w.sigName = revSigs.get(r.Id)[1]; w.hasSignature = true;
            } else { w.hasSignature = false; }

            w.hasObs     = String.isNotBlank(r.Observaciones__c);
            w.answers    = parseFormData(r.Datos_Formulario__c);
            w.hasAnswers = !w.answers.isEmpty();
            w.hasDefics  = false;
            for (RespuestaWrapper rw : w.answers) { if (rw.hasDefic) { w.hasDefics = true; break; } }

            Integer mid = (w.answers.size() + 1) / 2;
            w.answersLeft  = new List<RespuestaWrapper>();
            w.answersRight = new List<RespuestaWrapper>();
            for (Integer i = 0; i < w.answers.size(); i++) {
                if (i < mid) w.answersLeft.add(w.answers[i]); else w.answersRight.add(w.answers[i]);
            }

            List<RespuestaWrapper> allDefics = new List<RespuestaWrapper>();
            for (RespuestaWrapper rw : w.answers) { if (rw.hasDefic) allDefics.add(rw); }
            Integer defMid = (allDefics.size() + 1) / 2;
            w.deficsLeft  = new List<RespuestaWrapper>();
            w.deficsRight = new List<RespuestaWrapper>();
            for (Integer i = 0; i < allDefics.size(); i++) {
                if (i < defMid) w.deficsLeft.add(allDefics[i]); else w.deficsRight.add(allDefics[i]);
            }

            if (w.hasDefics)    this.totalDeficiencias++;
            if (w.hasSignature) this.totalFirmadas++;

            String fullZona = saZonaMap.containsKey(r.Cita_Servicio__c) ? saZonaMap.get(r.Cita_Servicio__c) : '';
            if (String.isNotBlank(fullZona)) {
                // Dividir por saltos de línea, punto y coma, o coma seguida de espacio
                String[] parts = fullZona.split('\n|;|, ');
                Integer idx = (r.Numero_Revision__c != null) ? (Integer)r.Numero_Revision__c.longValue() - 1 : 0;
                if (idx < 0) idx = 0;
                
                if (parts.size() > 1 && idx < parts.size()) {
                    w.zona = parts[idx].trim();
                } else if (parts.size() > 1 && idx >= parts.size()) {
                    w.zona = parts[parts.size() - 1].trim();
                } else {
                    w.zona = fullZona;
                }
            } else {
                w.zona = '';
            }

            w.tratamiento    = saTratMap.containsKey(r.Cita_Servicio__c) ? saTratMap.get(r.Cita_Servicio__c) : '';
            w.hasTratamiento = String.isNotBlank(w.tratamiento);
            w.showTratHeader = false;
            w.showZonaHeader = false;
            this.revWrappers.add(w);
        }

        // Ordenar por tratamiento → zona → Numero_Revision__c
        List<RevSortKey> sortKeys = new List<RevSortKey>();
        for (RevWrapper w : this.revWrappers) sortKeys.add(new RevSortKey(w));
        sortKeys.sort();
        this.revWrappers = new List<RevWrapper>();
        for (RevSortKey sk : sortKeys) this.revWrappers.add(sk.w);

        // Setear flags de cabecera y isFirst
        String lastTrat = null; String lastZona = null; Boolean firstItem = true;
        for (RevWrapper w : this.revWrappers) {
            w.showZonaHeader = (lastZona == null || !w.zona.equals(lastZona));
            w.showTratHeader = w.showZonaHeader || (lastTrat == null || !w.tratamiento.equals(lastTrat));
            w.isFirst  = firstItem; firstItem = false;
            lastTrat   = w.tratamiento;
            lastZona   = w.zona;
        }
    }

    private static String safeFileName(String raw) {
        if (String.isBlank(raw)) return '';
        return raw
            .replace('á','a').replace('é','e').replace('í','i').replace('ó','o').replace('ú','u')
            .replace('Á','A').replace('É','E').replace('Í','I').replace('Ó','O').replace('Ú','U')
            .replace('ñ','n').replace('Ñ','N').replace('ü','u').replace('Ü','U')
            .replaceAll('[^a-zA-Z0-9\\-]', '_')
            .replaceAll('_+', '_')
            .removeEnd('_');
    }

    private static String fixListStyles(String html) {
        return html
            .replaceAll('(?i)<ul([^>]*)>', '<ul$1 style="list-style-position:inside;padding:0;margin:3pt 0;">')
            .replaceAll('(?i)<ol([^>]*)>', '<ol$1 style="list-style-position:inside;padding:0;margin:3pt 0;">')
            .replaceAll('(?i)<li([^>]*)>', '<li$1 style="margin-bottom:2pt;">');
    }

    private static String formatPlainTextToHtml(String text) {
        if (String.isBlank(text)) return '';
        List<String> lines = text.trim().split('\n');
        String html = '';
        for (String line : lines) {
            String t = line.trim();
            if (String.isBlank(t)) continue;
            html += '<p style="margin:3pt 0;">' + t + '</p>';
        }
        return html;
    }

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