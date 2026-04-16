// 1. Buscar Objetos que contengan PL o Margen
System.debug('--- BUSCANDO OBJETOS PERSONALIZADOS EN LA ORG ---');
for(Schema.SObjectType objType : Schema.getGlobalDescribe().Values()) {
    String name = objType.getDescribe().getName();
    if(name.contains('__c') && (name.contains('PL') || name.contains('Margen') || name.contains('Estrategia') || name.contains('Financiero'))) {
        System.debug('OBJETO_ENCONTRADO: ' + name);
    }
}

// 2. Escaneo exhaustivo de campos en Quote (Org)
System.debug('--- ESCANEANDO TODOS LOS CAMPOS CUSTOM EN QUOTE (ORG) ---');
Map<String, Schema.SObjectField> quoteFields = Schema.SObjectType.Quote.fields.getMap();
for(String fieldName : quoteFields.keySet()) {
    Schema.DescribeFieldResult dr = quoteFields.get(fieldName).getDescribe();
    if(dr.isCustom()) {
        System.debug('QUOTE_FIELD: ' + dr.getName() + ' (' + dr.getLabel() + ') - ' + dr.getType());
    }
}

// 3. Escaneo exhaustivo de campos en Opportunity (Org)
System.debug('--- ESCANEANDO TODOS LOS CAMPOS CUSTOM EN OPPORTUNITY (ORG) ---');
Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
for(String fieldName : oppFields.keySet()) {
    Schema.DescribeFieldResult dr = oppFields.get(fieldName).getDescribe();
    if(dr.isCustom()) {
        System.debug('OPP_FIELD: ' + dr.getName() + ' (' + dr.getLabel() + ') - ' + dr.getType());
    }
}