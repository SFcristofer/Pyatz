Id quoteId = '0Q0V9000000SFSrKAO'; // Usaré un ID de presupuesto que el usuario esté probando si puedo encontrarlo, o uno reciente.
// Si no tengo un ID, buscaré el último presupuesto modificado.
Quote q = [SELECT Id, Name, Markers_Data__c FROM Quote ORDER BY LastModifiedDate DESC LIMIT 1];
System.debug('Analizando Cotización: ' + q.Name + ' (' + q.Id + ')');

List<Zona_Servicio_Pyatz__c> zonas = [SELECT Id, Name, Id_Unico_Zona__c, Tipo_de_Servicio__c, Linea_de_Cotizacion__c FROM Zona_Servicio_Pyatz__c WHERE Cotizacion__c = :q.Id];
System.debug('Total de Zonas encontradas: ' + zonas.size());
for(Zona_Servicio_Pyatz__c z : zonas) {
    System.debug('Zona: ' + z.Name + ' | ID Único: ' + z.Id_Unico_Zona__c + ' | Servicios: ' + z.Tipo_de_Servicio__c);
}
