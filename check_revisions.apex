Id saId = '08pV9000001CDtlIAG';
ServiceAppointment sa = [SELECT Id, Zonas_a_Tratar__c FROM ServiceAppointment WHERE Id = :saId];
System.debug('SA Zonas: ' + sa.Zonas_a_Tratar__c);

List<Revision_Cita_Servicio__c> revs = [SELECT Id, Name, Tipo_Reporte__c, Numero_Revision__c FROM Revision_Cita_Servicio__c WHERE Cita_Servicio__c = :saId];
System.debug('Revs count: ' + revs.size());
for(Revision_Cita_Servicio__c r : revs) {
    System.debug('Rev: ' + r.Name + ' | Tipo: ' + r.Tipo_Reporte__c + ' | Num: ' + r.Numero_Revision__c);
}
