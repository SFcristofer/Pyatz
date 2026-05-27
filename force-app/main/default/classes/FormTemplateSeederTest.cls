@isTest
private class FormTemplateSeederTest {

    @isTest
    static void testSeed() {
        Test.startTest();
        FormTemplateSeeder.seed();
        Test.stopTest();
        List<Form_Template__c> templates = [SELECT Id FROM Form_Template__c];
        System.assert(templates.size() > 0, 'Should have seeded templates');
    }

    @isTest
    static void testSeedIdempotent() {
        FormTemplateSeeder.seed();
        Integer firstCount = [SELECT COUNT() FROM Form_Template__c];
        Test.startTest();
        FormTemplateSeeder.seed();
        Test.stopTest();
        Integer secondCount = [SELECT COUNT() FROM Form_Template__c];
        System.assertEquals(firstCount, secondCount, 'Idempotent upsert should not duplicate');
    }
}
