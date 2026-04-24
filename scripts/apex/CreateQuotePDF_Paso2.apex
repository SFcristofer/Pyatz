// PASO 2: Quote + QuoteLineItems
// REEMPLAZA los IDs de abajo con los del log del Paso 1

Id oppId = 'PEGA_OPP_ID_AQUI';
Id conId = 'PEGA_CON_ID_AQUI';
Id stdPb = 'PEGA_PRICEBOOK_ID_AQUI';
Id pb1   = 'PEGA_PB1_AQUI';
Id pb2   = 'PEGA_PB2_AQUI';
Id pb3   = 'PEGA_PB3_AQUI';
Id pb4   = 'PEGA_PB4_AQUI';

// Campos personalizados: descomenta los que ya estén desplegados en tu org
Quote qt = new Quote(
    Name='Propuesta Tecnica - Automatizacion Industrial',
    OpportunityId=oppId,
    ContactId=conId,
    Pricebook2Id=stdPb,
    Status='Draft',
    ExpirationDate=Date.today().addDays(30),
    Description='BANCO: BANAMEX | CUENTA: 1234567890 | CLABE: 002180012345678901 | Condiciones: 50% anticipo, 50% contra entrega.'
    // Business_Lines_Selected__c='Automatizacion · Control Industrial · Capacitacion',
    // Technical_Sedes__c='Planta Principal - Tlalnepantla, Estado de Mexico',
    // Introduction_Text__c='<p>Estimado <strong>Carlos Ramirez</strong>, ponemos a su consideracion nuestra propuesta tecnica.</p>',
    // Warranty_Text__c='<ol><li>Garantia 12 meses.</li><li>Vigencia 30 dias.</li><li>Precios sin IVA.</li></ol>',
    // Show_Introduction__c=true,
    // Show_Warranty__c=true
);
insert qt;

Product2 p1 = [SELECT Id FROM Product2 WHERE ProductCode='AUT-001' LIMIT 1];
Product2 p2 = [SELECT Id FROM Product2 WHERE ProductCode='AUT-002' LIMIT 1];
Product2 p3 = [SELECT Id FROM Product2 WHERE ProductCode='SRV-001' LIMIT 1];
Product2 p4 = [SELECT Id FROM Product2 WHERE ProductCode='SRV-002' LIMIT 1];

insert new List<QuoteLineItem>{
    new QuoteLineItem(QuoteId=qt.Id, Product2Id=p1.Id, PricebookEntryId=pb1, Quantity=2, UnitPrice=45000,
        Descripcion_Detallada__c='<ul><li>CPU 100KB de memoria de trabajo</li><li>14 DI / 10 DO 24V DC</li><li>2 Entradas analogicas</li><li>PROFINET integrado</li><li>Programacion TIA Portal V17</li></ul>'),
    new QuoteLineItem(QuoteId=qt.Id, Product2Id=p2.Id, PricebookEntryId=pb2, Quantity=2, UnitPrice=28000,
        Descripcion_Detallada__c='<ul><li>Pantalla TFT 7" (800x480 px)</li><li>Touch resistivo multitouch</li><li>Interfaz PROFINET/Ethernet</li><li>Proteccion IP65 frente de panel</li></ul>'),
    new QuoteLineItem(QuoteId=qt.Id, Product2Id=p3.Id, PricebookEntryId=pb3, Quantity=1, UnitPrice=35000,
        Descripcion_Detallada__c='<ul><li>Analisis de requerimientos funcionales</li><li>Desarrollo en Ladder (LAD) y SCL</li><li>Configuracion PROFINET PLC-HMI</li><li>Pruebas FAT y SAT</li><li>Manual de operacion y mantenimiento</li></ul>'),
    new QuoteLineItem(QuoteId=qt.Id, Product2Id=p4.Id, PricebookEntryId=pb4, Quantity=1, UnitPrice=12000,
        Descripcion_Detallada__c='<ul><li>Modulo 1 (4h): Operacion basica del HMI</li><li>Modulo 2 (4h): Interpretacion de alarmas</li><li>Modulo 3 (4h): Mantenimiento preventivo</li><li>Modulo 4 (4h): Introduccion a TIA Portal</li></ul>')
};

System.debug('=== PASO 2 COMPLETADO ===');
System.debug('QUOTE_ID=' + qt.Id);
System.debug('URL PDF: /apex/QuoteTechnicalPDF?id=' + qt.Id);
