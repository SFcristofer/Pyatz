Map<String, Schema.SObjectField> fields = Schema.SObjectType.Quote.fields.getMap();
for(String fieldName : fields.keySet()) {
    Schema.DescribeFieldResult dr = fields.get(fieldName).getDescribe();
    if(dr.isCustom()) {
        System.debug('FIELD_SCAN: ' + dr.getName() + ' | LABEL: ' + dr.getLabel() + ' | TYPE: ' + dr.getType());
    }
}