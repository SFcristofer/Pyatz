/**
 * Servicio especializado en la gestión de comunicaciones por correo electrónico,
 * renderizado de plantillas y rastreo de interacciones (Engagement).
 */
public with sharing class EmailService {

    /**
     * Recupera el detalle de apertura y lectura de correos relacionados a una oportunidad.
     */
    public static List<Map<String, Object>> getEmailEngagementDetails(Id oppId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (EmailMessage em : [SELECT Id, Subject, ToAddress, Status, MessageDate, IsOpened, FirstOpenedDate, LastOpenedDate, 
                               (SELECT RelationAddress, RelationType FROM EmailMessageRelations WHERE RelationType IN ('ToAddress', 'CcAddress')) 
                               FROM EmailMessage WHERE RelatedToId = :oppId ORDER BY MessageDate DESC LIMIT 50]) {
            Map<String, Object> row = new Map<String, Object>{ 'id' => em.Id, 'subject' => em.Subject, 'sentDate' => em.MessageDate, 'isOpened' => em.IsOpened, 'firstOpen' => em.FirstOpenedDate, 'lastOpen' => em.LastOpenedDate };
            List<Map<String, String>> recipients = new List<Map<String, String>>();
            for (EmailMessageRelation rel : em.EmailMessageRelations) recipients.add(new Map<String, String>{ 'name' => rel.RelationAddress, 'email' => rel.RelationAddress, 'type' => rel.RelationType == 'ToAddress' ? 'Principal' : 'En Copia' });
            row.put('recipients', recipients);
            row.put('statusLabel', em.IsOpened ? 'Leído' : 'Enviado');
            row.put('statusClass', em.IsOpened ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_shade');
            results.add(row);
        }
        return results;
    }

    /**
     * Recupera plantillas de correo filtradas por carpetas.
     */
    public static List<Map<String, String>> getEmailTemplatesByFolders(List<String> folderNames) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        for (EmailTemplate et : [SELECT Id, Name, Folder.Name FROM EmailTemplate WHERE Folder.Name IN :folderNames AND IsActive = true ORDER BY Folder.Name, Name ASC]) {
            results.add(new Map<String, String>{'id' => et.Id, 'name' => et.Name, 'folder' => et.Folder.Name});
        }
        return results;
    }

    /**
     * Renderiza una plantilla de correo con los datos dinámicos de un presupuesto.
     */
    public static String renderTemplate(Id templateId, Id quoteId) {
        if (templateId == null || quoteId == null) return '';
        Quote q = QuoteSelector.getQuoteById(quoteId);
        Id conId = q.ContactId;
        if (conId == null) {
            List<Contact> cs = [SELECT Id FROM Contact WHERE AccountId = :q.AccountId LIMIT 1];
            if (!cs.isEmpty()) conId = cs[0].Id;
        }
        Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, conId, quoteId);
        String body = rendered.getHtmlBody() != null ? rendered.getHtmlBody() : rendered.getPlainTextBody();
        if (body != null) {
            // Localizar el inicio real del contenido (después de <body...>) de forma precisa
            String lowerBody = body.toLowerCase();
            if (lowerBody.contains('<body')) {
                Integer startIdx = lowerBody.indexOf('<body');
                Integer endBracketIdx = body.indexOf('>', startIdx);
                if (endBracketIdx != -1) body = body.substring(endBracketIdx + 1);
            }
            // Localizar el final real del contenido (antes de </body>)
            lowerBody = body.toLowerCase();
            if (lowerBody.contains('</body>')) {
                Integer endIdx = lowerBody.lastIndexOf('</body>');
                body = body.substring(0, endIdx);
            }
            
            // 0.5. Extraer SOLO el contenido real de las plantillas clásicas (Letterhead)
            // Estas plantillas envuelven todo en una <table> gigante que Quill JS no puede editar bien y causa que se borre todo con Backspace
            if (body.contains('bLabel:main')) {
                String extracted = '';
                Matcher m = Pattern.compile('(?si)<td[^>]*bLabel:main[^>]*>(.*?)</td>').matcher(body);
                while (m.find()) {
                    String innerHtml = m.group(1);
                    if (String.isNotBlank(innerHtml) && innerHtml.trim() != '&nbsp;') {
                        extracted += innerHtml + '<br/>';
                    }
                }
                if (String.isNotBlank(extracted)) {
                    body = extracted;
                }
            }

            // 0.8. Remover marcadores CDATA que rompen la interpretación del HTML en LWC
            body = body.replaceAll('<!\\[CDATA\\[', '');
            body = body.replaceAll('\\]\\]>', '');

            // 0.9. Remover envoltorios de Google Sheets que vuelven el bloque atómico
            body = body.replaceAll('(?i)<span data-sheets-root="1"[^>]*>', '');
            if (body.trim().endsWith('</span>')) {
                body = body.substring(0, body.lastIndexOf('</span>'));
            }

            // 1. Limpiar párrafos vacíos y saltos de línea basura inyectados al inicio y al final
            body = body.replaceAll('(?i)^(?:\\s|<br\\s*/?>|<p>(?:&nbsp;|\\s|<br\\s*/?>)*</p>)+', '');
            body = body.replaceAll('(?i)(?:\\s|<br\\s*/?>|<p>(?:&nbsp;|\\s|<br\\s*/?>)*</p>)+$', '');
            
            // Forzar envoltura en un div bloque para evitar que Quill borre todo como un solo nodo inline
            if (String.isNotBlank(body) && !body.toLowerCase().startsWith('<div')) {
                body = '<div>' + body + '</div>';
            }

            // 2. Aislar el pixel de rastreo de Salesforce para que no cause espacios extra
            body = body.replaceAll('(?i)(<img[^>]*?width="1"[^>]*?height="1"[^>]*?>)', '<div style="display:none;">$1</div>');
            
            // 3. Suprimir márgenes gigantes de los contenedores por defecto de Lightning
            body = body.replaceAll('(?i)padding:\\s*(?:[3-5][0-9]px|\\d{2,3}px)(?:\\s+(?:[3-5][0-9]px|\\d{2,3}px)){0,3};?', '');
        }
        return body != null ? body.trim() : '';
    }

    /**
     * Envía un correo electrónico con múltiples adjuntos (PDFs de presupuestos o archivos de Salesforce).
     */
    public static void sendEmailWithAttachments(Id oppId, String toEmail, String ccEmail, String subject, String body, List<Map<String, String>> selectedAttachments) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{toEmail}); 
            if (String.isNotBlank(ccEmail)) mail.setCcAddresses(ccEmail.split(','));
            mail.setSubject(subject); 
            mail.setHtmlBody(body); 
            mail.setWhatId(oppId); 
            mail.setSaveAsActivity(true);
            
            List<Id> contentVersionIds = new List<Id>();
            for (Map<String, String> att : selectedAttachments) {
                String type = att.get('type'); 
                Id attId = (Id)att.get('id'); 
                
                if (type == 'Quote' || type == 'Survey') {
                    PageReference pr = Page.QuoteTechnicalPDF; 
                    pr.getParameters().put('id', type == 'Quote' ? attId : oppId);
                    if (type == 'Survey') pr.getParameters().put('surveyOnly', 'true');
                    
                    Blob pdfBlob = !Test.isRunningTest() ? pr.getContentAsPDF() : Blob.valueOf('Test Content');
                    
                    // VALIDACIÓN CRÍTICA: ¿Es realmente un PDF binario o un HTML de error?
                    String base64Content = EncodingUtil.base64Encode(pdfBlob);
                    if (!base64Content.startsWith('JVBERi')) {
                        throw new AuraHandledException('Error al generar el PDF para "' + att.get('name') + '". El servidor devolvió un error. Verifique la configuración técnica.');
                    }
                    
                    ContentVersion cv = new ContentVersion();
                    cv.Title = att.get('name');
                    cv.PathOnClient = att.get('name') + '.pdf';
                    cv.VersionData = pdfBlob;
                    cv.FirstPublishLocationId = oppId; // Lo guarda en la oportunidad
                    insert cv;
                    
                    contentVersionIds.add(cv.Id);
                } else if (type == 'File') {
                    ContentVersion cv = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :attId AND IsLatest = true LIMIT 1];
                    contentVersionIds.add(cv.Id);
                }
            }
            if (!contentVersionIds.isEmpty()) {
                mail.setEntityAttachments(contentVersionIds); 
            }
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch (Exception e) { throw new AuraHandledException('Error en el motor de envío: ' + e.getMessage()); }
    }
}