List<Solucion_Tecnica__c> soluciones = [SELECT Id, Levantamiento_Tecnico__c, Levantamiento_Tecnico__r.Oportunidad__c, Oportunidad__c FROM Solucion_Tecnica__c WHERE Levantamiento_Tecnico__c != null];
List<Solucion_Tecnica__c> solucionesToUpdate = new List<Solucion_Tecnica__c>();
List<Enlace_Solucion__c> enlacesToInsert = new List<Enlace_Solucion__c>();

for(Solucion_Tecnica__c sol : soluciones) {
    if(sol.Oportunidad__c == null) {
        sol.Oportunidad__c = sol.Levantamiento_Tecnico__r.Oportunidad__c;
        solucionesToUpdate.add(sol);
    }
    
    // Create junction record
    Enlace_Solucion__c enlace = new Enlace_Solucion__c(
        Solucion_Tecnica__c = sol.Id,
        Levantamiento_Tecnico__c = sol.Levantamiento_Tecnico__c
    );
    enlacesToInsert.add(enlace);
}

if(!solucionesToUpdate.isEmpty()) {
    update solucionesToUpdate;
}
if(!enlacesToInsert.isEmpty()) {
    insert enlacesToInsert;
}
System.debug('Migracion completada. Soluciones actualizadas: ' + solucionesToUpdate.size() + '. Enlaces creados: ' + enlacesToInsert.size());
