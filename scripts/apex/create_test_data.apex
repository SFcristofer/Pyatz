WorkOrder wo = new WorkOrder(AccountId='001V900004XHZxDIAX', Subject='Servicio de Prueba Pyatz - Calendario');
insert wo;
ServiceAppointment sa = new ServiceAppointment(
    ParentRecordId=wo.Id, 
    Subject='Cita de Prueba - Mañana', 
    EarliestStartTime=DateTime.now().addDays(1), 
    DueDate=DateTime.now().addDays(2),
    SchedStartTime=DateTime.now().addDays(1).addHours(2), 
    SchedEndTime=DateTime.now().addDays(1).addHours(4), 
    Status='None'
);
insert sa;
System.debug('WO creada ID: ' + wo.Id);
System.debug('SA creada ID: ' + sa.Id);