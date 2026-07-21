List<Schema.PicklistEntry> ple = Form_Template__c.Tipo_Reporte__c.getDescribe().getPicklistValues();
for(Schema.PicklistEntry p : ple) {
    System.debug('VALOR: ' + p.getValue());
}
