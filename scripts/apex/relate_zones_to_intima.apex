Id accId = '001V900004XHZxEIAX';
Id templateId = 'a16V9000000xVmCIAU'; // Íntima

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

// Buscamos las zonas por nombre exacto o nombre con prefijo (por si acaso)
List<Zona_Servicio_Pyatz__c> zones = [SELECT Id, Name, Tipo_de_Servicio__c, Plantilla_de_Formulario__c 
                                      FROM Zona_Servicio_Pyatz__c 
                                      WHERE Cuenta__c = :accId 
                                      AND (Name IN :namesToUpdate OR Name LIKE 'CDT %')];

List<Zona_Servicio_Pyatz__c> toUpdate = new List<Zona_Servicio_Pyatz__c>();

for(Zona_Servicio_Pyatz__c z : zones) {
    Boolean matches = false;
    for(String targetName : namesToUpdate) {
        if(z.Name == targetName || z.Name.contains(targetName)) {
            matches = true;
            break;
        }
    }
    
    if(matches) {
        z.Plantilla_de_Formulario__c = templateId;
        z.Tipo_de_Servicio__c = 'GESTIÓN MENSTRUAL (ÍNTIMA)';
        toUpdate.add(z);
    }
}

if(!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Se actualizaron ' + toUpdate.size() + ' zonas con la plantilla Íntima y el tipo GESTIÓN MENSTRUAL (ÍNTIMA)');
} else {
    System.debug('No se encontraron zonas que coincidan con los nombres proporcionados.');
}
