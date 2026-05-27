public with sharing class AccountDashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardData(Id accountId) {
        Map<String, Object> result = new Map<String, Object>();

        // OPORTUNIDADES
        Integer oppOpen = 0, oppWon = 0;
        for (AggregateResult ar : [
            SELECT IsClosed, IsWon, COUNT(Id) cnt
            FROM Opportunity
            WHERE AccountId = :accountId
            GROUP BY IsClosed, IsWon
        ]) {
            Integer cnt = (Integer) ar.get('cnt');
            Boolean isClosed = (Boolean) ar.get('IsClosed');
            Boolean isWon    = (Boolean) ar.get('IsWon');
            if (!isClosed) oppOpen += cnt;
            else if (isWon) oppWon  += cnt;
        }
        result.put('oppOpen', oppOpen);
        result.put('oppWon',  oppWon);

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

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities(Id accountId) {
        return [
            SELECT Id, Name, StageName, Amount, CloseDate, Probability
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY CloseDate DESC NULLS LAST
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Quote> getQuotes(Id accountId) {
        return [
            SELECT Id, Name, Status, TotalPrice, ExpirationDate, Opportunity.Name
            FROM Quote
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceContract> getContracts(Id accountId) {
        return [
            SELECT Id, Name, ApprovalStatus, StartDate, EndDate, TotalPrice
            FROM ServiceContract
            WHERE AccountId = :accountId
            ORDER BY StartDate DESC NULLS LAST
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<WorkOrder> getWorkOrders(Id accountId) {
        return [
            SELECT Id, WorkOrderNumber, Subject, Status, Priority, CreatedDate
            FROM WorkOrder
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }
}