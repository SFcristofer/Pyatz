/**
 * Lógica de procesamiento para el motor de partidas técnicas y sincronización de presupuestos.
 */
public with sharing class QuoteEngineService {

    /**
     * Procesa el guardado integral de datos técnicos, partidas y sincronización de oportunidad.
     */
    public static Id saveTechnicalData(Map<String, Object> data) {
        try {
            Map<String, Object> p = data.containsKey('data') ? (Map<String, Object>)data.get('data') : data;
            Id rid = (Id)p.get('quoteId');
            Id contactId = p.containsKey('contactId') && p.get('contactId') != null ? (Id)p.get('contactId') : null;
            String oppIdStr = (String)p.get('opportunityId');
            Id oppId = (oppIdStr != null && oppIdStr != '') ? (Id)oppIdStr : null;
            String itemsJson = (String)p.get('lineItems');
            String status = (String)p.get('status');
            
            Quote q;
            String businessLines = (String)p.get('businessLines');
            if (rid != null && rid.getSObjectType().getDescribe().getName() == 'Quote') {
                q = [SELECT Id, Pricebook2Id FROM Quote WHERE Id = :rid LIMIT 1 FOR UPDATE];
                q.Name = (String)p.get('name'); q.Status = status; q.ContactId = contactId;
                q.Introduction_Text__c = (String)p.get('intro'); q.Warranty_Text__c = (String)p.get('warranty');
                q.Markers_Data__c = (String)p.get('markersData'); q.Technical_Sedes__c = (String)p.get('technicalSedes');
                q.Description = (String)p.get('observacionesPago');
                q.Estrategia_Venta__c = (String)p.get('estrategiaVenta');
                q.Business_Lines_Selected__c = businessLines;
                update q;
            } else {
                if (oppId == null && rid != null && rid.getSObjectType().getDescribe().getName() == 'Opportunity') oppId = rid;
                Id pbId;
                if (oppId != null) { List<Opportunity> opps = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1]; if (!opps.isEmpty()) pbId = opps[0].Pricebook2Id; }
                if (pbId == null) pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1].Id;
                q = new Quote(Name = (String)p.get('name'), OpportunityId = oppId, Pricebook2Id = pbId, Status = status, ContactId = contactId, Introduction_Text__c = (String)p.get('intro'), Warranty_Text__c = (String)p.get('warranty'), Markers_Data__c = (String)p.get('markersData'), Technical_Sedes__c = (String)p.get('technicalSedes'), Description = (String)p.get('observacionesPago'), Estrategia_Venta__c = (String)p.get('estrategiaVenta'), Business_Lines_Selected__c = businessLines, ExpirationDate = Date.today().addDays(30));
                insert q; rid = q.Id;
            }

            if (String.isNotBlank((String)p.get('markersData')) && rid != null) {
                LevantamientoService.processLevantamientos(rid, (String)p.get('markersData'));
                QuoteTechnicalController.syncServiceZones(rid, (String)p.get('markersData'));
            }

            if (String.isNotBlank(itemsJson) && rid != null) {
                List<Object> items = (List<Object>)JSON.deserializeUntyped(itemsJson);
                delete [SELECT Id FROM QuoteLineItem WHERE QuoteId = :rid];
                List<QuoteLineItem> qlis = new List<QuoteLineItem>();
                for (Object obj : items) {
                    Map<String, Object> it = (Map<String, Object>)obj;
                    String pbeIdStr = (String)it.get('pbeId'); if (String.isBlank(pbeIdStr) || pbeIdStr == 'null') pbeIdStr = (String)it.get('id');
                    if (String.isBlank(pbeIdStr) || pbeIdStr.length() < 15) continue;
                    try {
                        Decimal can = Decimal.valueOf(String.valueOf(it.get('cantidad') != null ? it.get('cantidad') : 1));
                        Decimal tot = Decimal.valueOf(String.valueOf(it.get('totalSinImpuestos') != null ? it.get('totalSinImpuestos') : 0));
                        qlis.add(new QuoteLineItem(
                            QuoteId = rid, 
                            PricebookEntryId = (Id)pbeIdStr, 
                            Quantity = (can > 0 ? can : 1), 
                            UnitPrice = (can > 0 ? (tot/can) : tot), 
                            Descripcion_Detallada__c = (String)it.get('detalleTecnico'),
                            Zonas_a_Tratar__c = (String)it.get('areas'),
                            Levantamiento_Tecnico__c = (it.get('levantamientoId') != null && String.valueOf(it.get('levantamientoId')) != '') ? (Id)it.get('levantamientoId') : null
                        ));
                    } catch (Exception e) {}
                }
                if (!qlis.isEmpty()) insert qlis;
            }
            if (oppId != null && rid != null) {
                Opportunity opp = new Opportunity(Id = oppId, SyncedQuoteId = rid);
                if (businessLines != null) opp.Linea_de_negocio__c = businessLines;
                if (q.Estrategia_Venta__c != null) {
                    Map<String, String> strategyLabels = new Map<String, String>{
                        'E1' => 'E1 - Póliza Anual', 'E2' => 'E2 - Extraordinario',
                        'E3' => 'E3 - Cliente Nuevo', 'E4' => 'E4 - Retardantes', 'E5' => 'E5 - Cedis'
                    };
                    opp.Tipo_de_venta__c = strategyLabels.containsKey(q.Estrategia_Venta__c) ? strategyLabels.get(q.Estrategia_Venta__c) : q.Estrategia_Venta__c;
                }
                update opp;
            }
            return rid;
        } catch (Exception e) { throw new AuraHandledException('Error técnico: ' + e.getMessage()); }
    }

    /**
     * Motor de búsqueda de productos con filtrado por línea de negocio y priorización de precios.
     */
    public static List<Map<String, Object>> searchProducts(String searchTerm, Id quoteId, List<String> businessLines, Boolean allowOtherLines) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        Id pbId; List<String> lines = businessLines != null ? businessLines : new List<String>();
        if (quoteId != null) { Quote q = [SELECT Pricebook2Id, Business_Lines_Selected__c FROM Quote WHERE Id = :quoteId LIMIT 1]; pbId = q.Pricebook2Id; if (lines.isEmpty() && q.Business_Lines_Selected__c != null) { for(String s : q.Business_Lines_Selected__c.split(',')) lines.add(s.trim()); } }
        String query = '%' + searchTerm + '%';
        String soql = 'SELECT Id, Name, ProductCode, Description, Family FROM Product2 WHERE (Name LIKE :query OR ProductCode LIKE :query) AND IsActive = true ';
        if (!allowOtherLines && !lines.isEmpty()) soql += 'AND Family IN :lines ';
        List<Product2> products = Database.query(soql + ' ORDER BY Name ASC LIMIT 40');
        if (products.isEmpty()) return results;
        Map<Id, List<PricebookEntry>> prodToPbes = new Map<Id, List<PricebookEntry>>();
        for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice, Pricebook2Id, Pricebook2.Name, Pricebook2.IsStandard FROM PricebookEntry WHERE Product2Id IN :new Map<Id, Product2>(products).keySet() AND IsActive = true AND Pricebook2.IsActive = true]) {
            if (!prodToPbes.containsKey(pbe.Product2Id)) prodToPbes.put(pbe.Product2Id, new List<PricebookEntry>());
            prodToPbes.get(pbe.Product2Id).add(pbe);
        }
        for (Product2 p : products) {
            List<PricebookEntry> pbes = prodToPbes.get(p.Id); if (pbes == null || pbes.isEmpty()) continue;
            PricebookEntry best = null;
            for (PricebookEntry pbe : pbes) { if (pbId != null && pbe.Pricebook2Id == pbId) { best = pbe; break; } }
            if (best == null) { for (PricebookEntry pbe : pbes) { if (pbe.Pricebook2.IsStandard) { best = pbe; break; } } }
            if (best == null) best = pbes[0];
            results.add(new Map<String, Object>{ 'id' => best.Id, 'productId' => p.Id, 'name' => p.Name, 'sku' => p.ProductCode, 'description' => p.Description, 'unitPrice' => best.UnitPrice, 'pricebookName' => best.Pricebook2.Name });
        }
        return results;
    }
}