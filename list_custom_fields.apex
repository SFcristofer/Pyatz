Map<String, Schema.SObjectField> fields = Schema.SObjectType.ServiceContract.fields.getMap();
for(String f : fields.keySet()) {
    if(f.endsWith('__c')) {
        Schema.DescribeFieldResult d = fields.get(f).getDescribe();
        System.debug('CAMPO CUSTOM: ' + d.getName() + ' | Etiqueta: ' + d.getLabel());
    }
}