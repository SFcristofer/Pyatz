Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

System.debug('--- ANÁLISIS EXHAUSTIVO DE OBJETOS FIELD SERVICE ---');

// 1. Analizar ServiceAppointment
if(gd.containsKey('serviceappointment')) {
    System.debug('--- ServiceAppointment Fields ---');
    Map<String, Schema.SObjectField> fields = gd.get('serviceappointment').getDescribe().fields.getMap();
    List<String> fieldNames = new List<String>(fields.keySet());
    fieldNames.sort();
    for(String f : fieldNames) {
        if(f.contains('fsl') || f.contains('note') || f.contains('pin') || f.contains('sched')) {
            System.debug('SA Field: ' + fields.get(f).getDescribe().getName() + ' (' + fields.get(f).getDescribe().getType() + ')');
        }
    }
}

// 2. Analizar WorkOrder
if(gd.containsKey('workorder')) {
    System.debug('--- WorkOrder Fields ---');
    Map<String, Schema.SObjectField> fields = gd.get('workorder').getDescribe().fields.getMap();
    List<String> fieldNames = new List<String>(fields.keySet());
    fieldNames.sort();
    for(String f : fieldNames) {
        if(f.contains('fsl') || f.contains('contract') || f.contains('opp') || f.contains('quote')) {
            System.debug('WO Field: ' + fields.get(f).getDescribe().getName() + ' (' + fields.get(f).getDescribe().getType() + ')');
        }
    }
}
System.debug('--- FIN DEL ANÁLISIS ---');