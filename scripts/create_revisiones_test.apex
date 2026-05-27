Id saId     = '08pV9000001CTfBIAW';
Id tecnicoId = UserInfo.getUserId();

List<Revision_Cita_Servicio__c> revisiones = new List<Revision_Cita_Servicio__c>{

    new Revision_Cita_Servicio__c(
        Cita_Servicio__c  = saId,
        Tipo_Reporte__c   = 'Aromatizante',
        Status__c         = 'Completada',
        Fecha_Revision__c = DateTime.now().addHours(-3),
        Tecnico__c        = tecnicoId,
        Observaciones__c  = 'Revisión 1 — equipo en buen estado, consumo normal.'
    ),

    new Revision_Cita_Servicio__c(
        Cita_Servicio__c  = saId,
        Tipo_Reporte__c   = 'Bioenzmático',
        Status__c         = 'Completada',
        Fecha_Revision__c = DateTime.now().addHours(-2),
        Tecnico__c        = tecnicoId,
        Observaciones__c  = 'Revisión 2 — dosificación aplicada correctamente.'
    ),

    new Revision_Cita_Servicio__c(
        Cita_Servicio__c  = saId,
        Tipo_Reporte__c   = 'Limpieza de Trampa',
        Status__c         = 'En Proceso',
        Fecha_Revision__c = DateTime.now(),
        Tecnico__c        = tecnicoId,
        Observaciones__c  = 'Revisión 3 — pendiente confirmación de limpieza profunda.'
    )
};

insert revisiones;

System.debug('✅ Revisiones creadas:');
for (Revision_Cita_Servicio__c r : revisiones) {
    System.debug('  → Id: ' + r.Id);
}
