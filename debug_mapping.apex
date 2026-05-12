Id woId = '0WOV9000006uEzJOAU';
WorkOrder wo = [SELECT Id, ServiceContractId, AccountId FROM WorkOrder WHERE Id = :woId];

List<ServiceAppointment> sas = [SELECT Id, Subject, SchedStartTime, Producto_Relacionado__c FROM ServiceAppointment WHERE ParentRecordId = :woId];
System.debug('Total SAs: ' + sas.size());

for(ServiceAppointment sa : sas) {
    System.debug('SA: ' + sa.Id + ' | Subject: ' + sa.Subject + ' | Product: ' + sa.Producto_Relacionado__c);
}

// Check if these products match the QLIs
List<QuoteLineItem> qlis = [SELECT Id, Product2Id, Product2.Name FROM QuoteLineItem WHERE Quote.QuoteNumber LIKE '%104%'];
for(QuoteLineItem qli : qlis) {
    System.debug('QLI: ' + qli.Id + ' | Product: ' + qli.Product2Id + ' (' + qli.Product2.Name + ')');
}
