Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

System.debug('--- REPORTE DE ACTIVACIÓN PYATZ ---');

// 1. Validar ServiceContract
if(gd.containsKey('servicecontract')) {
    System.debug('OK: ServiceContract (Contratos de Servicio) está ACTIVO.');
} else {
    System.debug('ERR: ServiceContract NO está activo.');
}

// 2. Validar WorkOrder y relación con Opportunity
if(gd.containsKey('workorder')) {
    System.debug('OK: WorkOrder está ACTIVO.');
    Map<String, Schema.SObjectField> woFields = gd.get('workorder').getDescribe().fields.getMap();
    if(woFields.containsKey('opportunityid')) {
        System.debug('OK: Relación WorkOrder -> Opportunity (Estandar) está ACTIVA.');
    } else {
        System.debug('ERR: Relación WorkOrder -> Opportunity NO está activa.');
    }
}

// 3. Validar ServiceAppointment e IsPinned
if(gd.containsKey('serviceappointment')) {
    System.debug('OK: ServiceAppointment está ACTIVO.');
    Map<String, Schema.SObjectField> saFields = gd.get('serviceappointment').getDescribe().fields.getMap();
    if(saFields.containsKey('ispinned')) {
        System.debug('OK: Campo IsPinned (Nativo FSL) está ACTIVO.');
    } else {
        System.debug('ERR: Campo IsPinned NO está activo. (Requiere activar Optimización de FSL)');
    }
}
System.debug('--- FIN DEL REPORTE ---');