@isTest
private class QuoteSelectorTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Selector Account');
        insert acc;
        Account child = new Account(Name = 'Child Sede', ParentId = acc.Id);
        insert child;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'Selector Opp', AccountId = acc.Id, Pricebook2Id = pb.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Quote q = new Quote(
            Name = 'Selector Quote', OpportunityId = opp.Id,
            Pricebook2Id = pb.Id, Status = 'Draft'
        );
        insert q;
    }

    @isTest
    static void testGetQuoteById() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        Quote result = QuoteSelector.getQuoteById(q.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals('Selector Quote', result.Name);
    }

    @isTest
    static void testGetQuoteById_null() {
        Test.startTest();
        Quote result = QuoteSelector.getQuoteById(null);
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @isTest
    static void testGetOpportunityById() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        Opportunity result = QuoteSelector.getOpportunityById(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals('Selector Opp', result.Name);
    }

    @isTest
    static void testGetOpportunityById_null() {
        Test.startTest();
        Opportunity result = QuoteSelector.getOpportunityById(null);
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @isTest
    static void testGetLineItemsByQuoteId() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<QuoteLineItem> result = QuoteSelector.getLineItemsByQuoteId(q.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetSedesByParentId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Selector Account' LIMIT 1];
        Test.startTest();
        List<Account> result = QuoteSelector.getSedesByParentId(acc.Id, 10);
        Test.stopTest();
        System.assertEquals(1, result.size());
    }

    @isTest
    static void testGetPLAnalysisByQuoteId() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<Analisis_PL__c> result = QuoteSelector.getPLAnalysisByQuoteId(q.Id);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }
}
