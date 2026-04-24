/**
 * Script: CreateQuoteTechnicalPDFSample.apex
 * Propósito: Crear registros de ejemplo completos para visualizar QuoteTechnicalPDF.page
 * Ejecución: Developer Console > Debug > Open Execute Anonymous Window
 *
 * Al finalizar imprime en el log la URL directa al PDF.
 */

// ─── 1. ACCOUNT (CLIENTE) ────────────────────────────────────────────────────
Account acc = new Account(
    Name            = 'Empresa Demo S.A. de C.V.',
    Phone           = '5512345678',
    BillingCity     = 'Ciudad de México',
    BillingState    = 'CDMX',
    BillingCountry  = 'México'
);
insert acc;

// ─── 2. CONTACT ──────────────────────────────────────────────────────────────
Contact con = new Contact(
    FirstName   = 'Carlos',
    LastName    = 'Ramírez López',
    AccountId   = acc.Id,
    Email       = 'carlos.ramirez@empresademo.mx',
    Phone       = '5598765432',
    Title       = 'Director de Operaciones'
);
insert con;

// ─── 3. OPPORTUNITY ──────────────────────────────────────────────────────────
Opportunity opp = new Opportunity(
    Name            = 'Proyecto Integración de Sistemas - Empresa Demo',
    AccountId       = acc.Id,
    StageName       = 'Proposal/Price Quote',
    CloseDate       = Date.today().addDays(30),
    Amount          = 250000
);
insert opp;

// ─── 4. PRICEBOOK (Estándar) ──────────────────────────────────────────────────
Id stdPricebook = Test.isRunningTest()
    ? Test.getStandardPricebookId()
    : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

// ─── 5. PRODUCTOS ─────────────────────────────────────────────────────────────
// Separador 1
Product2 prodSep1 = new Product2(
    Name        = '▶ AUTOMATIZACIÓN Y CONTROL',
    IsActive    = true,
    ProductCode = 'SEP-001'
);
// Partida 1
Product2 prod1 = new Product2(
    Name        = 'PLC Siemens S7-1200 CPU 1215C',
    IsActive    = true,
    ProductCode = 'AUT-001',
    Description = 'Controlador lógico programable de alta performance'
);
// Partida 2
Product2 prod2 = new Product2(
    Name        = 'Panel de Operador SIMATIC HMI KTP700',
    IsActive    = true,
    ProductCode = 'AUT-002',
    Description = 'Pantalla táctil 7" para supervisión de procesos'
);
// Separador 2
Product2 prodSep2 = new Product2(
    Name        = '▶ INSTALACIÓN Y PUESTA EN MARCHA',
    IsActive    = true,
    ProductCode = 'SEP-002'
);
// Partida 3
Product2 prod3 = new Product2(
    Name        = 'Ingeniería y Programación de PLC',
    IsActive    = true,
    ProductCode = 'SRV-001',
    Description = 'Servicio de programación y parametrización del sistema'
);
// Partida 4
Product2 prod4 = new Product2(
    Name        = 'Capacitación al Personal Operativo',
    IsActive    = true,
    ProductCode = 'SRV-002',
    Description = 'Entrenamiento en sitio para operadores y técnicos'
);

insert new List<Product2>{ prodSep1, prod1, prod2, prodSep2, prod3, prod4 };

// ─── 6. PRICEBOOK ENTRIES ─────────────────────────────────────────────────────
PricebookEntry pbeSep1 = new PricebookEntry(Pricebook2Id = stdPricebook, Product2Id = prodSep1.Id, UnitPrice = 0,    IsActive = true);
PricebookEntry pbe1    = new PricebookEntry(Pricebook2Id = stdPricebook, Product2Id = prod1.Id,    UnitPrice = 45000, IsActive = true);
PricebookEntry pbe2    = new PricebookEntry(Pricebook2Id = stdPricebook, Product2Id = prod2.Id,    UnitPrice = 28000, IsActive = true);
PricebookEntry pbeSep2 = new PricebookEntry(Pricebook2Id = stdPricebook, Product2Id = prodSep2.Id, UnitPrice = 0,    IsActive = true);
PricebookEntry pbe3    = new PricebookEntry(Pricebook2Id = stdPricebook, Product2Id = prod3.Id,    UnitPrice = 35000, IsActive = true);
PricebookEntry pbe4    = new PricebookEntry(Pricebook2Id = stdPricebook, Product2Id = prod4.Id,    UnitPrice = 12000, IsActive = true);

insert new List<PricebookEntry>{ pbeSep1, pbe1, pbe2, pbeSep2, pbe3, pbe4 };

// ─── 7. QUOTE ─────────────────────────────────────────────────────────────────
String introHtml = '<p>Estimado(a) <strong>Carlos Ramírez López</strong>,</p>'
    + '<p>Por medio del presente, ponemos a su consideración nuestra propuesta técnica-económica '
    + 'para el suministro e instalación del sistema de automatización en sus instalaciones. '
    + 'Nuestro equipo de ingeniería ha diseñado una solución integral que cumple con los '
    + 'requerimientos operativos y de seguridad establecidos.</p>'
    + '<p>Quedamos a sus órdenes para cualquier aclaración.</p>';

String warrantyHtml = '<ol>'
    + '<li>La garantía cubre defectos de fabricación y programación por <strong>12 meses</strong> a partir de la puesta en marcha.</li>'
    + '<li>El presente presupuesto tiene vigencia de <strong>30 días naturales</strong>.</li>'
    + '<li>Los precios no incluyen IVA (se agrega al monto total).</li>'
    + '<li>El tiempo de entrega e instalación es de <strong>4 a 6 semanas</strong> a partir de la aprobación.</li>'
    + '<li>Pyatz no se hace responsable por daños derivados de uso inadecuado del equipo.</li>'
    + '</ol>';

String paymentDesc = 'BANCO: BANAMEX | CUENTA: 1234567890 | CLABE: 002180012345678901 | '
    + 'BENEFICIARIO: PYATZ TECNOLOGÍAS S.A. DE C.V. | '
    + 'Condiciones: 50% anticipo, 50% contra entrega.';

Quote qt = new Quote(
    Name                        = 'Propuesta Técnica - Sistema de Automatización Industrial',
    OpportunityId               = opp.Id,
    AccountId                   = acc.Id,
    ContactId                   = con.Id,
    Pricebook2Id                = stdPricebook,
    Status                      = 'Draft',
    ExpirationDate              = Date.today().addDays(30),
    Business_Lines_Selected__c  = 'Automatización · Control Industrial · Capacitación',
    Technical_Sedes__c          = 'Planta Principal - Tlalnepantla, Estado de México',
    Introduction_Text__c        = introHtml,
    Warranty_Text__c            = warrantyHtml,
    Description                 = paymentDesc,
    Show_Introduction__c        = true,
    Show_Warranty__c            = true
);
insert qt;

// ─── 8. QUOTE LINE ITEMS ──────────────────────────────────────────────────────
// Separadores con Quantity = 0 (se renderizan como encabezados de sección en el PDF)
// Partidas con Quantity > 0 (se renderizan con precio y detalle técnico)

String detalle1 = '<p><strong>Especificaciones técnicas:</strong></p><ul>'
    + '<li>CPU: 100 KB de memoria de trabajo</li>'
    + '<li>Entradas digitales integradas: 14 DI 24V DC</li>'
    + '<li>Salidas digitales integradas: 10 DO 24V DC / 0.5A</li>'
    + '<li>Entradas analógicas: 2 AI (0-10V / 0-20mA)</li>'
    + '<li>Comunicación: PROFINET integrado (1 puerto)</li>'
    + '<li>Software de programación: TIA Portal V17</li>'
    + '</ul>';

String detalle2 = '<p><strong>Características:</strong></p><ul>'
    + '<li>Pantalla TFT a color de 7" (800 x 480 px)</li>'
    + '<li>Touch resistivo multitouch</li>'
    + '<li>Interfaz: PROFINET / Ethernet</li>'
    + '<li>Temperatura de operación: 0°C a 50°C</li>'
    + '<li>Protección: IP65 (frente panel)</li>'
    + '</ul>';

String detalle3 = '<p>Incluye las siguientes actividades:</p><ul>'
    + '<li>Análisis y documentación de requerimientos funcionales</li>'
    + '<li>Desarrollo del programa en lenguaje Ladder (LAD) y SCL</li>'
    + '<li>Configuración de comunicaciones PROFINET entre PLC y HMI</li>'
    + '<li>Pruebas FAT (Factory Acceptance Test) en nuestras instalaciones</li>'
    + '<li>Pruebas SAT (Site Acceptance Test) en planta del cliente</li>'
    + '<li>Documentación técnica del sistema (manual de operación y mantenimiento)</li>'
    + '</ul>';

String detalle4 = '<p>Programa de capacitación (16 horas):</p><ul>'
    + '<li>Módulo 1 (4h): Operación básica del HMI y navegación de pantallas</li>'
    + '<li>Módulo 2 (4h): Interpretación de alarmas y acciones correctivas</li>'
    + '<li>Módulo 3 (4h): Mantenimiento preventivo del sistema</li>'
    + '<li>Módulo 4 (4h): Introducción a TIA Portal para modificaciones menores</li>'
    + '</ul>';

List<QuoteLineItem> lineItems = new List<QuoteLineItem>{
    // Separador sección 1 (Quantity = 0 → se renderiza como encabezado de sección en el PDF)
    new QuoteLineItem(
        QuoteId             = qt.Id,
        Product2Id          = prodSep1.Id,
        PricebookEntryId    = pbeSep1.Id,
        Quantity            = 0,
        UnitPrice           = 0
    ),
    // Partida 1
    new QuoteLineItem(
        QuoteId             = qt.Id,
        Product2Id          = prod1.Id,
        PricebookEntryId    = pbe1.Id,
        Quantity            = 2,
        UnitPrice           = 45000,
        Description         = 'PLC Siemens',
        Descripcion_Detallada__c = detalle1
    ),
    // Partida 2
    new QuoteLineItem(
        QuoteId             = qt.Id,
        Product2Id          = prod2.Id,
        PricebookEntryId    = pbe2.Id,
        Quantity            = 2,
        UnitPrice           = 28000,
        Description         = 'Panel HMI',
        Descripcion_Detallada__c = detalle2
    ),
    // Separador sección 2
    new QuoteLineItem(
        QuoteId             = qt.Id,
        Product2Id          = prodSep2.Id,
        PricebookEntryId    = pbeSep2.Id,
        Quantity            = 0,
        UnitPrice           = 0
    ),
    // Partida 3
    new QuoteLineItem(
        QuoteId             = qt.Id,
        Product2Id          = prod3.Id,
        PricebookEntryId    = pbe3.Id,
        Quantity            = 1,
        UnitPrice           = 35000,
        Description         = 'Ingeniería',
        Descripcion_Detallada__c = detalle3
    ),
    // Partida 4
    new QuoteLineItem(
        QuoteId             = qt.Id,
        Product2Id          = prod4.Id,
        PricebookEntryId    = pbe4.Id,
        Quantity            = 1,
        UnitPrice           = 12000,
        Description         = 'Capacitación',
        Descripcion_Detallada__c = detalle4
    )
};
insert lineItems;

// ─── 9. RESULTADO ─────────────────────────────────────────────────────────────
System.debug('=== REGISTROS CREADOS CON ÉXITO ===');
System.debug('Account ID  : ' + acc.Id + ' | ' + acc.Name);
System.debug('Contact ID  : ' + con.Id + ' | ' + con.LastName);
System.debug('Opportunity : ' + opp.Id + ' | ' + opp.Name);
System.debug('Quote ID    : ' + qt.Id);
System.debug('');
System.debug('>>> URL DIRECTA AL PDF <<<');
System.debug('/apex/QuoteTechnicalPDF?id=' + qt.Id);
System.debug('');
System.debug('>>> URL AL REGISTRO QUOTE <<<');
System.debug('/' + qt.Id);
