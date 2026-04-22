/**
 * Servicio encargado de la gestión de archivos, vinculación de documentos 
 * al Repositorio Maestro de Pyatz y mantenimiento de evidencias técnicas.
 */
public with sharing class FileService {

    /**
     * Recupera archivos PDF relacionados a un registro específico.
     */
    public static List<Map<String, Object>> getRelatedFiles(Id recordId) {
        List<Map<String, Object>> files = new List<Map<String, Object>>();
        for (ContentDocumentLink link : [SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, 
                                                ContentDocument.LatestPublishedVersionId, ContentDocument.ContentSize
                                         FROM ContentDocumentLink WHERE LinkedEntityId = :recordId AND ContentDocument.FileExtension = 'pdf']) {
            files.add(new Map<String, Object>{ 'id' => link.ContentDocumentId, 'versionId' => link.ContentDocument.LatestPublishedVersionId, 'title' => link.ContentDocument.Title, 'extension' => link.ContentDocument.FileExtension, 'size' => (link.ContentDocument.ContentSize / 1024) + ' KB' });
        }
        return files;
    }

    /**
     * Recupera adjuntos disponibles (Presupuestos, Levantamientos y Archivos) para una oportunidad.
     */
    public static Map<String, List<Map<String, String>>> getAvailableAttachments(Id oppId) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        List<Map<String, String>> quotes = new List<Map<String, String>>();
        for (Quote q : [SELECT Id, Name, QuoteNumber FROM Quote WHERE OpportunityId = :oppId ORDER BY CreatedDate DESC]) quotes.add(new Map<String, String>{'id' => q.Id, 'name' => 'Presupuesto: ' + q.QuoteNumber + ' - ' + q.Name, 'type' => 'Quote'});
        result.put('quotes', quotes);
        List<Map<String, String>> surveys = new List<Map<String, String>>();
        for (AggregateResult ar : [SELECT Tipo_Servicio__c FROM Levantamiento_Tecnico__c WHERE Oportunidad__c = :oppId GROUP BY Tipo_Servicio__c]) surveys.add(new Map<String, String>{'id' => oppId, 'name' => 'Levantamiento: ' + (String)ar.get('Tipo_Servicio__c'), 'type' => 'Survey', 'subType' => (String)ar.get('Tipo_Servicio__c')});
        result.put('surveys', surveys);
        List<Map<String, String>> files = new List<Map<String, String>>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension FROM ContentDocumentLink WHERE LinkedEntityId = :oppId AND ContentDocument.FileExtension = 'pdf']) files.add(new Map<String, String>{'id' => cdl.ContentDocumentId, 'name' => 'Archivo: ' + cdl.ContentDocument.Title, 'type' => 'File'});
        result.put('files', files);
        return result;
    }

    /**
     * Identifica el estado de documentos obligatorios basados en etiquetas [TAG].
     */
    public static Map<String, String> getDocumentStates(Id opportunityId) {
        Map<String, String> states = new Map<String, String>();
        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        Id pyatzMasterId = getOrCreatePyatzMasterAccount();
        Set<Id> entities = new Set<Id>{opportunityId, opp.AccountId, pyatzMasterId};
        for (ContentDocumentLink l : [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId IN :entities]) {
            String title = l.ContentDocument.Title; 
            if (title.startsWith('[') && title.contains(']')) { 
                String tag = title.substringBetween('[', ']').toUpperCase(); 
                if (!states.containsKey(tag)) states.put(tag, l.ContentDocumentId); 
            }
        }
        return states;
    }

    /**
     * Recupera una galería de imágenes y archivos marcados como evidencia técnica.
     */
    public static List<Map<String, Object>> getEvidenceGallery(Id opportunityId) {
        List<Map<String, Object>> gallery = new List<Map<String, Object>>();
        Set<Id> docIds = new Set<Id>(); 
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :opportunityId]) docIds.add(cdl.ContentDocumentId);
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [SELECT Id, Title, FileExtension, ContentDocumentId, CreatedDate FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true ORDER BY CreatedDate DESC]) {
                String title = cv.Title; 
                if (title.startsWith('[') && title.contains(']')) {
                    String tag = title.substringBetween('[', ']'); 
                    String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
                    Boolean isImg = new Set<String>{'png', 'jpg', 'jpeg', 'gif'}.contains(ext);
                    gallery.add(new Map<String, Object>{ 'id' => cv.ContentDocumentId, 'versionId' => cv.Id, 'tag' => tag.toUpperCase(), 'title' => title.substringAfter(']').replace('-', '').trim(), 'ext' => ext, 'isImage' => isImg, 'previewUrl' => isImg ? '/sfc/servlet.shepherd/version/download/' + cv.Id : null, 'date' => cv.CreatedDate });
                }
            }
        }
        return gallery;
    }

    /**
     * Renombra y vincula dinámicamente un archivo al Repositorio Maestro o a la Cuenta del Cliente.
     */
    public static void renameAndLinkFile(Id documentId, String docType) {
        ContentDocument doc = [SELECT Id, Title FROM ContentDocument WHERE Id = :documentId LIMIT 1];
        doc.Title = '[' + docType.toUpperCase() + '] - ' + doc.Title; 
        update doc;
        if (docType.toUpperCase().startsWith('PY_')) { 
            linkDocumentToEntity(documentId, getOrCreatePyatzMasterAccount()); 
        } else { 
            Id oppId = getOppIdFromDocument(documentId); 
            if (oppId != null) { 
                Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1]; 
                if (opp.AccountId != null) linkDocumentToEntity(documentId, opp.AccountId); 
            } 
        }
    }

    public static void deleteDocument(Id documentId) {
        delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
    }

    // --- MÉTODOS PRIVADOS DE SOPORTE ---
    
    private static Id getOrCreatePyatzMasterAccount() {
        List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Pyatz Corporativo' LIMIT 1];
        if (!accs.isEmpty()) return accs[0].Id;
        Account pyatz = new Account(Name = 'Pyatz Corporativo', Type = 'Other', Description = 'Repositorio Maestro'); 
        insert pyatz; 
        return pyatz.Id;
    }

    private static Id getOppIdFromDocument(Id docId) {
        for (ContentDocumentLink cdl : [SELECT LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :docId]) { 
            if (cdl.LinkedEntityId.getSObjectType().getDescribe().getName() == 'Opportunity') return cdl.LinkedEntityId; 
        }
        return null;
    }

    private static void linkDocumentToEntity(Id docId, Id entityId) {
        if ([SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId = :docId AND LinkedEntityId = :entityId].isEmpty()) {
            insert new ContentDocumentLink(ContentDocumentId = docId, LinkedEntityId = entityId, ShareType = 'V', Visibility = 'AllUsers');
        }
    }
}
