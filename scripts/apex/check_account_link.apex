Id targetId = '001V900004XHz6wIAD';
Quote q = [SELECT Id, Name, AccountId, Account.Name, OpportunityId, Opportunity.AccountId FROM Quote ORDER BY CreatedDate DESC LIMIT 1];

System.debug('--- ANALISIS DE VINCULO ---');
System.debug('NOMBRE PRESUPUESTO: ' + q.Name);
System.debug('ID CUENTA EN PRESUPUESTO: ' + q.AccountId);
System.debug('ID CUENTA EN OPORTUNIDAD: ' + q.Opportunity.AccountId);
System.debug('ID PROPORCIONADO POR USUARIO: ' + targetId);

if (q.AccountId == targetId) {
    System.debug('ESTADO: LOS IDs COINCIDEN. El presupuesto SÍ está vinculado a esta cuenta.');
} else {
    System.debug('ESTADO: DISCREPANCIA DETECTADA. El presupuesto está vinculado a otra cuenta.');
}

// Verificar si hay otras cotizaciones vinculadas a este ID de cuenta
List<Quote> others = [SELECT Id, Name FROM Quote WHERE AccountId = :targetId];
System.debug('TOTAL PRESUPUESTOS EN ESTA CUENTA: ' + others.size());
for(Quote o : others) {
    System.debug('- Presupuesto: ' + o.Name);
}
System.debug('---------------------------');
