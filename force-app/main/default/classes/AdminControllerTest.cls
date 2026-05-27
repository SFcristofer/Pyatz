@isTest
private class AdminControllerTest {

    @isTest
    static void testGetAvailableFields() {
        Test.startTest();
        List<Map<String, String>> fields = AdminController.getAvailableFields();
        Test.stopTest();
        System.assertNotEquals(null, fields);
    }

    @isTest
    static void testGetTableConfigs_empty() {
        Test.startTest();
        List<Map<String, Object>> configs = AdminController.getTableConfigs();
        Test.stopTest();
        System.assertNotEquals(null, configs);
    }

    @isTest
    static void testSaveTableConfig_insert() {
        Test.startTest();
        AdminController.saveTableConfig('TestConfig', 'Name,Status__c', 'Nombre,Estado');
        Test.stopTest();
        List<Configuracion_Tabla_Pyatz__c> results = [SELECT Id, Name FROM Configuracion_Tabla_Pyatz__c WHERE Name = 'TestConfig'];
        System.assertEquals(1, results.size());
    }

    @isTest
    static void testSaveTableConfig_update() {
        Configuracion_Tabla_Pyatz__c existing = new Configuracion_Tabla_Pyatz__c(
            Name = 'ExistingConfig', Activa__c = true
        );
        insert existing;

        Test.startTest();
        AdminController.saveTableConfig('ExistingConfig', 'Name', 'Nombre');
        Test.stopTest();
        Configuracion_Tabla_Pyatz__c updated = [SELECT Campos_API__c FROM Configuracion_Tabla_Pyatz__c WHERE Name = 'ExistingConfig'];
        System.assertEquals('Name', updated.Campos_API__c);
    }

    @isTest
    static void testToggleTableStatus() {
        Configuracion_Tabla_Pyatz__c config = new Configuracion_Tabla_Pyatz__c(
            Name = 'ToggleConfig', Activa__c = true
        );
        insert config;

        Test.startTest();
        AdminController.toggleTableStatus('ToggleConfig', false);
        Test.stopTest();
        Configuracion_Tabla_Pyatz__c updated = [SELECT Activa__c FROM Configuracion_Tabla_Pyatz__c WHERE Name = 'ToggleConfig'];
        System.assertEquals(false, updated.Activa__c);
    }

    @isTest
    static void testGetTableConfigs_withData() {
        insert new Configuracion_Tabla_Pyatz__c(
            Name = 'DataConfig', Campos_API__c = 'Name,Status__c',
            Etiquetas_Columnas__c = 'Nombre,Estado', Activa__c = true
        );
        Test.startTest();
        List<Map<String, Object>> configs = AdminController.getTableConfigs();
        Test.stopTest();
        System.assert(configs.size() >= 1);
    }
}
