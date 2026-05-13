trigger RevisionCitaTrigger on Revision_Cita_Servicio__c (
    after insert, after update, after delete, after undelete
) {
    Set<Id> saIds = new Set<Id>();
    List<Revision_Cita_Servicio__c> records = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (Revision_Cita_Servicio__c r : records) {
        if (r.Cita_Servicio__c != null) saIds.add(r.Cita_Servicio__c);
    }
    if (Trigger.isUpdate) {
        for (Revision_Cita_Servicio__c r : Trigger.old) {
            if (r.Cita_Servicio__c != null) saIds.add(r.Cita_Servicio__c);
        }
    }
    if (!saIds.isEmpty()) RevisionCitaTriggerHandler.syncSA(saIds);
}
