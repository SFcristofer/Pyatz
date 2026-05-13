@isTest
private class FloorPlanControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        FloorPlan__c plan = new FloorPlan__c(
            Name = 'Test Floor Plan',
            Account__c = acc.Id,
            Description__c = 'Test Description',
            IsActive__c = true
        );
        insert plan;

        ControlPoint__c cp = new ControlPoint__c(
            FloorPlan__c = plan.Id,
            XPercent__c = 25.00,
            YPercent__c = 50.00,
            PointType__c = 'Trap',
            Status__c = 'Active',
            Notes__c = 'Test notes'
        );
        insert cp;

        ControlPointVisit__c visit = new ControlPointVisit__c(
            ControlPoint__c = cp.Id,
            VisitDate__c = DateTime.now(),
            TechnicianUser__c = UserInfo.getUserId(),
            Result__c = 'No Activity',
            Quantity__c = 0,
            Observations__c = 'Test observation'
        );
        insert visit;
    }

    @isTest
    static void testGetControlPoints() {
        FloorPlan__c plan = [SELECT Id FROM FloorPlan__c LIMIT 1];
        List<ControlPoint__c> points = FloorPlanController.getControlPoints(plan.Id);
        System.assertEquals(1, points.size(), 'Debe retornar 1 punto');
        System.assertEquals('Trap', points[0].PointType__c);
    }

    @isTest
    static void testGetRecentVisits() {
        ControlPoint__c cp = [SELECT Id FROM ControlPoint__c LIMIT 1];
        List<ControlPointVisit__c> visits = FloorPlanController.getRecentVisits(cp.Id);
        System.assertEquals(1, visits.size(), 'Debe retornar 1 visita');
        System.assertEquals('No Activity', visits[0].Result__c);
    }

    @isTest
    static void testGetFloorPlanImageUrl_NoImage() {
        FloorPlan__c plan = [SELECT Id FROM FloorPlan__c LIMIT 1];
        String url = FloorPlanController.getFloorPlanImageUrl(plan.Id);
        System.assertEquals(null, url, 'Sin imagen debe retornar null');
    }

    @isTest
    static void testGetFloorPlanImageUrl_WithImage() {
        FloorPlan__c plan = [SELECT Id FROM FloorPlan__c LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'test.png',
            PathOnClient = 'test.png',
            VersionData = Blob.valueOf('fake image data'),
            IsMajorVersion = true
        );
        insert cv;
        ContentVersion cvInserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = cvInserted.ContentDocumentId,
            LinkedEntityId = plan.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        String url = FloorPlanController.getFloorPlanImageUrl(plan.Id);
        System.assertNotEquals(null, url, 'Con imagen debe retornar URL');
        System.assert(url.contains('/sfc/servlet.shepherd/document/download/'), 'URL debe contener ruta correcta');
    }

    @isTest
    static void testLogVisit_NoActivity() {
        ControlPoint__c cp = [SELECT Id, Status__c FROM ControlPoint__c LIMIT 1];
        FloorPlanController.logVisit(cp.Id, 'No Activity', 0, 'Sin actividad');

        List<ControlPointVisit__c> visits = [SELECT Id, Result__c FROM ControlPointVisit__c WHERE ControlPoint__c = :cp.Id ORDER BY VisitDate__c DESC];
        System.assertEquals(2, visits.size());
        System.assertEquals('No Activity', visits[0].Result__c);

        ControlPoint__c updated = [SELECT Status__c, LastVisitDate__c FROM ControlPoint__c WHERE Id = :cp.Id];
        System.assertEquals('Active', updated.Status__c, 'Estado no debe cambiar con No Activity');
        System.assertEquals(Date.today(), updated.LastVisitDate__c);
    }

    @isTest
    static void testLogVisit_Triggered() {
        ControlPoint__c cp = [SELECT Id FROM ControlPoint__c LIMIT 1];
        FloorPlanController.logVisit(cp.Id, 'Capture', 3, 'Captura de roedor');

        ControlPoint__c updated = [SELECT Status__c FROM ControlPoint__c WHERE Id = :cp.Id];
        System.assertEquals('Triggered', updated.Status__c, 'Estado debe cambiar a Triggered con Capture');
    }

    @isTest
    static void testUploadFloorPlanImage() {
        FloorPlan__c plan = [SELECT Id FROM FloorPlan__c LIMIT 1];
        String fakeBase64 = EncodingUtil.base64Encode(Blob.valueOf('fake image'));
        String docId = FloorPlanController.uploadFloorPlanImage(plan.Id, fakeBase64, 'plano.png');

        System.assertNotEquals(null, docId);
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :plan.Id];
        System.assertEquals(1, links.size(), 'Debe crear 1 ContentDocumentLink');
    }

    @isTest
    static void testDeleteControlPoint() {
        ControlPoint__c cp = [SELECT Id FROM ControlPoint__c LIMIT 1];
        FloorPlanController.deleteControlPoint(cp.Id);
        List<ControlPoint__c> remaining = [SELECT Id FROM ControlPoint__c WHERE Id = :cp.Id];
        System.assertEquals(0, remaining.size(), 'Punto debe eliminarse');
    }

    @isTest
    static void testGetControlPoints_Empty() {
        Account acc2 = new Account(Name = 'Empty Account');
        insert acc2;
        FloorPlan__c emptyPlan = new FloorPlan__c(Name = 'Empty Plan', Account__c = acc2.Id);
        insert emptyPlan;
        List<ControlPoint__c> points = FloorPlanController.getControlPoints(emptyPlan.Id);
        System.assertEquals(0, points.size());
    }

    @isTest
    static void testGetControlPointsWithVisits() {
        FloorPlan__c plan = [SELECT Id FROM FloorPlan__c LIMIT 1];
        List<FloorPlanController.ControlPointWrapper> wrappers =
            FloorPlanController.getControlPointsWithVisits(plan.Id);

        System.assertEquals(1, wrappers.size(), 'Debe retornar 1 wrapper');
        System.assertEquals('Trap', wrappers[0].point.PointType__c);
        System.assertEquals(1, wrappers[0].visits.size(), 'Debe retornar 1 visita embebida');
        System.assertEquals('No Activity', wrappers[0].visits[0].Result__c);
    }

    @isTest
    static void testGetControlPointsWithVisits_Empty() {
        Account acc2 = new Account(Name = 'Empty Account 2');
        insert acc2;
        FloorPlan__c emptyPlan = new FloorPlan__c(Name = 'Empty Plan 2', Account__c = acc2.Id);
        insert emptyPlan;
        List<FloorPlanController.ControlPointWrapper> wrappers =
            FloorPlanController.getControlPointsWithVisits(emptyPlan.Id);
        System.assertEquals(0, wrappers.size());
    }
}