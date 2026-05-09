Id accId = '001V900004XHZxEIAX';
List<String> namesToUpdate = new List<String>{
    '10. ENTRADA CDT (1)',
    '16. LOCKERS (6)',
    '17. ENTREGA PARA CAMBIO EN LOCKERS (3)',
    '2. R.H (3)',
    '3. CAJA AZUL (3)',
    '4. PATINETA (3)',
    '5. ENVIOS (3)',
    '6. ESCALERAS (5)',
    '7. SUB ESTACION (5)',
    '8. TRANSPORTE (2)',
    '9. PROVEEDORES (5)'
};

List<Zona_Servicio_Pyatz__c> zones = [SELECT Id, Name, Tipo_de_Servicio__c 
                                      FROM Zona_Servicio_Pyatz__c 
                                      WHERE Cuenta__c = :accId 
                                      AND Name IN :namesToUpdate];

for(Zona_Servicio_Pyatz__c z : zones) {
    // Relacionamos con GESTIÓN MENSTRUAL (ÍNTIMA)
    z.Tipo_de_Servicio__c = 'GESTIÓN MENSTRUAL (ÍNTIMA)';
}

update zones;
System.debug('Se actualizaron ' + zones.size() + ' zonas con el tipo GESTIÓN MENSTRUAL (ÍNTIMA)');
