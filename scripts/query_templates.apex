// JSONs de revisiones completadas
List<Revision_Cita_Servicio__c> todas = [
    SELECT Id, Tipo_Reporte__c, Status__c, Datos_Formulario__c
    FROM Revision_Cita_Servicio__c
    WHERE Cita_Servicio__r.ParentRecordId = '0WOV90000071oDSOAY'
    AND Status__c = 'Completada'
    ORDER BY Tipo_Reporte__c
];
for (Revision_Cita_Servicio__c r : todas) {
    if (String.isNotBlank(r.Datos_Formulario__c))
        System.debug('JSON|' + r.Tipo_Reporte__c + '|' + r.Datos_Formulario__c);
}

// Campos de Form_Template__c
Schema.DescribeSObjectResult d = Form_Template__c.sObjectType.getDescribe();
for (Schema.SObjectField f : d.fields.getMap().values()) {
    System.debug('FT_FIELD|' + f.getDescribe().getName() + '|' + f.getDescribe().getType());
}

// Técnico Guillermo
List<User> guillos = [SELECT Id, Name FROM User WHERE Name LIKE '%GUILLERMO%' AND IsActive = true LIMIT 3];
for (User u : guillos) System.debug('TECH|' + u.Id + '|' + u.Name);

// SAs del WO
List<ServiceAppointment> sas = [
    SELECT Id, AppointmentNumber, Zonas_a_Tratar__c,
           Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode
    FROM ServiceAppointment
    WHERE ParentRecordId = '0WOV90000071oDSOAY'
    ORDER BY AppointmentNumber
];
for (ServiceAppointment sa : sas) {
    System.debug('SA|' + sa.AppointmentNumber
        + '|ZONA=' + sa.Zonas_a_Tratar__c
        + '|PROD=' + (sa.Producto_Relacionado__r != null ? sa.Producto_Relacionado__r.Name : 'NONE'));
}
