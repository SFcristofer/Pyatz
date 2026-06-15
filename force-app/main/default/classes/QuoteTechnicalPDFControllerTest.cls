@isTest
private class QuoteTechnicalPDFControllerTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'QTPDF Account');
        insert acc;
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'QTPDF Opp', AccountId = acc.Id, Pricebook2Id = pb.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Quote q = new Quote(
            Name = 'QTPDF Quote', OpportunityId = opp.Id,
            Pricebook2Id = pb.Id, Status = 'Draft',
            Introduction_Text__c = 'Hello [[SEDES]] [[CLIENTE]] [[ATENCION]]',
            Warranty_Text__c = 'Warranty [[FOLIO]]'
        );
        insert q;
    }

    @isTest
    static void testConstructor_basic() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        PageReference page = Page.QuoteTechnicalPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        QuoteTechnicalPDFController ctrl = new QuoteTechnicalPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertNotEquals(null, ctrl.technicalQuote);
    }

    @isTest
    static void testConstructor_withMarkersData() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Map<String, Object> state = new Map<String, Object>{
            'selectedContactNames' => 'Juan Test',
            'pagoTransferencia' => true,
            'pagoTarjeta' => false,
            'trabajoPuntual' => true,
            'trabajoMantenimiento' => false,
            'ventaProducto' => false,
            'observacionesPago' => 'Pay in 30 days',
            'serviciosData' => new List<Object>()
        };
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state)));
        q.Markers_Data__c = b64;
        update q;

        PageReference page = Page.QuoteTechnicalPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        QuoteTechnicalPDFController ctrl = new QuoteTechnicalPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertEquals('Juan Test', ctrl.atencionNames);
        System.assert(ctrl.metodoPago.contains('Transferencia'));
    }

    @isTest
    static void testFormatPlainTextToHtml_singleLine() {
        Test.startTest();
        String result = QuoteTechnicalPDFController.formatPlainTextToHtml('Simple text');
        Test.stopTest();
        System.assert(result.contains('<p'));
    }

    @isTest
    static void testFormatPlainTextToHtml_multiLine() {
        Test.startTest();
        String result = QuoteTechnicalPDFController.formatPlainTextToHtml('Line 1\nLine 2\nLine 3');
        Test.stopTest();
        System.assert(result.contains('<ul') || result.contains('<li'));
    }

    @isTest
    static void testFormatPlainTextToHtml_dashedItems() {
        Test.startTest();
        String result = QuoteTechnicalPDFController.formatPlainTextToHtml('Item A - Item B - Item C - Item D');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testConstructor_withLineItems() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Product2 prod = new Product2(Name = 'QTPDF Prod', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = prod.Id, UnitPrice = 300, IsActive = true);
        insert pbe;
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 300,
            Descripcion_Detallada__c = 'Item 1\nItem 2\nItem 3'
        );
        insert qli;
        PageReference page = Page.QuoteTechnicalPDF;
        Test.setCurrentPage(page);
        Test.startTest();
        QuoteTechnicalPDFController ctrl = new QuoteTechnicalPDFController(
            new ApexPages.StandardController(q)
        );
        Test.stopTest();
        System.assertEquals(1, ctrl.technicalQuote.QuoteLineItems.size());
    }
}
