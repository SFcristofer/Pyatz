/**
 * Servicio encargado de la gestión de archivos, vinculación de documentos 
 * al Repositorio Maestro de Pyatz y mantenimiento de evidencias técnicas.
 * Versión: Migración a Bibliotecas de Contenido (ContentWorkspace)
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
     * Recupera el checklist dinámico basado en Metadatos y verifica existencia de archivos.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getChecklist(Id opportunityId, String category) {
        List<Map<String, Object>> checklist = new List<Map<String, Object>>();
        if (opportunityId == null) return checklist;

        // 1. Obtener estados actuales de documentos vinculados (Opp, Cuenta Cliente y Librería)
        Map<String, String> currentFiles = getDocumentStates(opportunityId);

        // 2. Consultar requisitos desde Metadatos
        for (Documento_Expediente__mdt req : [SELECT Label, Tag__c, Obligatorio__c 
                                               FROM Documento_Expediente__mdt 
                                               WHERE Categoria__c = :category 
                                               ORDER BY Label ASC]) {
            Map<String, Object> item = new Map<String, Object>();
            Boolean isLoaded = currentFiles.containsKey(req.Tag__c.toUpperCase());
            
            item.put('label', req.Label);
            item.put('tag', req.Tag__c);
            item.put('required', req.Obligatorio__c);
            item.put('status', isLoaded ? 'Cargado' : 'Pendiente');
            item.put('isLoaded', isLoaded);
            checklist.add(item);
        }
        return checklist;
    }

    /**
     * Identifica el estado de documentos obligatorios basados en etiquetas [TAG].
     * Escanea Oportunidad, Cuenta de Cliente y la Biblioteca Maestra de Pyatz.
     */
    public static Map<String, String> getDocumentStates(Id opportunityId) {
        Map<String, String> states = new Map<String, String>();
        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        
        // Entidades a escanear
        Set<Id> entities = new Set<Id>{opportunityId, opp.AccountId};
        Id libraryId = getPyatzLibraryId();
        if (libraryId != null) entities.add(libraryId);

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
                    String tag = title.substringBetween('[', ']').toUpperCase(); 
                    
                    // FILTRO: Excluir documentos administrativos de la galería técnica
                    if (tag.startsWith('CL_') || tag.startsWith('PY_')) continue;

                    String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
                    Boolean isImg = new Set<String>{'png', 'jpg', 'jpeg', 'gif'}.contains(ext);
                    gallery.add(new Map<String, Object>{ 'id' => cv.ContentDocumentId, 'versionId' => cv.Id, 'tag' => tag, 'title' => title.substringAfter(']').replace('-', '').trim(), 'ext' => ext, 'isImage' => isImg, 'previewUrl' => isImg ? '/sfc/servlet.shepherd/version/download/' + cv.Id : null, 'date' => cv.CreatedDate });
                }
            }
        }
        return gallery;
    }

    /**
     * Renombra y vincula dinámicamente un archivo a la Biblioteca Maestra o a la Cuenta del Cliente.
     */
    public static void renameAndLinkFile(Id documentId, String docType) {
        ContentDocument doc = [SELECT Id, Title FROM ContentDocument WHERE Id = :documentId LIMIT 1];
        doc.Title = '[' + docType.toUpperCase() + '] - ' + doc.Title; 
        update doc;

        if (docType.toUpperCase().startsWith('PY_')) { 
            Id libraryId = getPyatzLibraryId();
            if (libraryId != null) linkDocumentToEntity(documentId, libraryId);
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
    
    private static Id getPyatzLibraryId() {
        // Busca la Biblioteca profesional creada por el administrador.
        List<ContentWorkspace> libs = [SELECT Id FROM ContentWorkspace WHERE Name = 'Repositorio Maestro Pyatz' LIMIT 1];
        if (!libs.isEmpty()) return libs[0].Id;
        
        // Si no existe, usa la Biblioteca de activos por defecto de la Org.
        libs = [SELECT Id FROM ContentWorkspace WHERE Name = 'Asset Library' LIMIT 1];
        return !libs.isEmpty() ? libs[0].Id : null;
    }

    private static Id getOppIdFromDocument(Id docId) {
        for (ContentDocumentLink cdl : [SELECT LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :docId]) { 
            if (cdl.LinkedEntityId.getSObjectType().getDescribe().getName() == 'Opportunity') return cdl.LinkedEntityId; 
        }
        return null;
    }

    private static void linkDocumentToEntity(Id docId, Id entityId) {
        if ([SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId = :docId AND LinkedEntityId = :entityId].isEmpty()) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = docId;
            cdl.LinkedEntityId = entityId;
            
            // Si el ID empieza con '058', es una Biblioteca (ContentWorkspace)
            if (String.valueOf(entityId).startsWith('058')) {
                cdl.ShareType = 'I'; // Inferred: Requerido para Bibliotecas
            } else {
                cdl.ShareType = 'V'; // Viewer: Para Cuentas y Oportunidades
                cdl.Visibility = 'AllUsers';
            }
            insert cdl;
        }
    }
}