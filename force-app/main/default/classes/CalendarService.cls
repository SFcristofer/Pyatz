/**
 * Servicio encargado de la recuperación de datos para la visualización 
 * del calendario de operaciones y asignación de recursos de servicio.
 */
public without sharing class CalendarService {

    /**
     * Recupera recursos de servicio y sus citas asociadas en un rango de fechas.
     */
    public static Map<String, Object> getCalendarData(String startDate, String endDate) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            Date startDt = Date.valueOf(startDate); 
            Date endDt = Date.valueOf(endDate);

            result.put('resources', [SELECT Id, Name, ResourceType, RelatedRecord.SmallPhotoUrl FROM ServiceResource WHERE IsActive = true LIMIT 50]);
            
            List<Map<String, Object>> appList = new List<Map<String, Object>>();
            for (ServiceAppointment sa : [SELECT Id, Subject, SchedStartTime, SchedEndTime, Status, Duration, AppointmentNumber, Account.Name, (SELECT ServiceResourceId FROM ServiceResources) 
                                           FROM ServiceAppointment WHERE SchedStartTime >= :startDt AND SchedStartTime <= :endDt ORDER BY SchedStartTime ASC]) {
                Map<String, Object> app = new Map<String, Object>{ 'Id' => sa.Id, 'Folio' => sa.AppointmentNumber, 'Subject' => sa.Subject, 'AccountName' => sa.Account.Name != null ? sa.Account.Name : 'Sin Cliente', 'SchedStartTime' => sa.SchedStartTime, 'SchedEndTime' => sa.SchedEndTime, 'Status' => sa.Status, 'Duration' => sa.Duration != null ? sa.Duration : 0 };
                app.put('ServiceResourceId', !sa.ServiceResources.isEmpty() ? (String)sa.ServiceResources[0].ServiceResourceId : 'UNASSIGNED'); 
                appList.add(app);
            }
            result.put('appointments', appList);
        } catch (Exception e) { throw new AuraHandledException('Error en el motor de calendario: ' + e.getMessage()); }
        return result;
    }

    /**
     * Recupera y normaliza Actividades (Tareas, Llamadas y Eventos) para el Calendario 360.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getActionTimeline(Id opportunityId) {
        List<Map<String, Object>> timeline = new List<Map<String, Object>>();
        if (opportunityId == null) return timeline;

        Date todayDate = Date.today();

        // 1. Recuperar Tareas y Llamadas
        for (Task t : [SELECT Id, Subject, ActivityDate, Status, TaskSubtype, Description, Who.Name, Who.Phone, Who.Id 
                       FROM Task WHERE WhatId = :opportunityId 
                       ORDER BY ActivityDate DESC LIMIT 100]) {
            Map<String, Object> item = new Map<String, Object>();
            String subType = t.TaskSubtype != null ? t.TaskSubtype : 'Task';
            
            item.put('id', t.Id);
            item.put('title', t.Subject);
            item.put('start', t.ActivityDate);
            item.put('status', t.Status);
            item.put('type', subType);
            item.put('description', t.Description);
            item.put('icon', subType == 'Call' ? 'standard:log_a_call' : 'standard:task');
            item.put('colorClass', subType == 'Call' ? 'event-call' : 'event-task');
            
            // Mejoras de contacto y estado
            if (t.Who != null) {
                item.put('whoName', t.Who.Name);
                item.put('whoPhone', t.Who.Phone);
                item.put('whoId', t.Who.Id);
            }
            item.put('isCompleted', t.Status == 'Completed');
            item.put('isOverdue', (t.ActivityDate != null && t.ActivityDate < todayDate && t.Status != 'Completed'));
            item.put('isTaskRecord', true); // Bandera para UI
            
            timeline.add(item);
        }

        // 2. Recuperar Eventos (Citas/Reuniones)
        for (Event e : [SELECT Id, Subject, StartDateTime, EndDateTime, Location, Description, Who.Name, Who.Phone, Who.Id 
                        FROM Event WHERE WhatId = :opportunityId 
                        ORDER BY StartDateTime DESC LIMIT 100]) {
            Map<String, Object> item = new Map<String, Object>();
            item.put('id', e.Id);
            item.put('title', e.Subject);
            item.put('start', e.StartDateTime);
            item.put('end', e.EndDateTime);
            item.put('type', 'Event');
            item.put('location', e.Location);
            item.put('description', e.Description);
            item.put('icon', 'standard:event');
            item.put('colorClass', 'event-meeting');
            
            if (e.Who != null) {
                item.put('whoName', e.Who.Name);
                item.put('whoPhone', e.Who.Phone);
                item.put('whoId', e.Who.Id);
            }
            item.put('isCompleted', e.EndDateTime < Datetime.now());
            
            timeline.add(item);
        }

        // 3. Recuperar Correos Electrónicos Enviados (Historial de Email)
        for (EmailMessage em : [SELECT Id, Subject, MessageDate, IsOpened, FirstOpenedDate, ToAddress 
                               FROM EmailMessage WHERE RelatedToId = :opportunityId 
                               ORDER BY MessageDate DESC LIMIT 50]) {
            Map<String, Object> item = new Map<String, Object>();
            item.put('id', em.Id);
            item.put('title', 'Correo: ' + em.Subject);
            item.put('start', em.MessageDate);
            item.put('type', 'Email');
            item.put('description', 'Enviado a: ' + em.ToAddress + (em.IsOpened ? '\nAbierto por primera vez el: ' + em.FirstOpenedDate : '\nAún no ha sido abierto.'));
            item.put('icon', em.IsOpened ? 'standard:task2' : 'standard:email');
            item.put('colorClass', em.IsOpened ? 'event-email-opened' : 'event-email');
            item.put('isCompleted', true);
            item.put('isEmail', true);
            
            timeline.add(item);
        }

        return timeline;
    }
}