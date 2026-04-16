// 1. Obtener la cotización
Quote q = [SELECT Id, Name, Account.Name, Opportunity.Name, GrandTotal FROM Quote WHERE QuoteNumber = '00000104' LIMIT 1];

System.debug('--- ANÁLISIS TÉCNICO PRESUPUESTO 00000104 ---');
System.debug('NOMBRE: ' + q.Name);
System.debug('CLIENTE: ' + q.Account.Name);
System.debug('OPORTUNIDAD: ' + q.Opportunity.Name);
System.debug('TOTAL: $' + q.GrandTotal);

// 2. Buscar registros de Levantamiento relacionados
List<Levantamiento_Tecnico__c> levs = [SELECT Id, Tipo_Servicio__c, Area_Cocina_Banos__c, Zona_Genero__c FROM Levantamiento_Tecnico__c WHERE Presupuesto__c = :q.Id];
System.debug('--- LEVANTAMIENTOS VINCULADOS ---');
for(Levantamiento_Tecnico__c l : levs) {
    System.debug('- Levantamiento: ' + l.Tipo_Servicio__c + ' | Area: ' + l.Area_Cocina_Banos__c + ' | Zona: ' + l.Zona_Genero__c);
}

// 3. Buscar registros de Zonas de Servicio (Nuevo Objeto)
List<Zona_Servicio_Pyatz__c> zonas = [SELECT Name, Tipo_de_Servicio__c, Detalle_Tecnico__c FROM Zona_Servicio_Pyatz__c WHERE Cotizacion__c = :q.Id];
System.debug('--- REGISTROS DE ZONAS GENERADOS ---');
System.debug('Total de registros de zona encontrados: ' + zonas.size());
for(Zona_Servicio_Pyatz__c z : zonas) {
    System.debug('- Zona Real: ' + z.Name + ' | Servicio: ' + z.Tipo_de_Servicio__c);
}
System.debug('------------------------------------------');
