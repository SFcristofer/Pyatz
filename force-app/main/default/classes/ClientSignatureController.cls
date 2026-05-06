public with sharing class ClientSignatureController {

    @AuraEnabled
    public static void saveSignaturePair(
        String recordId,
        String base64Clean,
        String base64Info,
        String base64Thumb,
        String filenameClean,
        String filenameInfo,
        String signerName
    ) {
        try {
            ContentVersion cvClean = new ContentVersion(
                Title          = filenameClean,
                PathOnClient   = filenameClean,
                VersionData    = EncodingUtil.base64Decode(base64Clean),
                IsMajorVersion = true,
                Description    = signerName
            );
            ContentVersion cvInfo = new ContentVersion(
                Title          = filenameInfo,
                PathOnClient   = filenameInfo,
                VersionData    = EncodingUtil.base64Decode(base64Info),
                IsMajorVersion = true,
                Description    = signerName
            );

            List<ContentVersion> toInsert = new List<ContentVersion>{ cvClean, cvInfo };

            // Thumbnail para galería móvil
            ContentVersion cvThumb = null;
            if (String.isNotBlank(base64Thumb)) {
                String thumbName = filenameInfo.replace('Firma_', 'SignThumb_');
                cvThumb = new ContentVersion(
                    Title          = thumbName,
                    PathOnClient   = thumbName,
                    VersionData    = EncodingUtil.base64Decode(base64Thumb),
                    IsMajorVersion = true,
                    Description    = signerName
                );
                toInsert.add(cvThumb);
            }

            insert toInsert;

            Map<Id, Id> cvToDoc = new Map<Id, Id>();
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId FROM ContentVersion
                WHERE Id IN :toInsert
            ]) {
                cvToDoc.put(cv.Id, cv.ContentDocumentId);
            }

            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (Id docId : cvToDoc.values()) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId    = recordId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                ));
            }
            insert links;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getSignatureContent(String contentVersionId) {
        ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        return EncodingUtil.base64Encode(cv.VersionData);
    }

    // Galería: muestra Firma_* con info, e incluye URL de su SignClean_ par
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getSignatures(String recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ];

        if (links.isEmpty()) return new List<Map<String, Object>>();

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        List<ContentVersion> allVersions = [
            SELECT Id, Title, Description, CreatedDate, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND (Title LIKE 'Firma_%' OR Title LIKE 'SignClean_%' OR Title LIKE 'SignThumb_%')
            AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 150
        ];

        Map<String, Id>     cleanIdBySuffix = new Map<String, Id>();
        Map<String, String> thumbBySuffix   = new Map<String, String>();
        List<ContentVersion> infoVersions   = new List<ContentVersion>();

        for (ContentVersion cv : allVersions) {
            if (cv.Title.startsWith('SignClean_')) {
                cleanIdBySuffix.put(cv.Title.removeStart('SignClean_'), cv.Id);
            } else if (cv.Title.startsWith('SignThumb_')) {
                thumbBySuffix.put(cv.Title.removeStart('SignThumb_'), EncodingUtil.base64Encode(cv.VersionData));
            } else if (cv.Title.startsWith('Firma_')) {
                infoVersions.add(cv);
            }
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (ContentVersion cv : infoVersions) {
            String suffix  = cv.Title.removeStart('Firma_');
            Id     cleanId = cleanIdBySuffix.get(suffix);

            Map<String, Object> item = new Map<String, Object>();
            item.put('id',              cv.Id);
            item.put('cleanId',         cleanId != null ? (Object)cleanId : (Object)'');
            item.put('title',           cv.Title);
            item.put('signerName',      cv.Description != null ? cv.Description : '');
            item.put('createdDate',     cv.CreatedDate.format('yyyy-MM-dd HH:mm:ss'));
            item.put('downloadUrl',     baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id);
            item.put('cleanDownloadUrl', cleanId != null
                ? baseUrl + '/sfc/servlet.shepherd/version/download/' + cleanId : '');
            item.put('thumbBase64',     thumbBySuffix.get(suffix));
            result.add(item);
        }
        return result;
    }

    // Elimina el par completo (Firma_* + su SignClean_*)
    @AuraEnabled
    public static void deleteSignature(String contentVersionId, String cleanVersionId) {
        try {
            Set<Id> cvIds = new Set<Id>{ (Id)contentVersionId };
            if (String.isNotBlank(cleanVersionId)) cvIds.add((Id)cleanVersionId);

            Set<Id> docIds = new Set<Id>();
            for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds]) {
                docIds.add(cv.ContentDocumentId);
            }
            delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}