@isTest
private class QuoteContractPDFControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Contract PDF Account');
        insert acc;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'Contract PDF Opp', AccountId = acc.Id, Pricebook2Id = pb.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Quote q = new Quote(
            Name = 'Contract PDF Quote', OpportunityId = opp.Id,
            Pricebook2Id = pb.Id, Status = 'Draft'
        );
        insert q;
    }

    @isTest
    static void testConstructor_basic() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        PageReference page = Page.QuoteContractPDF;
        Test.setCurrentPage(page);
        ApexPages.currentPage().getParameters().put('id', q.Id);
        Test.startTest();
        QuoteContractPDFController ctrl = new QuoteContractPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertNotEquals(null, ctrl.quoteRecord);
        System.assertNotEquals(null, ctrl.fechaHoy);
    }

    @isTest
    static void testConstructor_withParams() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        PageReference page = Page.QuoteContractPDF;
        Test.setCurrentPage(page);
        ApexPages.currentPage().getParameters().put('id', q.Id);
        ApexPages.currentPage().getParameters().put('show_total', 'false');
        ApexPages.currentPage().getParameters().put('show_line_prices', 'true');
        ApexPages.currentPage().getParameters().put('clientSigner', 'Juan Test');
        Test.startTest();
        QuoteContractPDFController ctrl = new QuoteContractPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertEquals(false, ctrl.config.get('show_total'));
        System.assertEquals('Juan Test', ctrl.firmanteCliente);
    }

    @isTest
    static void testConstructor_withCreatedByParam() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        PageReference page = Page.QuoteContractPDF;
        Test.setCurrentPage(page);
        ApexPages.currentPage().getParameters().put('id', q.Id);
        ApexPages.currentPage().getParameters().put('createdBy', UserInfo.getUserId());
        Test.startTest();
        QuoteContractPDFController ctrl = new QuoteContractPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertNotEquals(null, ctrl.firmanteNombre);
    }

    @isTest
    static void testConstructor_withSelectedItems() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Product2 prod = new Product2(Name = 'PDF Prod', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id, Product2Id = prod.Id, UnitPrice = 100, IsActive = true
        );
        insert pbe;
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100
        );
        insert qli;

        PageReference page = Page.QuoteContractPDF;
        Test.setCurrentPage(page);
        ApexPages.currentPage().getParameters().put('id', q.Id);
        ApexPages.currentPage().getParameters().put('selectedItems', qli.Id);
        Test.startTest();
        QuoteContractPDFController ctrl = new QuoteContractPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertNotEquals(null, ctrl.selectedLineItems);
        System.assert(ctrl.totalContrato > 0);
    }

    @isTest
    static void testGetQuoteLineItems() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<QuoteLineItem> result = QuoteContractPDFController.getQuoteLineItems(q.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
}
