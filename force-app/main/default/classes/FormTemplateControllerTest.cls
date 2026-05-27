@isTest
private class FormTemplateControllerTest {

    @TestSetup
    static void makeData() {
        Form_Template__c ft = new Form_Template__c(
            Name = 'Test Template',
            Tipo_Reporte__c = 'Test Template',
            Icono__c = 'utility:form',
            Preguntas__c = '[{"id":"q1","label":"Test","type":"radio","options":["Sí","No"]}]',
            Activo__c = true,
            Orden__c = 1
        );
        insert ft;
    }

    @isTest
    static void testGetFormTemplates() {
        Test.startTest();
        List<FormTemplateController.TemplateMetadata> result = FormTemplateController.getFormTemplates();
        Test.stopTest();
        System.assertEquals(1, result.size());
        System.assertEquals('Test Template', result[0].tipo);
        System.assertEquals(1, result[0].questionCount);
    }

    @isTest
    static void testGetFormTemplate_byType() {
        Test.startTest();
        String json = FormTemplateController.getFormTemplate('Test Template');
        Test.stopTest();
        System.assertNotEquals('[]', json);
    }

    @isTest
    static void testGetFormTemplate_byId() {
        Form_Template__c ft = [SELECT Id FROM Form_Template__c LIMIT 1];
        Test.startTest();
        String json = FormTemplateController.getFormTemplate(ft.Id);
        Test.stopTest();
        System.assertNotEquals('[]', json);
    }

    @isTest
    static void testGetFormTemplate_blank() {
        Test.startTest();
        String json = FormTemplateController.getFormTemplate('');
        Test.stopTest();
        System.assertEquals('[]', json);
    }

    @isTest
    static void testGetAllTemplatesAdmin() {
        Test.startTest();
        List<FormTemplateController.TemplateDetail> result = FormTemplateController.getAllTemplatesAdmin();
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetTemplateById() {
        Form_Template__c ft = [SELECT Id FROM Form_Template__c LIMIT 1];
        Test.startTest();
        FormTemplateController.TemplateDetail detail = FormTemplateController.getTemplateById(ft.Id);
        Test.stopTest();
        System.assertEquals('Test Template', detail.tipo);
    }

    @isTest
    static void testUpsertTemplate_insert() {
        Test.startTest();
        String newId = FormTemplateController.upsertTemplate(null, 'New Type', '[]', 'utility:bucket', 2, true);
        Test.stopTest();
        System.assertNotEquals(null, newId);
        Form_Template__c created = [SELECT Tipo_Reporte__c FROM Form_Template__c WHERE Id = :newId];
        System.assertEquals('New Type', created.Tipo_Reporte__c);
    }

    @isTest
    static void testUpsertTemplate_update() {
        Form_Template__c ft = [SELECT Id FROM Form_Template__c LIMIT 1];
        Test.startTest();
        FormTemplateController.upsertTemplate(ft.Id, 'Updated Type', '[]', 'utility:form', 1, true);
        Test.stopTest();
        Form_Template__c updated = [SELECT Tipo_Reporte__c FROM Form_Template__c WHERE Id = :ft.Id];
        System.assertEquals('Updated Type', updated.Tipo_Reporte__c);
    }

    @isTest
    static void testDeleteTemplate() {
        Form_Template__c ft = [SELECT Id FROM Form_Template__c LIMIT 1];
        Test.startTest();
        FormTemplateController.deleteTemplate(ft.Id);
        Test.stopTest();
        List<Form_Template__c> remaining = [SELECT Id FROM Form_Template__c WHERE Id = :ft.Id];
        System.assertEquals(0, remaining.size());
    }
}
