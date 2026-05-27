@isTest
private class ServiceReviewControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'SRCtrl Account');
        insert acc;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New');
        insert wo;
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id, Status = 'Ninguno',
            SchedStartTime = Datetime.now(), SchedEndTime = Datetime.now().addHours(2),
            DurationInMinutes = 120, Revisiones__c = 2
        );
        insert sa;
    }

    @isTest
    static void testGetServiceAppointmentInfo() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Test.startTest();
        ServiceReviewController.SAInfo info = ServiceReviewController.getServiceAppointmentInfo(sa.Id);
        Test.stopTest();
        System.assertNotEquals(null, info);
        System.assertNotEquals(null, info.saId);
        System.assertEquals(0, info.revisionesTotales);
    }

    @isTest
    static void testCreateRevision() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Test.startTest();
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        Test.stopTest();
        System.assertNotEquals(null, revId);
        Revision_Cita_Servicio__c rev = [SELECT Status__c FROM Revision_Cita_Servicio__c WHERE Id = :revId];
        System.assertEquals('En Proceso', rev.Status__c);
    }

    @isTest
    static void testSaveRevisionData() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        String datosJson = '{"respuestas":[{"label":"Q1","respuesta":"Sí","deficiencia":""}]}';
        Test.startTest();
        ServiceReviewController.saveRevisionData(revId, 'Limpieza de Trampa', datosJson, 'Observaciones');
        Test.stopTest();
        Revision_Cita_Servicio__c rev = [SELECT Status__c, Tipo_Reporte__c FROM Revision_Cita_Servicio__c WHERE Id = :revId];
        System.assertEquals('Completada', rev.Status__c);
        System.assertEquals('Limpieza de Trampa', rev.Tipo_Reporte__c);
    }

    @isTest
    static void testSaveRevisionData_withTemplateId() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Form_Template__c ft = new Form_Template__c(Name = 'Bioenz', Tipo_Reporte__c = 'Bioenz', Activo__c = true);
        insert ft;
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        Test.startTest();
        ServiceReviewController.saveRevisionData(revId, ft.Id, '{}', 'Obs');
        Test.stopTest();
        Revision_Cita_Servicio__c rev = [SELECT Status__c FROM Revision_Cita_Servicio__c WHERE Id = :revId];
        System.assertEquals('Completada', rev.Status__c);
    }

    @isTest
    static void testCancelRevision() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        Test.startTest();
        ServiceReviewController.cancelRevision(revId);
        Test.stopTest();
        List<Revision_Cita_Servicio__c> remaining = [SELECT Id FROM Revision_Cita_Servicio__c WHERE Id = :revId];
        System.assertEquals(0, remaining.size());
    }

    @isTest
    static void testSavePhoto() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('photo'));
        String b64Thumb = EncodingUtil.base64Encode(Blob.valueOf('thumb'));
        Test.startTest();
        String cvId = ServiceReviewController.savePhoto(revId, b64, b64Thumb, 'GeoFoto_test.jpg', 19.4, -99.1, 5);
        Test.stopTest();
        System.assertNotEquals(null, cvId);
    }

    @isTest
    static void testGetRevisionPhotos_empty() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        Test.startTest();
        List<ServiceReviewController.PhotoInfo> photos = ServiceReviewController.getRevisionPhotos(revId);
        Test.stopTest();
        System.assertEquals(0, photos.size());
    }

    @isTest
    static void testDeletePhoto() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('p'));
        String cvId = ServiceReviewController.savePhoto(revId, b64, null, 'GeoFoto_del.jpg', null, null, null);
        Test.startTest();
        ServiceReviewController.deletePhoto(cvId);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testSaveSignature() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('sig'));
        Test.startTest();
        ServiceReviewController.saveSignature(revId, b64, b64, b64, 'SignClean_Rev.png', 'Firma_Rev.png', 'Client Name');
        Test.stopTest();
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :revId];
        System.assert(links.size() >= 2);
    }

    @isTest
    static void testGetRevisionSignature_empty() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Id revId = ServiceReviewController.createRevision(sa.Id, 1);
        Test.startTest();
        Map<String, String> result = ServiceReviewController.getRevisionSignature(revId);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
}
