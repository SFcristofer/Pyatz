/**
 * Servicio encargado de la recuperación de datos para la visualización 
 * del calendario de operaciones y asignación de recursos de servicio.
 */
public with sharing class CalendarService {

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
                app.put('ServiceResourceId', !sa.ServiceResources.isEmpty() ? sa.ServiceResources[0].ServiceResourceId : 'UNASSIGNED'); 
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

        // 1. Recuperar Tareas y Llamadas
        for (Task t : [SELECT Id, Subject, ActivityDate, Status, TaskSubtype, Description 
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
            timeline.add(item);
        }

        // 2. Recuperar Eventos (Citas/Reuniones)
        for (Event e : [SELECT Id, Subject, StartDateTime, EndDateTime, Location, Description 
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
            timeline.add(item);
        }

        return timeline;
    }
}