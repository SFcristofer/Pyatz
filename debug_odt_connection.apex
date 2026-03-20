// 1. Verificar la relación Product2 en ContractLineItem
Map<String, Schema.SObjectField> fields = Schema.SObjectType.ContractLineItem.fields.getMap();
System.debug('--- Verificando Relaciones en ContractLineItem ---');
System.debug('Tiene Product2Id: ' + fields.containsKey('product2id'));
System.debug('Tiene PricebookEntryId: ' + fields.containsKey('pricebookentryid'));

// 2. Verificar existencia de Contratos Recientes
List<ServiceContract> scs = [SELECT Id, Name, (SELECT Id FROM ContractLineItems) FROM ServiceContract ORDER BY CreatedDate DESC LIMIT 1];
if(!scs.isEmpty()) {
    System.debug('Último Contrato: ' + scs[0].Name);
    System.debug('Número de Partidas: ' + scs[0].ContractLineItems.size());
} else {
    System.debug('CRÍTICO: No se encontró ningún ServiceContract en la Org.');
}