List<Zona_Servicio_Pyatz__c> newZones = new List<Zona_Servicio_Pyatz__c>();
Id accId = '001V900004XHZxEIAX';

newZones.add(new Zona_Servicio_Pyatz__c(
    Name = 'CDT Almacén Seco',
    Cuenta__c = accId,
    Tipo_de_Servicio__c = 'PÓLIZA FUMIGACIÓN'
));

newZones.add(new Zona_Servicio_Pyatz__c(
    Name = 'CDT Trampa de Grasa Exterior',
    Cuenta__c = accId,
    Tipo_de_Servicio__c = 'BIOENZIMÁTICO'
));

newZones.add(new Zona_Servicio_Pyatz__c(
    Name = 'CDT Baños Damas Planta Baja',
    Cuenta__c = accId,
    Tipo_de_Servicio__c = 'GESTIÓN MENSTRUAL (ÍNTIMA)'
));

newZones.add(new Zona_Servicio_Pyatz__c(
    Name = 'CDT Comedor de Empleados',
    Cuenta__c = accId,
    Tipo_de_Servicio__c = 'BIOENZIMÁTICO; PÓLIZA FUMIGACIÓN'
));

insert newZones;
System.debug('Se insertaron ' + newZones.size() + ' nuevas zonas para la cuenta.');
