List<Zona_Servicio_Pyatz__c> zonesToInsert = new List<Zona_Servicio_Pyatz__c>();
Id accId = '001V900004XHZxEIAX';

String[] names = new String[]{
    'NIVEL 8 (7)',
    'Subestacion Caballeros PB (5)',
    'Salas (Mixto) 2 PB (1)',
    'Cajas Azules Caballeros PB (2)',
    'Envios Caballeros PB (2)',
    'Patinetas Caballeros PB (2)',
    'Lockers Caballeros 1er Nivel (5)',
    'RH Caballeros 1er Nivel (3)',
    'Caseta principal caballeros PB (4)',
    'Carpinteria Caballeros PB (3)',
    'Proveedores Caballeros PB (3)',
    'Registro Caballeros PB (3)',
    'Transporte caballeros PB (2)',
    'Taller Mecanico caballeros PB (3)',
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
    'PROVEEDORES (5)',
    'Anexo B Comedor Empleados Cochambre',
    'Comedor Empleados Lavaloza',
    'Comedor Empleados Anexo B Cochambre',
    'Comedor Empleados Cochambre',
    'Comedor Empleados Cocina Caliente',
    'Comedor Empleados Lavaloza'
};

for(String n : names) {
    String serviceType = 'GENERAL';
    if(n.toLowerCase().contains('comedor') || n.toLowerCase().contains('cocina')) {
        serviceType = 'BIOENZIMÁTICO';
    } else if(n.toLowerCase().contains('caballeros') || n.toLowerCase().contains('baño') || n.toLowerCase().contains('r.h')) {
        serviceType = 'GESTIÓN MENSTRUAL (ÍNTIMA); AROMATIZACIÓN';
    } else {
        serviceType = 'PÓLIZA FUMIGACIÓN';
    }

    zonesToInsert.add(new Zona_Servicio_Pyatz__c(
        Name = n,
        Cuenta__c = accId,
        Tipo_de_Servicio__c = serviceType
    ));
}

insert zonesToInsert;
System.debug('Se insertaron ' + zonesToInsert.size() + ' zonas para la cuenta 001V900004XHZxEIAX');
