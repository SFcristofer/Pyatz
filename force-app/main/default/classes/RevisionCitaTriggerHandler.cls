public with sharing class RevisionCitaTriggerHandler {

    public static void syncSA(Set<Id> saIds) {
        Map<Id, Integer> totalMap     = new Map<Id, Integer>();
        Map<Id, Integer> completedMap = new Map<Id, Integer>();

        for (Id sid : saIds) {
            totalMap.put(sid, 0);
            completedMap.put(sid, 0);
        }

        for (AggregateResult ar : [
            SELECT Cita_Servicio__c sa, COUNT(Id) cnt
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :saIds
            GROUP BY Cita_Servicio__c
        ]) {
            totalMap.put((Id) ar.get('sa'), (Integer) ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT Cita_Servicio__c sa, COUNT(Id) cnt
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :saIds AND Status__c = 'Completada'
            GROUP BY Cita_Servicio__c
        ]) {
            completedMap.put((Id) ar.get('sa'), (Integer) ar.get('cnt'));
        }

        List<ServiceAppointment> toUpdate = new List<ServiceAppointment>();
        for (ServiceAppointment sa : [
            SELECT Id, Status, Revisiones__c
            FROM ServiceAppointment
            WHERE Id IN :saIds
        ]) {
            Integer total     = totalMap.get(sa.Id);
            Integer completed = completedMap.get(sa.Id);

            sa.Revisiones__c = total;

            String newStatus;
            if (total > 0 && completed >= total) {
                newStatus = 'Completado';
            } else if (total > 0) {
                newStatus = 'En curso';
            }

            if (newStatus != null && sa.Status != newStatus) {
                sa.Status = newStatus;
            }

            toUpdate.add(sa);
        }

        if (!toUpdate.isEmpty()) {
            try { update toUpdate; } catch (Exception e) { /* status transition may be restricted */ }
        }
    }
}
