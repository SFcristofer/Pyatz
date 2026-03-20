Map<String, Schema.SObjectField> fields = Schema.SObjectType.ServiceContract.fields.getMap();
for(String f : fields.keySet()) {
    Schema.DescribeFieldResult d = fields.get(f).getDescribe();
    if(d.getType() == Schema.DisplayType.DATE || d.getType() == Schema.DisplayType.DATETIME) {
        if(d.getLabel().contains('Inicio') || d.getName().contains('Inicio') || d.getLabel().contains('Contrato')) {
            System.debug('CAMPO DETECTADO: ' + d.getName() + ' | Etiqueta: ' + d.getLabel());
        }
    }
}