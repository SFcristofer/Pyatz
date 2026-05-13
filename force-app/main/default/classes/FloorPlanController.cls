public with sharing class FloorPlanController {

    public class ControlPointWrapper {
        @AuraEnabled public ControlPoint__c point { get; set; }
        @AuraEnabled public List<ControlPointVisit__c> visits { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ControlPointWrapper> getControlPointsWithVisits(String floorPlanId) {
        List<ControlPoint__c> points = [
            SELECT Id, Name, XPercent__c, YPercent__c, PointType__c,
                   Status__c, Notes__c, LastVisitDate__c,
                   (SELECT Id, Name, VisitDate__c, Result__c, Quantity__c,
                           Observations__c, TechnicianUser__r.Name
                    FROM Control_Point_Visits__r
                    ORDER BY VisitDate__c DESC
                    LIMIT 5)
            FROM ControlPoint__c
            WHERE FloorPlan__c = :floorPlanId
            ORDER BY Name ASC
        ];

        List<ControlPointWrapper> result = new List<ControlPointWrapper>();
        for (ControlPoint__c p : points) {
            ControlPointWrapper w = new ControlPointWrapper();
            w.point = p;
            w.visits = p.Control_Point_Visits__r;
            result.add(w);
        }
        return result;
    }


    @AuraEnabled(cacheable=true)
    public static List<ControlPoint__c> getControlPoints(String floorPlanId) {
        return [
            SELECT Id, Name, XPercent__c, YPercent__c, PointType__c,
                   Status__c, Notes__c, LastVisitDate__c
            FROM ControlPoint__c
            WHERE FloorPlan__c = :floorPlanId
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ControlPointVisit__c> getRecentVisits(String controlPointId) {
        return [
            SELECT Id, Name, VisitDate__c, Result__c, Quantity__c,
                   Observations__c, TechnicianUser__r.Name, WorkOrderId__c
            FROM ControlPointVisit__c
            WHERE ControlPoint__c = :controlPointId
            ORDER BY VisitDate__c DESC
            LIMIT 10
        ];
    }

    @AuraEnabled(cacheable=true)
    public static String getFloorPlanImageUrl(String floorPlanId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :floorPlanId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        if (links.isEmpty()) return null;
        return '/sfc/servlet.shepherd/document/download/' + links[0].ContentDocumentId;
    }

    @AuraEnabled
    public static void logVisit(String controlPointId, String result,
                                Decimal quantity, String observations) {
        ControlPointVisit__c visit = new ControlPointVisit__c(
            ControlPoint__c = controlPointId,
            VisitDate__c = DateTime.now(),
            TechnicianUser__c = UserInfo.getUserId(),
            Result__c = result,
            Quantity__c = quantity,
            Observations__c = observations
        );
        insert visit;

        ControlPoint__c point = new ControlPoint__c(Id = controlPointId);
        point.LastVisitDate__c = Date.today();
        if (result == 'Triggered' || result == 'Capture') {
            point.Status__c = 'Triggered';
        }
        update point;
    }

    @AuraEnabled
    public static String uploadFloorPlanImage(String floorPlanId, String base64Data, String fileName) {
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = inserted.ContentDocumentId,
            LinkedEntityId = floorPlanId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        return inserted.ContentDocumentId;
    }

    @AuraEnabled
    public static void deleteControlPoint(String controlPointId) {
        ControlPoint__c point = [SELECT Id FROM ControlPoint__c WHERE Id = :controlPointId LIMIT 1];
        delete point;
    }
}