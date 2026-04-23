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
            row.put('statusClass', em.IsOpened ? 'slds-theme_success' : 'slds-theme_shade');
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
        if (body != null && body.contains('<body')) { body = body.substringAfter('>'); if (body.contains('</body>')) body = body.substringBeforeLast('</body>'); }
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
            
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            for (Map<String, String> att : selectedAttachments) {
                String type = att.get('type'); 
                Id attId = (Id)att.get('id'); 
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                if (type == 'Quote' || type == 'Survey') {
                    PageReference pr = Page.QuoteTechnicalPDF; 
                    pr.getParameters().put('id', type == 'Quote' ? attId : oppId);
                    if (type == 'Survey') pr.getParameters().put('surveyOnly', 'true');
                    efa.setFileName(att.get('name') + '.pdf'); 
                    efa.setBody(!Test.isRunningTest() ? pr.getContentAsPDF() : Blob.valueOf('Test Content'));
                } else if (type == 'File') {
                    ContentVersion cv = [SELECT VersionData, Title, FileExtension FROM ContentVersion WHERE ContentDocumentId = :attId AND IsLatest = true LIMIT 1];
                    efa.setFileName(cv.Title + '.' + cv.FileExtension); 
                    efa.setBody(cv.VersionData);
                }
                attachments.add(efa);
            }
            mail.setFileAttachments(attachments); 
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch (Exception e) { throw new AuraHandledException('Error en el motor de envío: ' + e.getMessage()); }
    }
}