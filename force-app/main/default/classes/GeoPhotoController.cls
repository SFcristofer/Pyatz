public with sharing class GeoPhotoController {

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getWorkOrderInfo(String recordId) {
        Map<String, String> info = new Map<String, String>();
        try {
            // Técnico en sesión — siempre primero para garantizar que llegue al LWC
            String fullName = UserInfo.getName();
            info.put('techName',     fullName);
            info.put('techInitials', buildInitials(fullName));

            String objectType = Id.valueOf(recordId).getSObjectType().getDescribe().getName();

            if (objectType == 'WorkOrder') {
                WorkOrder wo = [
                    SELECT Account.Name, Street, City, State, Country,
                           WorkOrderNumber, Subject
                    FROM WorkOrder
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                info.put('accountName',     wo.Account?.Name  != null ? wo.Account.Name : '');
                info.put('street',          wo.Street         != null ? wo.Street        : '');
                info.put('city',            wo.City           != null ? wo.City          : '');
                info.put('state',           wo.State          != null ? wo.State         : '');
                info.put('workOrderNumber', wo.WorkOrderNumber);
            } else if (objectType == 'ServiceAppointment') {
                ServiceAppointment sa = [
                    SELECT Street, City, State, AppointmentNumber, ParentRecordId
                    FROM ServiceAppointment
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                info.put('street', sa.Street != null ? sa.Street : '');
                info.put('city',   sa.City   != null ? sa.City   : '');
                info.put('state',  sa.State  != null ? sa.State  : '');
                info.put('workOrderNumber', sa.AppointmentNumber);
                info.put('accountName', '');

                // Buscar Account desde el WorkOrder padre si aplica
                if (sa.ParentRecordId != null) {
                    String parentType = sa.ParentRecordId.getSObjectType().getDescribe().getName();
                    if (parentType == 'WorkOrder') {
                        WorkOrder wo = [
                            SELECT Account.Name, WorkOrderNumber
                            FROM WorkOrder
                            WHERE Id = :sa.ParentRecordId
                            LIMIT 1
                        ];
                        info.put('accountName',     wo.Account?.Name    != null ? wo.Account.Name    : '');
                        info.put('workOrderNumber', wo.WorkOrderNumber  != null ? wo.WorkOrderNumber : sa.AppointmentNumber);
                    }
                }
            }

            // Empresa
            Organization org = [SELECT Name FROM Organization LIMIT 1];
            info.put('companyName', org.Name);


        } catch (Exception e) {
            info.put('error', e.getMessage());
        }
        return info;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getGeoPhotos(String recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ];

        if (links.isEmpty()) return new List<Map<String, Object>>();

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        List<ContentVersion> thumbVersions = [
            SELECT Id, Title, CreatedDate, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title LIKE 'GeoFotoThumb_%'
            AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        List<ContentVersion> allGeoVersions = [
            SELECT Id, Title, CreatedDate, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title LIKE 'GeoFoto_%'
            AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
        List<ContentVersion> mainVersions = new List<ContentVersion>();
        for (ContentVersion v : allGeoVersions) {
            if (!v.Title.startsWith('GeoFotoThumb_')) mainVersions.add(v);
        }

        // Map thumb base64 por timestamp (GeoFotoThumb_YYYYMMDD_HHmmss → key)
        Map<String, String> thumbByTs = new Map<String, String>();
        for (ContentVersion t : thumbVersions) {
            String ts = t.Title.replace('GeoFotoThumb_', '').replace('.jpg', '');
            thumbByTs.put(ts, EncodingUtil.base64Encode(t.VersionData));
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (ContentVersion cv : mainVersions) {
            String ts = cv.Title.replace('GeoFoto_', '').replace('.jpg', '');
            Map<String, Object> item = new Map<String, Object>();
            item.put('id',          cv.Id);
            item.put('title',       cv.Title);
            item.put('createdDate', cv.CreatedDate.format('yyyy-MM-dd HH:mm:ss'));
            item.put('downloadUrl', baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id);
            item.put('thumbBase64', thumbByTs.containsKey(ts) ? thumbByTs.get(ts) : null);
            result.add(item);
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static String getPhotoContent(String contentVersionId) {
        ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        return EncodingUtil.base64Encode(cv.VersionData);
    }

    @AuraEnabled
    public static void deleteGeoPhoto(String contentVersionId) {
        try {
            ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
            delete [SELECT Id FROM ContentDocument WHERE Id = :cv.ContentDocumentId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveGeoPhoto(
        String recordId,
        String base64,
        String base64Thumb,
        String filename,
        Decimal latitude,
        Decimal longitude,
        Integer accuracy
    ) {
        try {
            // 1. Crear el archivo principal
            ContentVersion cv = new ContentVersion(
                Title        = filename,
                PathOnClient = filename,
                VersionData  = EncodingUtil.base64Decode(base64),
                IsMajorVersion = true
            );
            insert cv;

            // 2. Obtener el ContentDocumentId recién generado
            Id contentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ].ContentDocumentId;

            // 3. Adjuntar al registro
            ContentDocumentLink link = new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId    = recordId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
            insert link;

            // 4. Guardar thumbnail para galería móvil
            if (String.isNotBlank(base64Thumb)) {
                String thumbName = filename.replace('GeoFoto_', 'GeoFotoThumb_');
                ContentVersion cvThumb = new ContentVersion(
                    Title        = thumbName,
                    PathOnClient = thumbName,
                    VersionData  = EncodingUtil.base64Decode(base64Thumb),
                    IsMajorVersion = true
                );
                insert cvThumb;
                Id thumbDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvThumb.Id LIMIT 1].ContentDocumentId;
                insert new ContentDocumentLink(
                    ContentDocumentId = thumbDocId,
                    LinkedEntityId    = recordId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                );
            }

            // 4. Actualizar coordenadas en el registro padre (dinámico)
            updateParentRecord(recordId, latitude, longitude, accuracy);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String buildInitials(String fullName) {
        if (String.isBlank(fullName)) return '';
        String initials = '';
        for (String part : fullName.trim().split('\\s+')) {
            if (part.length() > 0) initials += part.substring(0, 1).toUpperCase();
        }
        return initials;
    }

    private static void updateParentRecord(
        String recordId,
        Decimal latitude,
        Decimal longitude,
        Integer accuracy
    ) {
        SObjectType objType = Id.valueOf(recordId).getSObjectType();
        Map<String, SObjectField> fields = objType.getDescribe().fields.getMap();

        // Solo actualiza campos que existan en el objeto
        SObject record = objType.newSObject(recordId);

        if (fields.containsKey('geophoto_latitude__c'))  record.put('GeoPhoto_Latitude__c',  latitude);
        if (fields.containsKey('geophoto_longitude__c')) record.put('GeoPhoto_Longitude__c', longitude);
        if (fields.containsKey('geophoto_accuracy__c'))  record.put('GeoPhoto_Accuracy__c',  accuracy);
        if (fields.containsKey('geophoto_timestamp__c')) record.put('GeoPhoto_Timestamp__c', Datetime.now());

        if (fields.containsKey('geophoto_count__c')) {
            String q = 'SELECT GeoPhoto_Count__c FROM ' + objType.getDescribe().getName() +
                       ' WHERE Id = :recordId LIMIT 1';
            SObject current = Database.query(q);
            Decimal count = (Decimal) current.get('GeoPhoto_Count__c');
            record.put('GeoPhoto_Count__c', (count == null ? 0 : count) + 1);
        }

        update record;
    }
}