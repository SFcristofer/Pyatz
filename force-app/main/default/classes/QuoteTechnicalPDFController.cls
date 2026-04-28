public with sharing class QuoteTechnicalPDFController {
    public Quote technicalQuote {get; set;}
    public String versionId {get; set;}
    public String signatureUrl {get; set;}
    public String quoteNumberShort {get; set;}
    public String atencionNames {get; set;}
    public String metodoPago {get; set;}
    public String tipoTrabajo {get; set;}
    public String descripcionPago {get; set;}
    public Map<Id, String> htmlDescriptions {get; set;}

    public QuoteTechnicalPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        this.htmlDescriptions = new Map<Id, String>();
        
        // 1. Cargamos datos
        this.technicalQuote = [SELECT Id, Name, QuoteNumber, AccountId, Account.Name, ContactId, Contact.Name, Opportunity.Name, 
                                     Show_Introduction__c, Introduction_Text__c, Phone, Email, Discount,
                                     Show_Warranty__c, Warranty_Text__c, Markers_Data__c,
                                     Business_Lines_Selected__c, Technical_Sedes__c, CreatedBy.Name, CreatedBy.Email, CreatedDate,
                                     Subtotal, Tax, TotalPrice, Description,
                                     (SELECT Id, Product2.Name, Product2.ProductCode, Description, Pyatz_Technical_Description__c, Descripcion_Detallada__c, Quantity, ListPrice, UnitPrice, Discount, TotalPrice
                                      FROM QuoteLineItems)
                              FROM Quote 
                              WHERE Id = :quoteId];

        // Folio sin ceros iniciales
        if (String.isNotBlank(this.technicalQuote.QuoteNumber)) {
            String digits = this.technicalQuote.QuoteNumber.replaceAll('[^0-9]', '');
            String prefix = this.technicalQuote.QuoteNumber.replaceAll('[0-9]', '');
            this.quoteNumberShort = (String.isNotBlank(digits) ? prefix + String.valueOf(Integer.valueOf(digits)) : this.technicalQuote.QuoteNumber);
        }

        // 1.1. Procesar etiquetas dinámicas (Lazy Loading)
        if (this.technicalQuote.Introduction_Text__c != null) {
            this.technicalQuote.Introduction_Text__c = this.technicalQuote.Introduction_Text__c
                .replace('[[SEDES]]', this.technicalQuote.Technical_Sedes__c != null ? this.technicalQuote.Technical_Sedes__c : '')
                .replace('[[CLIENTE]]', this.technicalQuote.Account.Name != null ? this.technicalQuote.Account.Name : '')
                .replace('[[CUENTA]]', this.technicalQuote.Account.Name != null ? this.technicalQuote.Account.Name : '')
                .replace('[[FOLIO]]', this.technicalQuote.QuoteNumber != null ? this.technicalQuote.QuoteNumber : '');
        }
        if (this.technicalQuote.Warranty_Text__c != null) {
            this.technicalQuote.Warranty_Text__c = this.technicalQuote.Warranty_Text__c
                .replace('[[SEDES]]', this.technicalQuote.Technical_Sedes__c != null ? this.technicalQuote.Technical_Sedes__c : '')
                .replace('[[CLIENTE]]', this.technicalQuote.Account.Name != null ? this.technicalQuote.Account.Name : '')
                .replace('[[CUENTA]]', this.technicalQuote.Account.Name != null ? this.technicalQuote.Account.Name : '')
                .replace('[[FOLIO]]', this.technicalQuote.QuoteNumber != null ? this.technicalQuote.QuoteNumber : '');
        }

        // 2. Extraer HTML y datos de la memoria persistente
        if (String.isNotBlank(this.technicalQuote.Markers_Data__c)) {
            try {
                String decodedJson = EncodingUtil.base64Decode(this.technicalQuote.Markers_Data__c).toString();
                Map<String, Object> fullState = (Map<String, Object>)JSON.deserializeUntyped(decodedJson);
                
                // --- PROCESAR CONTACTOS MÚLTIPLES ---
                String atencionNames = '';
                if (fullState.containsKey('selectedContactNames')) {
                    atencionNames = (String)fullState.get('selectedContactNames');
                } else if (this.technicalQuote.ContactId != null) {
                    atencionNames = this.technicalQuote.Contact.Name;
                }
                this.atencionNames = atencionNames; // ASIGNACIÓN CLAVE

                // --- PROCESAR DATOS DE PAGO ---
                List<String> metodos = new List<String>();
                if (fullState.containsKey('pagoTransferencia') && (Boolean)fullState.get('pagoTransferencia')) metodos.add('Transferencia');
                if (fullState.containsKey('pagoTarjeta') && (Boolean)fullState.get('pagoTarjeta')) metodos.add('Tarjeta');
                this.metodoPago = metodos.isEmpty() ? 'A convenir' : String.join(metodos, ' / ');

                List<String> tipos = new List<String>();
                if (fullState.containsKey('trabajoPuntual') && (Boolean)fullState.get('trabajoPuntual')) tipos.add('Trabajo Puntual');
                if (fullState.containsKey('ventaProducto') && (Boolean)fullState.get('ventaProducto')) tipos.add('Venta de Producto');
                if (fullState.containsKey('trabajoMantenimiento') && (Boolean)fullState.get('trabajoMantenimiento')) tipos.add('Mantenimiento');
                this.tipoTrabajo = tipos.isEmpty() ? 'N/A' : String.join(tipos, ' / ');

                if (fullState.containsKey('observacionesPago')) {
                    this.descripcionPago = (String)fullState.get('observacionesPago');
                } else {
                    this.descripcionPago = this.technicalQuote.Description;
                }
                // ------------------------------

                if (this.technicalQuote.Introduction_Text__c != null) {
                    this.technicalQuote.Introduction_Text__c = this.technicalQuote.Introduction_Text__c.replace('[[ATENCION]]', atencionNames);
                }
                if (this.technicalQuote.Warranty_Text__c != null) {
                    this.technicalQuote.Warranty_Text__c = this.technicalQuote.Warranty_Text__c.replace('[[ATENCION]]', atencionNames);
                }
                // ------------------------------------

                if (fullState.containsKey('serviciosData')) {
                    List<Object> servicios = (List<Object>)fullState.get('serviciosData');
                    // Mapear por nombre de producto y sede para coincidir con las líneas
                    for (Object obj : servicios) {
                        Map<String, Object> s = (Map<String, Object>)obj;
                        String html = (String)s.get('detalleTecnicoHtml');
                        String key = (String)s.get('descripcion'); // \"Producto - Sede\"
                        
                        for (QuoteLineItem qli : this.technicalQuote.QuoteLineItems) {
                            String qliKey = qli.Product2.Name + ' - ' + (qli.Description != null ? qli.Description.substringBefore('\n') : '');
                            if (qliKey.contains(qli.Product2.Name)) {
                                this.htmlDescriptions.put(qli.Id, html);
                            }
                        }
                    }
                }
            } catch (Exception e) { System.debug('Error recuperando HTML: ' + e.getMessage()); }
        }
        
        // 3. Formatear descripciones y anclar marcadores de listas para el PDF
        for (QuoteLineItem qli : this.technicalQuote.QuoteLineItems) {
            if (String.isNotBlank(qli.Descripcion_Detallada__c)) {
                if (!qli.Descripcion_Detallada__c.contains('<')) {
                    qli.Descripcion_Detallada__c = formatPlainTextToHtml(qli.Descripcion_Detallada__c);
                } else {
                    qli.Descripcion_Detallada__c = fixListStyles(qli.Descripcion_Detallada__c);
                }
            }
        }
        if (String.isNotBlank(this.technicalQuote.Introduction_Text__c)) {
            this.technicalQuote.Introduction_Text__c = fixListStyles(this.technicalQuote.Introduction_Text__c);
            this.technicalQuote.Introduction_Text__c = fixParagraphStyles(this.technicalQuote.Introduction_Text__c); // REVERT: borrar esta línea
        }
        if (String.isNotBlank(this.technicalQuote.Warranty_Text__c)) {
            this.technicalQuote.Warranty_Text__c = fixListStyles(this.technicalQuote.Warranty_Text__c);
            this.technicalQuote.Warranty_Text__c = fixParagraphStyles(this.technicalQuote.Warranty_Text__c);
        }

        // 4. Buscar firma del creador en static resources
        this.signatureUrl = findSignatureUrl(this.technicalQuote.CreatedBy.Name);

        // 4. Buscar documentos
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :quoteId];
        if(!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for(ContentDocumentLink cdl : links) docIds.add(cdl.ContentDocumentId);
            
            List<ContentVersion> versions = [SELECT Id FROM ContentVersion 
                                             WHERE ContentDocumentId IN :docIds 
                                             AND Title = 'Levantamiento_Tecnico_Snapshot' 
                                             AND IsLatest = true 
                                             ORDER BY CreatedDate DESC LIMIT 1];
            if(!versions.isEmpty()) {
                this.versionId = versions[0].Id;
            }
        }
    }

    private static String fixParagraphStyles(String html) {
        if (String.isBlank(html)) return html;
        // Elimina etiquetas <body> que algunos editores añaden (causan márgenes extra en Flying Saucer)
        String r = html.replaceAll('(?i)</?body[^>]*>', '');
        // Elimina párrafos vacíos (cualquier combinación de espacios, &nbsp;, &#160;, <br>)
        r = r.replaceAll('(?i)<p[^>]*>(\\s*(&nbsp;|&#160;|<br\\s*/?>)\\s*)*</p>', '');
        // Quita style inline de <p>, <div> y <span> para eliminar letter-spacing del editor rico
        r = r.replaceAll('(?i)<p(\\s[^>]*)?\\s+style="[^"]*"([^>]*)>', '<p$1$2>');
        r = r.replaceAll('(?i)<div(\\s[^>]*)?\\s+style="[^"]*"([^>]*)>', '<div$1$2>');
        r = r.replaceAll('(?i)<span(\\s[^>]*)?\\s+style="[^"]*"([^>]*)>', '<span$1$2>');
        // Márgenes uniformes sin justify
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

            // Línea corta que termina en ':' → sub-encabezado, cierra lista anterior
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

    @TestVisible
    private static String formatPlainTextToHtml(String text) {
        String t = text.trim();

        // Si viene con saltos de línea, cada línea es un ítem
        List<String> lines = t.split('\n');
        if (lines.size() > 1) {
            return renderItems(lines);
        }

        // Si viene como un bloque separado por " - " (patrón de contratos/cláusulas)
        List<String> parts = t.split(' - ');
        if (parts.size() > 2) {
            return renderItems(parts);
        }

        // Texto sin patrón claro: párrafo justificado
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
}