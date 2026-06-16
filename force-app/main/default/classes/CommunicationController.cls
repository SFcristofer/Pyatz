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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getContactsFromLatestQuoteSedes(Id oppId) {
        List<Map<String, String>> contacts = new List<Map<String, String>>();
        try {
            // 1. Obtener la Quote más reciente con sus marcadores
            List<Quote> latestQuotes = [SELECT Markers_Data__c FROM Quote WHERE OpportunityId = :oppId ORDER BY CreatedDate DESC LIMIT 1];
            if (latestQuotes.isEmpty() || String.isBlank(latestQuotes[0].Markers_Data__c)) return contacts;

            // 2. Extraer IDs de sedes del JSON
            String decodedJson = '';
            try {
                decodedJson = EncodingUtil.base64Decode(latestQuotes[0].Markers_Data__c).toString();
            } catch (Exception e) {
                // Fallback si no está en Base64
                decodedJson = latestQuotes[0].Markers_Data__c;
            }
            
            Map<String, Object> fullState = (Map<String, Object>)JSON.deserializeUntyped(decodedJson);
            
            Set<Id> sedeIds = new Set<Id>();
            if (fullState.containsKey('selectedSedesIds')) {
                List<Object> ids = (List<Object>)fullState.get('selectedSedesIds');
                for (Object idObj : ids) sedeIds.add((Id)idObj);
            }

            if (sedeIds.isEmpty()) return contacts;

            // 3. Consultar contactos de esas sedes
            for (Contact c : [SELECT Id, Name, Email, Title, Account.Name FROM Contact WHERE AccountId IN :sedeIds AND Email != null ORDER BY Account.Name, Name]) {
                contacts.add(new Map<String, String>{
                    'id' => c.Id,
                    'name' => c.Name,
                    'email' => c.Email,
                    'title' => c.Title != null ? c.Title : '',
                    'sede' => c.Account.Name,
                    'group' => 'CLIENTE'
                });
            }
        } catch (Exception e) { System.debug('Error en getContactsFromLatestQuoteSedes: ' + e.getMessage()); }
        return contacts;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInternalTeam(Id oppId) {
        List<Map<String, String>> team = new List<Map<String, String>>();
        try {
            Opportunity opp = [SELECT Owner.Name, Owner.Email, Account.Owner.Name, Account.Owner.Email, OwnerId, Account.OwnerId FROM Opportunity WHERE Id = :oppId];
            
            team.add(new Map<String, String>{
                'id' => opp.OwnerId,
                'name' => opp.Owner.Name + ' (Dueño)',
                'email' => opp.Owner.Email,
                'group' => 'INTERNO',
                'role' => 'Ventas'
            });
            
            if (opp.Account.Owner.Email != opp.Owner.Email) {
                team.add(new Map<String, String>{
                    'id' => opp.Account.OwnerId,
                    'name' => opp.Account.Owner.Name + ' (Cuenta)',
                    'email' => opp.Account.Owner.Email,
                    'group' => 'INTERNO',
                    'role' => 'Admin'
                });
            }
            // MEJORA FUTURA: Se requiere campo personalizado en WorkOrder para vincular técnicos automáticamente.
        } catch (Exception e) { System.debug('Error en getInternalTeam: ' + e.getMessage()); }
        return team;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPyatzQueues() {
        List<Map<String, String>> queues = new List<Map<String, String>>();
        try {
            for (Group g : [SELECT Id, Name, Email FROM Group WHERE Type = 'Queue' AND Name LIKE '%PYATZ%' ORDER BY Name ASC LIMIT 50]) {
                queues.add(new Map<String, String>{
                    'id' => g.Id,
                    'name' => g.Name,
                    'group' => 'COLA'
                });
            }
        } catch (Exception e) { System.debug('Error en getPyatzQueues: ' + e.getMessage()); }
        return queues;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchInternalUsers(String searchTerm) {
        List<Map<String, String>> users = new List<Map<String, String>>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) return users;
        String searchKey = '%' + searchTerm + '%';
        try {
            for (User u : [SELECT Id, Name, Email, Title FROM User WHERE Name LIKE :searchKey AND IsActive = true AND UserType = 'Standard' ORDER BY Name ASC LIMIT 15]) {
                users.add(new Map<String, String>{
                    'id' => u.Id,
                    'name' => u.Name,
                    'email' => u.Email,
                    'title' => u.Title != null ? u.Title : 'Usuario',
                    'group' => 'USUARIO'
                });
            }
        } catch (Exception e) { System.debug('Error en searchInternalUsers: ' + e.getMessage()); }
        return users;
    }

    @AuraEnabled
    public static void sendInternalEmail(Id oppId, String toEmail, String ccEmail, String bccEmail, String subject, String body, List<Id> queueIds, List<Id> userIds, List<Map<String, String>> selectedAttachments) {
        EmailService.sendInternalEmail(oppId, toEmail, ccEmail, bccEmail, subject, body, queueIds, userIds, selectedAttachments);
    }
}