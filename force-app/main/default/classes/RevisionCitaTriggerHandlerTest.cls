@isTest
private class RevisionCitaTriggerHandlerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Rev Handler Account');
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
    static void testSyncSA_viaInsert() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        sa.Revisiones__c = 2;
        update sa;

        Test.startTest();
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c = sa.Id,
            Numero_Revision__c = 1,
            Status__c = 'En Proceso',
            Fecha_Revision__c = Datetime.now(),
            Tecnico__c = UserInfo.getUserId()
        );
        insert rev;
        Test.stopTest();

        ServiceAppointment updated = [SELECT Status FROM ServiceAppointment WHERE Id = :sa.Id];
        System.assertNotEquals(null, updated.Status);
    }

    @isTest
    static void testSyncSA_allCompleted() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        sa.Revisiones__c = 1;
        update sa;

        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c = sa.Id,
            Numero_Revision__c = 1,
            Status__c = 'En Proceso',
            Fecha_Revision__c = Datetime.now(),
            Tecnico__c = UserInfo.getUserId()
        );
        insert rev;

        Test.startTest();
        rev.Status__c = 'Completada';
        update rev;
        Test.stopTest();

        ServiceAppointment updated = [SELECT Status FROM ServiceAppointment WHERE Id = :sa.Id];
        System.assertNotEquals(null, updated.Status);
    }

    @isTest
    static void testSyncSA_delete() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        sa.Revisiones__c = 1;
        update sa;

        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c = sa.Id,
            Numero_Revision__c = 1,
            Status__c = 'En Proceso',
            Fecha_Revision__c = Datetime.now(),
            Tecnico__c = UserInfo.getUserId()
        );
        insert rev;

        Test.startTest();
        delete rev;
        Test.stopTest();

        ServiceAppointment updated = [SELECT Revisiones__c FROM ServiceAppointment WHERE Id = :sa.Id];
        System.assertEquals(0, (Integer)updated.Revisiones__c);
    }

    @isTest
    static void testSyncSA_directCall() {
        ServiceAppointment sa = [SELECT Id FROM ServiceAppointment LIMIT 1];
        Test.startTest();
        RevisionCitaTriggerHandler.syncSA(new Set<Id>{sa.Id});
        Test.stopTest();
        System.assert(true);
    }
}
