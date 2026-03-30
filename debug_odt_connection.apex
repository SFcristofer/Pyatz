// SCRIPT DE DEPURACIÓN: Verificando datos técnicos del presupuesto
// Reemplaza el ID por uno real si lo tienes, o buscará el último modificado
Quote q = [SELECT Id, Name, QuoteNumber, Show_Introduction__c, Introduction_Text__c FROM Quote ORDER BY LastModifiedDate DESC LIMIT 1];

System.debug('--- DEPURACIÓN PRESUPUESTO ---');
System.debug('ID: ' + q.Id);
System.debug('Folio: ' + q.QuoteNumber);
System.debug('Asunto: ' + q.Name);
System.debug('¿Mostrar Introducción?: ' + q.Show_Introduction__c);
System.debug('Texto de Introducción (Primeros 100 caracteres): ' + (q.Introduction_Text__c != null ? q.Introduction_Text__c.left(100) : 'ESTÁ VACÍO'));
System.debug('-------------------------------');