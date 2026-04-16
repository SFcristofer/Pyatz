
Schema.DescribeFieldResult F = Opportunity.Estado_Subetapa__c.getDescribe();
List<Schema.PicklistEntry> P = F.getPicklistValues();
System.debug('--- DIAGNÓSTICO DE ESTADOS ---');
System.debug('Total de valores encontrados: ' + P.size());

for(Schema.PicklistEntry entry : P) {
    if(entry.isActive()) {
        System.debug('Valor Activo: ' + entry.getLabel() + ' (API: ' + entry.getValue() + ')');
    }
}

Schema.DescribeFieldResult F2 = Opportunity.Subetapa__c.getDescribe();
System.debug('--- CAMPO CONTROLADOR: Subetapa ---');
for(Schema.PicklistEntry entry : F2.getPicklistValues()) {
    System.debug('Controlador Disponible: ' + entry.getLabel());
}
