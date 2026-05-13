public with sharing class AccountDashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardData(Id accountId) {
        Map<String, Object> result = new Map<String, Object>();

        // ÓRDENES DE TRABAJO
        Integer woTotal = 0, woOpen = 0, woPending = 0;
        for (AggregateResult ar : [
            SELECT Status, COUNT(Id) cnt
            FROM WorkOrder
            WHERE AccountId = :accountId
            GROUP BY Status
        ]) {
            Integer cnt = (Integer) ar.get('cnt');
            String status = (String) ar.get('Status');
            woTotal += cnt;
            if (new Set<String>{'New','In Progress','Dispatched','On Site'}.contains(status)) woOpen += cnt;
            else if (new Set<String>{'Completed','Cannot Complete'}.contains(status)) woPending += cnt;
        }
        result.put('woTotal', woTotal);
        result.put('woOpen', woOpen);
        result.put('woClosed', woPending);

        // PRESUPUESTOS (Quotes) — filtrar por Opportunity.AccountId porque AccountId en Quote no siempre se puebla
        Integer quoteTotal = 0, quoteActive = 0, quotePending = 0;
        for (AggregateResult ar : [
            SELECT Status, COUNT(Id) cnt
            FROM Quote
            WHERE AccountId = :accountId
            GROUP BY Status
        ]) {
            Integer cnt = (Integer) ar.get('cnt');
            String status = (String) ar.get('Status');
            quoteTotal += cnt;
            if (new Set<String>{'Aprobada','Accepted'}.contains(status)) quoteActive += cnt;
            else if (new Set<String>{'Borrador','Pendiente','Actualizada','Presented'}.contains(status)) quotePending += cnt;
        }
        result.put('quoteTotal', quoteTotal);
        result.put('quoteActive', quoteActive);
        result.put('quotePending', quotePending);

        // CONTRATOS (ServiceContract - Field Service)
        Integer scTotal = 0, scActive = 0, scDraft = 0;
        for (AggregateResult ar : [
            SELECT ApprovalStatus, COUNT(Id) cnt
            FROM ServiceContract
            WHERE AccountId = :accountId
            GROUP BY ApprovalStatus
        ]) {
            Integer cnt = (Integer) ar.get('cnt');
            String status = (String) ar.get('ApprovalStatus');
            scTotal += cnt;
            if (status == 'Activado') scActive += cnt;
            else if (new Set<String>{'Borrador','En proceso de aprobación','Cancelled'}.contains(status)) scDraft += cnt;
        }
        result.put('scTotal', scTotal);
        result.put('scActive', scActive);
        result.put('scInactive', scDraft);

        // ZONAS DE SERVICIO
        Integer zonaCount = [
            SELECT COUNT() FROM Zona_Servicio_Pyatz__c WHERE Cuenta__c = :accountId
        ];
        result.put('zonaCount', zonaCount);

        return result;
    }
}
