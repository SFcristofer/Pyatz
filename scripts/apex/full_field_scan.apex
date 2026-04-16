Map<String, Schema.SObjectField> fields = Schema.SObjectType.Quote.fields.getMap();
System.debug('--- CAMPOS PERSONALIZADOS EN QUOTE ---');
for(String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    if(d.isCustom()) {
        System.debug('Nombre API: ' + d.getName() + ' | Etiqueta: ' + d.getLabel());
    }
}
System.debug('--------------------------------------');
