Map<String, Object> payload = new Map<String, Object>();
payload.put('opportunityId', '006V900000OrM6DIAV');
payload.put('name', 'PYATZ - Ptto SIMULADO - Prueba2026');
payload.put('status', 'Borrador');
payload.put('intro', 'Introducción de prueba de vinculación');
payload.put('warranty', 'Garantía de prueba de vinculación');
payload.put('observacionesPago', 'Pago en una sola exhibición');
payload.put('markersData', '');
payload.put('technicalSedes', 'Sede Principal');
payload.put('lineItems', '[]');

try {
    Id quoteId = QuoteTechnicalController.saveTechnicalData(payload);
    System.debug('>>> PRESUPUESTO CREADO: ' + quoteId);
    
    Quote q = [SELECT Id, OpportunityId, Name FROM Quote WHERE Id = :quoteId];
    System.debug('>>> VINCULACIÓN: ' + q.OpportunityId);
} catch (Exception e) {
    System.debug('>>> ERROR: ' + e.getMessage());
}
