Map<String, Schema.SObjectField> fields = Schema.SObjectType.Quote.fields.getMap();
String[] targets = new String[]{'Business_Lines_Selected__c', 'Technical_Sedes__c', 'Markers_Data__c'};
for(String t : targets) {
    if(fields.containsKey(t.toLowerCase())) {
        System.debug('OK: Campo ' + t + ' EXISTE.');
    } else {
        System.debug('ERR: Campo ' + t + ' NO EXISTE.');
    }
}