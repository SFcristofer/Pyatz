@isTest
private class OdtViewerControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'ODT Account');
        insert acc;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        ServiceContract sc = new ServiceContract(
            Name = 'ODT Contract', AccountId = acc.Id, Pricebook2Id = pb.Id
        );
        insert sc;
        WorkOrder wo = new WorkOrder(AccountId = acc.Id, Status = 'New', ServiceContractId = sc.Id);
        insert wo;
    }

    @isTest
    static void testGetContractsForAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Map<String, String>> result = OdtViewerController.getContractsForAccount(acc.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testAssignWorkOrdersToContract() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceContract sc = [SELECT Id FROM ServiceContract LIMIT 1];
        Test.startTest();
        OdtViewerController.assignWorkOrdersToContract(new List<Id>{wo.Id}, sc.Id);
        Test.stopTest();
        WorkOrder updated = [SELECT ServiceContractId FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals(sc.Id, updated.ServiceContractId);
    }

    @isTest
    static void testGetServiceTerritoriesForAccount() {
        Test.startTest();
        List<Map<String, String>> result = OdtViewerController.getServiceTerritoriesForAccount();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testBulkUpdateWorkOrders() {
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceContract sc = [SELECT Id FROM ServiceContract LIMIT 1];
        Test.startTest();
        OdtViewerController.bulkUpdateWorkOrders(
            new List<Id>{wo.Id}, 'New', 'High',
            String.valueOf(Date.today()), sc.Id, null, 'Test desc'
        );
        Test.stopTest();
        WorkOrder updated = [SELECT Status, Priority FROM WorkOrder WHERE Id = :wo.Id];
        System.assertEquals('New', updated.Status);
        System.assertEquals('High', updated.Priority);
    }

    @isTest
    static void testGetOdtsByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = OdtViewerController.getOdtsByAccount(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetOppAndQuoteFromContract_notFound() {
        ServiceContract sc = [SELECT Id FROM ServiceContract LIMIT 1];
        Boolean exThrown = false;
        Test.startTest();
        try {
            OdtViewerController.getOppAndQuoteFromContract(sc.Id);
        } catch (AuraHandledException e) {
            exThrown = true;
        }
        Test.stopTest();
        System.assert(exThrown);
    }
}
