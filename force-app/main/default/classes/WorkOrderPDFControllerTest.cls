@isTest
private class WorkOrderPDFControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'WOPDF Account');
        insert acc;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New');
        insert wo;
    }

    @isTest
    static void testConstructor_noSAs() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        PageReference page = Page.WorkOrderPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        WorkOrderPDFController ctrl = new WorkOrderPDFController(
            new ApexPages.StandardController(wo)
        );
        Test.stopTest();
        System.assertNotEquals(null, ctrl.workOrderRecord);
        System.assertEquals(0, ctrl.totalCitas);
        System.assertEquals(0, ctrl.totalFotos);
        System.assertEquals(0, ctrl.citasCompletadas);
        System.assertEquals(0, ctrl.citasConIncidencia);
    }

    @isTest
    static void testConstructor_withSAs() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceAppointment sa1 = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'Ninguno',
            SchedStartTime = Datetime.now(),
            SchedEndTime = Datetime.now().addHours(1),
            DurationInMinutes = 60,
            Subject = 'Servicio: Fumigacion'
        );
        ServiceAppointment sa2 = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'Ninguno',
            SchedStartTime = Datetime.now(),
            SchedEndTime = Datetime.now().addHours(2),
            DurationInMinutes = 120,
            Subject = 'Servicio: Fumigacion'
        );
        insert new List<ServiceAppointment>{ sa1, sa2 };

        PageReference page = Page.WorkOrderPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        WorkOrderPDFController ctrl = new WorkOrderPDFController(
            new ApexPages.StandardController(wo)
        );
        Test.stopTest();
        System.assertEquals(2, ctrl.totalCitas);
        System.assertEquals(0, ctrl.totalFotos);
    }

    @isTest
    static void testConstructor_withPhotosAndSignatures() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'Ninguno',
            SchedStartTime = Datetime.now(),
            SchedEndTime = Datetime.now().addHours(1),
            DurationInMinutes = 60,
            Description = 'Has observation'
        );
        insert sa;

        ContentVersion cvPhoto = new ContentVersion(
            Title = 'GeoFoto_testphoto.jpg', PathOnClient = 'GeoFoto_testphoto.jpg',
            VersionData = Blob.valueOf('photo'), IsMajorVersion = true
        );
        ContentVersion cvSig = new ContentVersion(
            Title = 'SignClean_client.png', PathOnClient = 'SignClean_client.png',
            VersionData = Blob.valueOf('sig'), IsMajorVersion = true,
            Description = 'Client Name'
        );
        insert new List<ContentVersion>{ cvPhoto, cvSig };

        Id photoDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'GeoFoto_testphoto.jpg' LIMIT 1].ContentDocumentId;
        Id sigDocId   = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'SignClean_client.png'  LIMIT 1].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = photoDocId, LinkedEntityId = sa.Id, ShareType = 'V', Visibility = 'AllUsers');
        insert new ContentDocumentLink(ContentDocumentId = sigDocId,   LinkedEntityId = sa.Id, ShareType = 'V', Visibility = 'AllUsers');

        ContentVersion cvWoSig = new ContentVersion(
            Title = 'SignClean_tech.png', PathOnClient = 'SignClean_tech.png',
            VersionData = Blob.valueOf('techsig'), IsMajorVersion = true,
            Description = 'Tech Name'
        );
        insert cvWoSig;
        Id woSigDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'SignClean_tech.png' LIMIT 1].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = woSigDocId, LinkedEntityId = wo.Id, ShareType = 'V', Visibility = 'AllUsers');

        PageReference page = Page.WorkOrderPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        WorkOrderPDFController ctrl = new WorkOrderPDFController(
            new ApexPages.StandardController(wo)
        );
        Test.stopTest();
        System.assertEquals(1, ctrl.totalFotos);
        System.assertNotEquals(null, ctrl.clientSigUrl);
        System.assertEquals('Client Name', ctrl.clientSigName);
        System.assertNotEquals(null, ctrl.techSigUrl);
    }

    @isTest
    static void testSAWrapper_completedAndIncident() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceAppointment saCompleted = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'Ninguno',
            SchedStartTime = Datetime.now(),
            SchedEndTime = Datetime.now().addHours(1),
            DurationInMinutes = 60,
            Subject = 'Punto A'
        );
        ServiceAppointment saIncident = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'Ninguno',
            SchedStartTime = Datetime.now(),
            SchedEndTime = Datetime.now().addHours(1),
            DurationInMinutes = 60,
            Subject = 'Punto B'
        );
        insert new List<ServiceAppointment>{ saCompleted, saIncident };

        PageReference page = Page.WorkOrderPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        WorkOrderPDFController ctrl = new WorkOrderPDFController(
            new ApexPages.StandardController(wo)
        );
        Test.stopTest();
        System.assertEquals(2, ctrl.totalCitas);
        System.assertEquals(2, ctrl.totalPuntos);
    }
}
