// Paso 1: Ver revisiones del WO
List<Revision_Cita_Servicio__c> revs = [
    SELECT Id, Name, Status__c, Tipo_Reporte__c, Datos_Formulario__c,
           Observaciones__c, Nombre_Firmante__c, Cargo_Firmante__c,
           Fecha_Revision__c, Tecnico__c, Tecnico__r.Name,
           Cita_Servicio__c, Cita_Servicio__r.AppointmentNumber,
           Plantilla_de_Formulario__c, Plantilla_de_Formulario__r.Name
    FROM Revision_Cita_Servicio__c
    WHERE Cita_Servicio__r.ParentRecordId = '0WOV90000071oDSOAY'
    ORDER BY Cita_Servicio__c, Numero_Revision__c ASC
];
System.debug('TOTAL_REVS=' + revs.size());
for (Revision_Cita_Servicio__c r : revs) {
    System.debug('REV|' + r.Id + '|' + r.Name
        + '|SA=' + r.Cita_Servicio__r.AppointmentNumber
        + '|STATUS=' + r.Status__c
        + '|TIPO=' + r.Tipo_Reporte__c
        + '|PLANTILLA_ID=' + r.Plantilla_de_Formulario__c
        + '|PLANTILLA_NAME=' + (r.Plantilla_de_Formulario__r != null ? r.Plantilla_de_Formulario__r.Name : 'NONE')
        + '|TECNICO=' + (r.Tecnico__r != null ? r.Tecnico__r.Name : 'NONE')
        + '|TIENE_JSON=' + String.isNotBlank(r.Datos_Formulario__c));
}

// Paso 2: Ver un JSON existente si hay
for (Revision_Cita_Servicio__c r : revs) {
    if (String.isNotBlank(r.Datos_Formulario__c)) {
        System.debug('JSON_SAMPLE|' + r.Id + '|' + r.Datos_Formulario__c.left(500));
        break;
    }
}

// Paso 3: Ver técnicos disponibles
List<User> tecnicos = [SELECT Id, Name FROM User WHERE IsActive = true AND UserType = 'Standard' LIMIT 5];
for (User u : tecnicos) System.debug('USER|' + u.Id + '|' + u.Name);
