// Localizando las imágenes originales del Membrete Pyatz2
for(BrandTemplate bt : [SELECT Id, Name, Value FROM BrandTemplate WHERE Name LIKE '%Membrete%Pyatz2%']) {
    System.debug('BRAND_TEMPLATE_ID: ' + bt.Id);
    System.debug('BRAND_TEMPLATE_CONTENT: ' + bt.Value);
}
// También buscaremos Documentos que puedan ser los originales (alta res)
for(Document d : [SELECT Id, Name, DeveloperName FROM Document WHERE Name LIKE '%Header%' OR Name LIKE '%Footer%' OR Name LIKE '%Membrete%' LIMIT 20]) {
    System.debug('DOCUMENT_FOUND: ' + d.Name + ' | ID: ' + d.Id);
}