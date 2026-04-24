// PASO 1: Account, Contact, Opportunity, Productos, PricebookEntries
// Ejecuta este primero. Al terminar copia los IDs del log para el Paso 2.

Account acc = new Account(Name='Empresa Demo S.A. de C.V.', Phone='5512345678', BillingCity='CDMX');
insert acc;

Contact con = new Contact(FirstName='Carlos', LastName='Ramirez Lopez', AccountId=acc.Id, Email='carlos@demo.mx');
insert con;

Opportunity opp = new Opportunity(Name='Proyecto Demo - Automatizacion', AccountId=acc.Id, StageName='Proposal/Price Quote', CloseDate=Date.today().addDays(30), Amount=130000);
insert opp;

Id stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard=true LIMIT 1].Id;

Product2 sep1 = new Product2(Name='-- AUTOMATIZACION Y CONTROL --', IsActive=true, ProductCode='SEP-001');
Product2 p1   = new Product2(Name='PLC Siemens S7-1200', IsActive=true, ProductCode='AUT-001');
Product2 p2   = new Product2(Name='Panel HMI KTP700', IsActive=true, ProductCode='AUT-002');
Product2 sep2 = new Product2(Name='-- INSTALACION Y PUESTA EN MARCHA --', IsActive=true, ProductCode='SEP-002');
Product2 p3   = new Product2(Name='Ingenieria y Programacion PLC', IsActive=true, ProductCode='SRV-001');
Product2 p4   = new Product2(Name='Capacitacion al Personal', IsActive=true, ProductCode='SRV-002');
insert new List<Product2>{sep1,p1,p2,sep2,p3,p4};

PricebookEntry pbSep1 = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=sep1.Id, UnitPrice=0,     IsActive=true);
PricebookEntry pb1    = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p1.Id,   UnitPrice=45000, IsActive=true);
PricebookEntry pb2    = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p2.Id,   UnitPrice=28000, IsActive=true);
PricebookEntry pbSep2 = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=sep2.Id, UnitPrice=0,     IsActive=true);
PricebookEntry pb3    = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p3.Id,   UnitPrice=35000, IsActive=true);
PricebookEntry pb4    = new PricebookEntry(Pricebook2Id=stdPb, Product2Id=p4.Id,   UnitPrice=12000, IsActive=true);
insert new List<PricebookEntry>{pbSep1,pb1,pb2,pbSep2,pb3,pb4};

System.debug('=== PASO 1 COMPLETADO ===');
System.debug('OPP_ID=' + opp.Id);
System.debug('CON_ID=' + con.Id);
System.debug('PB_SEP1=' + pbSep1.Id);
System.debug('PB1='     + pb1.Id);
System.debug('PB2='     + pb2.Id);
System.debug('PB_SEP2=' + pbSep2.Id);
System.debug('PB3='     + pb3.Id);
System.debug('PB4='     + pb4.Id);
System.debug('PRICEBOOK=' + stdPb);
