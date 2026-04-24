List<Documento_Expediente__mdt> docs = [SELECT Label, Tag__c, Categoria__c FROM Documento_Expediente__mdt ORDER BY Tag__c];
System.debug('--- REPORTE DE DOCUMENTOS PYATZ ---');
for(Documento_Expediente__mdt d : docs) {
    System.debug('DOCUMENTO: [' + d.Tag__c + '] | LABEL: ' + d.Label + ' | CATEGORIA: ' + d.Categoria__c);
}
System.debug('--- FIN DEL REPORTE ---');