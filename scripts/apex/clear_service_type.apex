Id accId = '001V900004XHZxEIAX';
List<String> namesToUpdate = new List<String>{
    'ENTRADA CDT (1)',
    'LOCKERS (6)',
    'ENTREGA PARA CAMBIO EN LOCKERS (3)',
    'R.H (3)',
    'CAJA AZUL (3)',
    'PATINETA (3)',
    'ENVIOS (3)',
    'ESCALERAS (5)',
    'SUB ESTACION (5)',
    'TRANSPORTE (2)',
    'PROVEEDORES (5)'
};

List<Zona_Servicio_Pyatz__c> zones = [SELECT Id, Name, Tipo_de_Servicio__c 
                                      FROM Zona_Servicio_Pyatz__c 
                                      WHERE Cuenta__c = :accId 
                                      AND Name IN :namesToUpdate];

for(Zona_Servicio_Pyatz__c z : zones) {
    z.Tipo_de_Servicio__c = null;
}

if(!zones.isEmpty()) {
    update zones;
    System.debug('Se eliminó la información del campo Tipo de Servicio en ' + zones.size() + ' zonas.');
}
