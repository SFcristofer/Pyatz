/**
 * Controlador de dominio para Comunicaciones (Email) y Gestión Documental (Archivos).
 */
public with sharing class CommunicationController {

    // --- ARCHIVOS Y DOCUMENTOS ---

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRelatedFiles(Id recordId) {
        return FileService.getRelatedFiles(recordId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getDocumentStates(Id opportunityId) {
        return FileService.getDocumentStates(opportunityId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEvidenceGallery(Id opportunityId) {
        return FileService.getEvidenceGallery(opportunityId);
    }

    @AuraEnabled
    public static void renameUploadedFile(Id documentId, String docType) {
        FileService.renameAndLinkFile(documentId, docType);
    }

    @AuraEnabled
    public static void deleteDocument(Id documentId) {
        FileService.deleteDocument(documentId);
    }

    // --- COMUNICACIONES Y EMAILS ---

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEmailEngagementDetails(Id oppId) {
        return EmailService.getEmailEngagementDetails(oppId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getAvailableAttachments(Id oppId) {
        return FileService.getAvailableAttachments(oppId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmailTemplatesByFolders(List<String> folderNames) {
        return EmailService.getEmailTemplatesByFolders(folderNames);
    }

    @AuraEnabled
    public static String renderTemplate(Id templateId, Id quoteId) {
        return EmailService.renderTemplate(templateId, quoteId);
    }

    @AuraEnabled
    public static void sendEmailWithAttachments(Id oppId, String toEmail, String ccEmail, String subject, String body, List<Map<String, String>> selectedAttachments) {
        EmailService.sendEmailWithAttachments(oppId, toEmail, ccEmail, subject, body, selectedAttachments);
    }
}