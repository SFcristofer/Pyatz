public with sharing class QuoteContractPDFController {
    public Quote quoteRecord {get; set;}
    public List<QuoteLineItem> selectedLineItems {get; set;}
    public Map<String, Boolean> config {get; set;}
    public String fechaHoy {get; set;}
    public Decimal totalContrato {get; set;}
    
    public String quoteNumberShort {get; set;}
    public String firmanteNombre {get; set;}
    public String firmanteCargo {get; set;}
    public String firmanteCliente {get; set;}
    public String signatureUrl {get; set;}
    public String fechaContrato {get; set;}

    public QuoteContractPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        this.fechaHoy = Date.today().format();
        this.totalContrato = 0;

        Date hoy = Date.today();
        String[] meses = new String[]{'ENERO','FEBRERO','MARZO','ABRIL','MAYO','JUNIO','JULIO','AGOSTO','SEPTIEMBRE','OCTUBRE','NOVIEMBRE','DICIEMBRE'};
        this.fechaContrato = String.valueOf(hoy.day()) + ' DE ' + meses[hoy.month()-1] + ' DEL ' + String.valueOf(hoy.year());

        this.quoteRecord = [SELECT Id, Name, QuoteNumber,
                                   Account.Name, Account.BillingStreet, Account.BillingCity, Account.Phone,
                                   Account.Nombre_RL__c, Account.RFC__c, Account.Registro_IMSS__c,
                                   Account.Escritura_Publica__c, Account.Dia_Esc_Pub__c, Account.Mes_Esc_Pub__c, Account.Ano_Esc_Pub__c,
                                   Account.Notaria__c, Account.Ciudad_Notaria__c,
                                   Account.Folio_Mercantil__c, Account.Dia_Folio_Merc__c, Account.Mes_Folio_Merc__c, Account.Ano_Folio_Merc__c,
                                   Account.Calle_de_envio__c, Account.No_Ext__c, Account.No_Int__c, Account.Colonia__c,
                                   Account.Ciudad_de_envio__c, Account.Codigo_postal_de_envio__c,
                                   Account.Estado_o_provincia_de_envio__c, Account.Pais_de_envio__c,
                                   Account.Correo_electronico_RL__c, Account.Extension__c,
                                   Account.Facturas_sin_pago_para_sancion__c,
                                   Account.Plan_Generador__c, Account.Permiso_Entidad__c,
                                   Account.Calle_Notificacion__c, Account.Ext_Notificacion__c, Account.Int_Notificacion__c,
                                   Account.Colonia_Notificacion__c, Account.Alcaldia_Notificacion__c,
                                   Account.CP_Notificacion__c, Account.CD_Notificacion__c,
                                   Account.Pais_Notificacion__c, Account.Correo_Notificacion__c, Account.Tel_Notificacion__c,
                                   Account.Proceso_liberacion_pedidos__c, Account.Proceso_ingreso_de_facturas__c,
                                   Contact.Name, CreatedBy.Name, CreatedBy.Email, CreatedDate,
                                   TotalPrice, Business_Lines_Selected__c, Technical_Sedes__c,
                                   Introduction_Text__c, Warranty_Text__c, Description, Subtotal, Tax, Discount
                            FROM Quote WHERE Id = :quoteId];

        // Folio sin ceros iniciales
        if (String.isNotBlank(this.quoteRecord.QuoteNumber)) {
            String digits = this.quoteRecord.QuoteNumber.replaceAll('[^0-9]', '');
            String prefix = this.quoteRecord.QuoteNumber.replaceAll('[0-9]', '');
            this.quoteNumberShort = (String.isNotBlank(digits) ? prefix + String.valueOf(Integer.valueOf(digits)) : this.quoteRecord.QuoteNumber);
        }

        Map<String, String> params = ApexPages.currentPage().getParameters();
        this.config = new Map<String, Boolean>();
        List<String> keys = new List<String>{'show_total', 'show_line_prices'};
        for (String key : keys) {
            this.config.put(key, !params.containsKey(key) || params.get(key) == 'true');
        }

        // 1. Filtrar partidas
        String selectedIdsParam = params.get('selectedItems');
        if (String.isNotBlank(selectedIdsParam)) {
            this.selectedLineItems = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, 
                                             Discount, Description FROM QuoteLineItem 
                                      WHERE QuoteId = :quoteId AND Id IN :selectedIdsParam.split(',')];
            for(QuoteLineItem item : this.selectedLineItems) {
                this.totalContrato += (item.TotalPrice != null ? item.TotalPrice : 0) * 1.16;
            }
        }

        // 2. Lógica de Firmas Dinámica
        String creatorId = params.get('createdBy');
        String managerId = params.get('managedBy');
        String sigSource = params.get('sigSource');
        Id targetUserId = (sigSource == 'manager' && String.isNotBlank(managerId)) ? (Id)managerId : (Id)creatorId;

        if (targetUserId != null) {
            User u = [SELECT Name, Title FROM User WHERE Id = :targetUserId LIMIT 1];
            this.firmanteNombre = u.Name;
            this.firmanteCargo = u.Title != null ? u.Title : 'Representante Comercial';
        } else {
            this.firmanteNombre = quoteRecord.CreatedBy.Name;
            this.firmanteCargo = 'Gerencia Comercial';
        }

        this.firmanteCliente = params.get('clientSigner');
        if (String.isBlank(this.firmanteCliente)) {
            this.firmanteCliente = quoteRecord.Contact.Name;
        }

        this.signatureUrl = findSignatureUrl(this.firmanteNombre);

        // 3. Formatear campos long text para el PDF
        if (String.isNotBlank(this.quoteRecord.Introduction_Text__c)) {
            this.quoteRecord.Introduction_Text__c = fixListStyles(this.quoteRecord.Introduction_Text__c);
            this.quoteRecord.Introduction_Text__c = fixParagraphStyles(this.quoteRecord.Introduction_Text__c);
        }
        if (String.isNotBlank(this.quoteRecord.Warranty_Text__c)) {
            this.quoteRecord.Warranty_Text__c = fixListStyles(this.quoteRecord.Warranty_Text__c);
            this.quoteRecord.Warranty_Text__c = fixParagraphStyles(this.quoteRecord.Warranty_Text__c);
        }
        if (String.isNotBlank(this.quoteRecord.Description)) {
            if (!this.quoteRecord.Description.contains('<')) {
                this.quoteRecord.Description = formatPlainTextToHtml(this.quoteRecord.Description);
            } else {
                this.quoteRecord.Description = fixListStyles(this.quoteRecord.Description);
            }
        }
        if (this.selectedLineItems != null) {
            for (QuoteLineItem qli : this.selectedLineItems) {
                if (String.isNotBlank(qli.Descripcion_Detallada__c)) {
                    if (!qli.Descripcion_Detallada__c.contains('<')) {
                        qli.Descripcion_Detallada__c = formatPlainTextToHtml(qli.Descripcion_Detallada__c);
                    } else {
                        qli.Descripcion_Detallada__c = fixListStyles(qli.Descripcion_Detallada__c);
                    }
                }
            }
        }
    }

    private static String fixParagraphStyles(String html) {
        if (String.isBlank(html)) return html;
        String r = html.replaceAll('(?i)</?body[^>]*>', '');
        r = r.replaceAll('(?i)<p[^>]*>(\\s*(&nbsp;|&#160;|<br\\s*/?>)\\s*)*</p>', '');
        r = r.replaceAll('(?i)<p(\\s[^>]*)?\\s+style="[^"]*"([^>]*)>', '<p$1$2>');
        r = r.replaceAll('(?i)<div(\\s[^>]*)?\\s+style="[^"]*"([^>]*)>', '<div$1$2>');
        r = r.replaceAll('(?i)<span(\\s[^>]*)?\\s+style="[^"]*"([^>]*)>', '<span$1$2>');
        r = r.replaceAll('(?i)<p([^>]*)>', '<p$1 style="margin:4pt 0; padding:0;">');
        return r;
    }

    private static String fixListStyles(String html) {
        return html
            .replaceAll('(?i)<ul([^>]*)>', '<ul$1 style="list-style-position:inside;padding:0;margin:4pt 0;">')
            .replaceAll('(?i)<ol([^>]*)>', '<ol$1 style="list-style-position:inside;padding:0;margin:4pt 0;">')
            .replaceAll('(?i)<li([^>]*)>', '<li$1 style="margin-bottom:2pt;">');
    }

    private static String renderItems(List<String> parts) {
        String html = '';
        Boolean inList = false;
        for (String part : parts) {
            String item = part.trim().removeStart('- ').removeStart('• ').removeStart('· ');
            if (String.isBlank(item)) continue;
            Boolean isHeader = item.endsWith(':') && item.length() < 120;
            if (isHeader) {
                if (inList) { html += '</ul>'; inList = false; }
                html += '<p style="font-weight:bold;margin:6pt 0 2pt 0;">' + item + '</p>';
            } else {
                if (!inList) { html += '<ul style="margin:0 0 4pt 0;padding-left:15pt;text-align:justify;">'; inList = true; }
                html += '<li style="margin-bottom:3pt;">' + item + '</li>';
            }
        }
        if (inList) html += '</ul>';
        return html;
    }

    private static String formatPlainTextToHtml(String text) {
        String t = text.trim();
        List<String> lines = t.split('\n');
        if (lines.size() > 1) return renderItems(lines);
        List<String> parts = t.split(' - ');
        if (parts.size() > 2) return renderItems(parts);
        return '<p style="text-align:justify;">' + t + '</p>';
    }

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
            if (allMatch) {
                return '/resource/' + sr.SystemModstamp.getTime() + '/' + sr.Name;
            }
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
        return [SELECT Id, PricebookEntryId, Product2Id, Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, 
                       ListPrice, Description, Discount, Quote.Technical_Sedes__c
                FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY CreatedDate ASC];
    }
}