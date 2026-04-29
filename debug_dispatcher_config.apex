
System.debug('--- DIAGNÓSTICO PROFUNDO DISPATCHER PYATZ ---');

// 1. Contar Recursos
Integer countResources = [SELECT count() FROM ServiceResource WHERE IsActive = true];
System.debug('RECURSOS ACTIVOS: ' + countResources);

// 2. Contar Territorios
Integer countTerritories = [SELECT count() FROM ServiceTerritory WHERE IsActive = true];
System.debug('TERRITORIOS ACTIVOS: ' + countTerritories);

// 3. Verificar Permission Sets de FSL
List<PermissionSet> fslPerms = [SELECT Name, Label FROM PermissionSet WHERE Name LIKE '%FSL%' OR Name LIKE '%FieldService%'];
System.debug('PERMISSION SETS FSL DETECTADOS:');
for(PermissionSet ps : fslPerms) {
    System.debug('- ' + ps.Label + ' (' + ps.Name + ')');
}

// 4. Verificar configuración de Dispatcher en el paquete
Boolean packageInstalled = false;
for(Publisher p : [SELECT Name FROM Publisher WHERE Name LIKE '%Field Service%']) {
    packageInstalled = true;
}
System.debug('PAQUETE GESTIONADO FSL INSTALADO: ' + packageInstalled);

System.debug('--- FIN DEL DIAGNÓSTICO ---');
