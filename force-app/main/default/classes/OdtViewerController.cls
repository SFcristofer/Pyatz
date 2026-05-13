public with sharing class OdtViewerController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getContractsForAccount(Id accountId) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (ServiceContract sc : [
            SELECT Id, ContractNumber, Name, Status
            FROM ServiceContract
            WHERE AccountId = :accountId
            ORDER BY ContractNumber ASC
        ]) {
            result.add(new Map<String, String>{
                'id'    => sc.Id,
                'label' => sc.ContractNumber + ' — ' + sc.Name + ' (' + sc.Status + ')'
            });
        }
        return result;
    }

    @AuraEnabled
    public static void assignWorkOrdersToContract(List<Id> workOrderIds, Id contractId) {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Id IN :workOrderIds];
        for (WorkOrder wo : wos) {
            wo.ServiceContractId = contractId;
        }
        update wos;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getOppAndQuoteFromContract(Id contractId) {
        List<ServiceContract> scs = [
            SELECT Quote_Source__c, Quote_Source__r.OpportunityId
            FROM ServiceContract
            WHERE Id = :contractId
            LIMIT 1
        ];
        if (scs.isEmpty() || scs[0].Quote_Source__r == null) {
            throw new AuraHandledException('No se encontró oportunidad vinculada a este contrato.');
        }
        return new Map<String, String>{
            'oppId'   => scs[0].Quote_Source__r.OpportunityId,
            'quoteId' => scs[0].Quote_Source__c
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceTerritoriesForAccount() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (ServiceTerritory st : [
            SELECT Id, Name FROM ServiceTerritory WHERE IsActive = true ORDER BY Name ASC LIMIT 100
        ]) {
            result.add(new Map<String, String>{ 'id' => st.Id, 'label' => st.Name });
        }
        return result;
    }

    @AuraEnabled
    public static void bulkUpdateWorkOrders(
        List<Id>  workOrderIds,
        String    status,
        String    priority,
        String    startDate,
        Id        contractId,
        Id        territoryId,
        String    description
    ) {
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Id IN :workOrderIds];
        for (WorkOrder wo : wos) {
            if (String.isNotBlank(status))      wo.Status             = status;
            if (String.isNotBlank(priority))    wo.Priority           = priority;
            if (String.isNotBlank(startDate))   wo.StartDate          = Date.valueOf(startDate);
            if (contractId  != null)            wo.ServiceContractId  = contractId;
            if (territoryId != null)            wo.ServiceTerritoryId = territoryId;
            if (String.isNotBlank(description)) wo.Description        = description;
        }
        update wos;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOdtsByAccount(Id accountId) {
        // 1. ServiceContracts
        Map<Id, Map<String, Object>> scMap = new Map<Id, Map<String, Object>>();
        for (ServiceContract sc : [
            SELECT Id, ContractNumber, Status, StartDate, EndDate, Name
            FROM ServiceContract
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
        ]) {
            scMap.put(sc.Id, new Map<String, Object>{
                'id'         => sc.Id,
                'number'     => sc.ContractNumber,
                'name'       => sc.Name,
                'status'     => sc.Status,
                'startDate'  => sc.StartDate != null ? sc.StartDate.format() : '',
                'endDate'    => sc.EndDate   != null ? sc.EndDate.format()   : '',
                'workOrders' => new List<Map<String, Object>>()
            });
        }

        // 2. Todas las citas de servicio por WorkOrder
        Map<Id, List<Map<String, Object>>> woAppointments = new Map<Id, List<Map<String, Object>>>();
        for (ServiceAppointment sa : [
            SELECT Id, AppointmentNumber, ParentRecordId, SchedStartTime, Duration, Status, Description,
                   (SELECT ServiceResource.Name FROM ServiceResources LIMIT 1)
            FROM ServiceAppointment
            WHERE ParentRecordId IN (SELECT Id FROM WorkOrder WHERE AccountId = :accountId)
            ORDER BY SchedStartTime ASC
        ]) {
            if (!woAppointments.containsKey(sa.ParentRecordId)) {
                woAppointments.put(sa.ParentRecordId, new List<Map<String, Object>>());
            }
            String techName  = sa.ServiceResources.isEmpty() ? '' : sa.ServiceResources[0].ServiceResource.Name;
            String schedDate = sa.SchedStartTime != null ? sa.SchedStartTime.format('dd/MM/yyyy HH:mm') : '';
            Integer durationMins = sa.Duration != null ? Integer.valueOf(sa.Duration) : 0;
            woAppointments.get(sa.ParentRecordId).add(new Map<String, Object>{
                'id'         => sa.Id,
                'number'     => sa.AppointmentNumber,
                'schedDate'  => schedDate,
                'duration'   => durationMins > 0 ? String.valueOf(durationMins) + ' min' : '—',
                'status'     => sa.Status != null ? sa.Status : '',
                'technician' => techName,
                'notes'      => sa.Description != null ? sa.Description : ''
            });
        }

        // 3. Tratamientos por WorkOrder (WorkOrderLineItem → ProductCode)
        Map<Id, List<String>> woTreatments = new Map<Id, List<String>>();
        for (WorkOrderLineItem woli : [
            SELECT WorkOrderId, Product2.ProductCode, Product2.Name
            FROM WorkOrderLineItem
            WHERE WorkOrder.AccountId = :accountId
            ORDER BY WorkOrderId
        ]) {
            if (!woTreatments.containsKey(woli.WorkOrderId)) {
                woTreatments.put(woli.WorkOrderId, new List<String>());
            }
            String code = String.isNotBlank(woli.Product2?.ProductCode)
                ? woli.Product2.ProductCode
                : (woli.Product2?.Name ?? '');
            if (!woTreatments.get(woli.WorkOrderId).contains(code)) {
                woTreatments.get(woli.WorkOrderId).add(code);
            }
        }

        // 4. WorkOrders agrupadas por contrato
        Map<String, Object> sinContrato = new Map<String, Object>{
            'id'         => 'sin-contrato',
            'number'     => '—',
            'name'       => 'Sin Contrato',
            'status'     => '',
            'startDate'  => '',
            'endDate'    => '',
            'workOrders' => new List<Map<String, Object>>()
        };

        for (WorkOrder wo : [
            SELECT Id, WorkOrderNumber, Status, StartDate, Subject, Description,
                   ServiceContractId, ServiceTerritory.Name, Priority
            FROM WorkOrder
            WHERE AccountId = :accountId
            ORDER BY StartDate DESC NULLS LAST
            LIMIT 500
        ]) {
            List<Map<String, Object>> appts = woAppointments.containsKey(wo.Id)
                ? woAppointments.get(wo.Id)
                : new List<Map<String, Object>>();

            String fecha = wo.StartDate != null ? wo.StartDate.format() : '';
            if (String.isBlank(fecha) && !appts.isEmpty()) {
                fecha = (String) appts[0].get('schedDate');
            }
            String startDateRaw = wo.StartDate != null
                ? wo.StartDate.format('yyyy-MM-dd')
                : '';

            Map<String, Object> woData = new Map<String, Object>{
                'id'           => wo.Id,
                'number'       => wo.WorkOrderNumber,
                'status'       => wo.Status,
                'fecha'        => fecha,
                'startDateRaw' => startDateRaw,
                'technician'   => !appts.isEmpty() ? (String) appts[0].get('technician') : '',
                'territory'    => wo.ServiceTerritory != null ? wo.ServiceTerritory.Name : '',
                'subject'      => wo.Subject,
                'description'  => wo.Description,
                'priority'     => wo.Priority,
                'tipo'         => 'Prevista',
                'treatments'   => woTreatments.containsKey(wo.Id)
                                  ? String.join(woTreatments.get(wo.Id), ', ')
                                  : '',
                'appointments' => appts
            };

            if (wo.ServiceContractId != null && scMap.containsKey(wo.ServiceContractId)) {
                ((List<Map<String, Object>>) scMap.get(wo.ServiceContractId).get('workOrders')).add(woData);
            } else {
                ((List<Map<String, Object>>) sinContrato.get('workOrders')).add(woData);
            }
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>(scMap.values());
        if (!((List<Map<String, Object>>) sinContrato.get('workOrders')).isEmpty()) {
            result.add(sinContrato);
        }
        return result;
    }
}
