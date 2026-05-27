@isTest
private class TechCitasServicioControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Citas Account');
        insert acc;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New');
        insert wo;
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id, Status = 'Ninguno',
            SchedStartTime = Datetime.now(), SchedEndTime = Datetime.now().addHours(1),
            DurationInMinutes = 60
        );
        insert sa;
    }

    @isTest
    static void testGetCitasServicio_empty() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        delete [SELECT Id FROM ServiceAppointment WHERE ParentRecordId = :wo.Id];
        Test.startTest();
        List<TechCitasServicioController.CitaWrapper> result = TechCitasServicioController.getCitasServicio(wo.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetCitasServicio_withData() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        Test.startTest();
        List<TechCitasServicioController.CitaWrapper> result = TechCitasServicioController.getCitasServicio(wo.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
        System.assertEquals(0, result[0].totalRevisiones);
    }

    @isTest
    static void testGetCitasServicio_withRevisions() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c = sa.Id,
            Numero_Revision__c = 1,
            Status__c = 'Completada',
            Tipo_Reporte__c = 'Bioenzimático',
            Fecha_Revision__c = Datetime.now(),
            Tecnico__c = UserInfo.getUserId(),
            Datos_Formulario__c = '{"respuestas":[{"label":"Q1","respuesta":"Sí","deficiencia":"problema"}]}'
        );
        insert rev;
        Test.startTest();
        List<TechCitasServicioController.CitaWrapper> result = TechCitasServicioController.getCitasServicio(wo.Id);
        Test.stopTest();
        System.assertEquals(1, result[0].totalRevisiones);
        System.assertEquals(1, result[0].revisionesCompletadas);
        System.assertEquals(1, result[0].revisiones[0].totalNoConformidades);
    }

    @isTest
    static void testGetCitasServicio_withPhotos() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c = sa.Id, Numero_Revision__c = 1, Status__c = 'En Proceso',
            Fecha_Revision__c = Datetime.now(), Tecnico__c = UserInfo.getUserId()
        );
        insert rev;
        ContentVersion cv = new ContentVersion(
            Title = 'GeoFoto_photo.jpg', PathOnClient = 'GeoFoto_photo.jpg',
            VersionData = Blob.valueOf('img'), IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId, LinkedEntityId = rev.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        Test.startTest();
        List<TechCitasServicioController.CitaWrapper> result = TechCitasServicioController.getCitasServicio(wo.Id);
        Test.stopTest();
        System.assertEquals(1, result[0].revisiones[0].totalFotos);
    }
}
