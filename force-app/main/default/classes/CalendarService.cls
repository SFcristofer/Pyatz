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
}
