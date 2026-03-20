Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
String[] objects = new String[]{'servicecontract', 'contract'};

for(String objName : objects) {
    if(gd.containsKey(objName)) {
        System.debug('--- LISTA COMPLETA DE CAMPOS: ' + objName.toUpperCase() + ' ---');
        Map<String, Schema.SObjectField> fields = gd.get(objName).getDescribe().fields.getMap();
        List<String> fieldNames = new List<String>(fields.keySet());
        fieldNames.sort();
        for(String f : fieldNames) {
            Schema.DescribeFieldResult d = fields.get(f).getDescribe();
            System.debug('Campo: ' + d.getName() + ' | Etiqueta: ' + d.getLabel() + ' | Tipo: ' + d.getType());
        }
    }
}