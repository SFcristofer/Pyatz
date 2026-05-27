@isTest
private class ServiceReviewPDFControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'SRPDF Account');
        insert acc;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New');
        insert wo;
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id, Status = 'Ninguno',
            SchedStartTime = Datetime.now(), SchedEndTime = Datetime.now().addHours(1),
            DurationInMinutes = 60, Revisiones__c = 1
        );
        insert sa;
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c = sa.Id,
            Numero_Revision__c = 1,
            Status__c = 'Completada',
            Tipo_Reporte__c = 'Limpieza de Trampa',
            Fecha_Revision__c = Datetime.now(),
            Tecnico__c = UserInfo.getUserId(),
            Datos_Formulario__c = '{"respuestas":[{"label":"Estado","respuesta":"Bien","deficiencia":""}]}'
        );
        insert rev;
    }

    @isTest
    static void testConstructor_noId() {
        PageReference page = Page.ServiceReviewPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        ServiceReviewPDFController ctrl = new ServiceReviewPDFController();
        Test.stopTest();
        System.assertEquals(null, ctrl.saRecord);
    }

    @isTest
    static void testConstructor_withSaId() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        PageReference page = Page.ServiceReviewPDF;
        Test.setCurrentPage(page);
        ApexPages.currentPage().getParameters().put('id', sa.Id);
        Test.startTest();
        ServiceReviewPDFController ctrl = new ServiceReviewPDFController();
        Test.stopTest();
        System.assertNotEquals(null, ctrl.saRecord);
        System.assertEquals(1, ctrl.totalRevs);
    }

    @isTest
    static void testConstructor_withPhotosAndSig() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Revision_Cita_Servicio__c rev = [SELECT Id FROM Revision_Cita_Servicio__c LIMIT 1];
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('img'));
        ContentVersion cvPhoto = new ContentVersion(
            Title = 'GeoFoto_rev.jpg', PathOnClient = 'GeoFoto_rev.jpg',
            VersionData = Blob.valueOf('img'), IsMajorVersion = true
        );
        ContentVersion cvSig = new ContentVersion(
            Title = 'SignClean_rev.png', PathOnClient = 'SignClean_rev.png',
            VersionData = Blob.valueOf('sig'), IsMajorVersion = true,
            Description = 'SignerName'
        );
        insert new List<ContentVersion>{cvPhoto, cvSig};
        Id photoDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'GeoFoto_rev.jpg' LIMIT 1].ContentDocumentId;
        Id sigDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'SignClean_rev.png' LIMIT 1].ContentDocumentId;
        insert new ContentDocumentLink(ContentDocumentId = photoDocId, LinkedEntityId = rev.Id, ShareType = 'V', Visibility = 'AllUsers');
        insert new ContentDocumentLink(ContentDocumentId = sigDocId, LinkedEntityId = rev.Id, ShareType = 'V', Visibility = 'AllUsers');

        PageReference page = Page.ServiceReviewPDF;
        Test.setCurrentPage(page);
        ApexPages.currentPage().getParameters().put('id', sa.Id);
        Test.startTest();
        ServiceReviewPDFController ctrl = new ServiceReviewPDFController();
        Test.stopTest();
        System.assertEquals(1, ctrl.totalFotos);
        System.assertEquals(1, ctrl.totalFirmadas);
    }
}
