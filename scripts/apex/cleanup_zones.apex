// Limpieza de zonas sin ID único (Causantes de duplicidad)
List<Zona_Servicio_Pyatz__c> huerfanos = [SELECT Id FROM Zona_Servicio_Pyatz__c WHERE Id_Unico_Zona__c = null];
if(!huerfanos.isEmpty()) {
    System.debug('Eliminando ' + huerfanos.size() + ' zonas huérfanas que causaban duplicidad.');
    delete huerfanos;
} else {
    System.debug('No se encontraron zonas huérfanas.');
}
