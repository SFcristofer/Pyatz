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
            SELECT AccountId FROM ServiceContract WHERE Id = :contractId LIMIT 1
        ];
        if (scs.isEmpty() || scs[0].AccountId == null) {
            throw new AuraHandledException('No se encontró cuenta vinculada a este contrato.');
        }
        // Retorna el primer Quote activo relacionado a una Oportunidad de la misma cuenta
        List<Quote> quotes = [
            SELECT Id, OpportunityId
            FROM Quote
            WHERE Opportunity.AccountId = :scs[0].AccountId
            AND OpportunityId != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            throw new AuraHandledException('No se encontró oportunidad vinculada a este contrato.');
        }
        return new Map<String, String>{
            'oppId'   => quotes[0].OpportunityId,
            'quoteId' => quotes[0].Id
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

        // 2. Todas las citas de servicio por WorkOrder (solo las que no tienen padre = no son hijas de fusión)
        Map<Id, List<Map<String, Object>>> woAppointments = new Map<Id, List<Map<String, Object>>>();
        for (ServiceAppointment sa : [
            SELECT Id, AppointmentNumber, ParentRecordId, SchedStartTime, Duration, Status, Description,
                   Producto_Relacionado__c, Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode,
                   (SELECT Id, ServiceResourceId, ServiceResource.Name FROM ServiceResources)
            FROM ServiceAppointment
            WHERE ParentRecordId IN (SELECT Id FROM WorkOrder WHERE AccountId = :accountId)
              AND Cita_Padre__c = null
            ORDER BY SchedStartTime ASC
        ]) {
            if (!woAppointments.containsKey(sa.ParentRecordId)) {
                woAppointments.put(sa.ParentRecordId, new List<Map<String, Object>>());
            }
            List<Map<String, String>> techs = new List<Map<String, String>>();
            for (AssignedResource ar : sa.ServiceResources) {
                techs.add(new Map<String, String>{
                    'arId'  => ar.Id,
                    'resId' => ar.ServiceResourceId,
                    'name'  => ar.ServiceResource != null ? ar.ServiceResource.Name : ''
                });
            }
            String techName     = techs.isEmpty() ? '' : techs[0].get('name');
            String schedDate    = sa.SchedStartTime != null ? sa.SchedStartTime.format('dd/MM/yyyy HH:mm') : '';
            String schedDateRaw = sa.SchedStartTime != null ? sa.SchedStartTime.format('yyyy-MM-dd\'T\'HH:mm') : '';
            Integer durationMins = sa.Duration != null ? Integer.valueOf(sa.Duration) : 0;
            woAppointments.get(sa.ParentRecordId).add(new Map<String, Object>{
                'id'           => sa.Id,
                'number'       => sa.AppointmentNumber,
                'schedDate'    => schedDate,
                'schedDateRaw' => schedDateRaw,
                'duration'     => durationMins > 0 ? String.valueOf(durationMins) + ' min' : '—',
                'durationRaw'  => durationMins > 0 ? String.valueOf(durationMins) : '',
                'status'       => sa.Status != null ? sa.Status : '',
                'technician'   => techName,
                'technicians'  => techs,
                'notes'        => sa.Description != null ? sa.Description : '',
                'productoId'   => sa.Producto_Relacionado__c != null ? (String) sa.Producto_Relacionado__c : '',
                'treatments'   => sa.Producto_Relacionado__c != null
                                  ? (String.isNotBlank(sa.Producto_Relacionado__r?.ProductCode)
                                     ? sa.Producto_Relacionado__r.ProductCode
                                     : (sa.Producto_Relacionado__r?.Name ?? ''))
                                  : ''
            });
        }

        // 2b. Agregar tratamientos de hijas de fusión al padre
        Set<Id> parentSaIds = new Set<Id>();
        for (List<Map<String, Object>> appts : woAppointments.values()) {
            for (Map<String, Object> appt : appts) parentSaIds.add((Id) appt.get('id'));
        }
        Map<Id, List<String>> hijaTreatsByPadre = new Map<Id, List<String>>();
        for (ServiceAppointment hija : [
            SELECT Cita_Padre__c, Producto_Relacionado__r.ProductCode, Producto_Relacionado__r.Name
            FROM ServiceAppointment
            WHERE Cita_Padre__c IN :parentSaIds
              AND Producto_Relacionado__c != null
        ]) {
            if (!hijaTreatsByPadre.containsKey(hija.Cita_Padre__c)) {
                hijaTreatsByPadre.put(hija.Cita_Padre__c, new List<String>());
            }
            String code = String.isNotBlank(hija.Producto_Relacionado__r?.ProductCode)
                ? hija.Producto_Relacionado__r.ProductCode
                : (hija.Producto_Relacionado__r?.Name ?? '');
            if (String.isNotBlank(code) && !hijaTreatsByPadre.get(hija.Cita_Padre__c).contains(code)) {
                hijaTreatsByPadre.get(hija.Cita_Padre__c).add(code);
            }
        }
        // Fusionar treatments del padre con los de sus hijas
        for (List<Map<String, Object>> appts : woAppointments.values()) {
            for (Map<String, Object> appt : appts) {
                Id saId = (Id) appt.get('id');
                if (!hijaTreatsByPadre.containsKey(saId)) continue;
                Set<String> allCodes = new Set<String>();
                String own = (String) appt.get('treatments');
                if (String.isNotBlank(own)) allCodes.add(own);
                allCodes.addAll(hijaTreatsByPadre.get(saId));
                List<String> sorted = new List<String>(allCodes);
                sorted.sort();
                appt.put('treatments', String.join(sorted, ', '));
            }
        }

        // 3. Revisiones de Cita de Servicio por SA
        Set<Id> allSaIds = new Set<Id>();
        for (List<Map<String, Object>> appts : woAppointments.values()) {
            for (Map<String, Object> a : appts) allSaIds.add((Id) a.get('id'));
        }
        Map<Id, List<Map<String, Object>>> revsBySA = new Map<Id, List<Map<String, Object>>>();
        Map<Id, Map<String, Object>> revByIdOdt = new Map<Id, Map<String, Object>>();
        for (Revision_Cita_Servicio__c rev : [
            SELECT Id, Name, Numero_Revision__c, Status__c, Tipo_Reporte__c, Datos_Formulario__c, Cita_Servicio__c,
                   Plantilla_de_Formulario__c, Plantilla_de_Formulario__r.Name
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :allSaIds
            ORDER BY Cita_Servicio__c, Numero_Revision__c ASC NULLS LAST
        ]) {
            if (!revsBySA.containsKey(rev.Cita_Servicio__c)) {
                revsBySA.put(rev.Cita_Servicio__c, new List<Map<String, Object>>());
            }
            String formName = rev.Plantilla_de_Formulario__r != null ? rev.Plantilla_de_Formulario__r.Name : '';
            Map<String, Object> revMap = new Map<String, Object>{
                'id'            => rev.Id,
                'folio'         => rev.Name != null ? rev.Name : '—',
                'tipo'          => rev.Tipo_Reporte__c != null ? rev.Tipo_Reporte__c : '',
                'status'        => rev.Status__c != null ? rev.Status__c : 'En Proceso',
                'formularioId'  => rev.Plantilla_de_Formulario__c,
                'formularioName'=> formName,
                'nc'            => countNoConformidades(rev.Datos_Formulario__c),
                'fotos'         => 0
            };
            revsBySA.get(rev.Cita_Servicio__c).add(revMap);
            revByIdOdt.put(rev.Id, revMap);
        }
        fillPhotoCounts(revByIdOdt);
        for (List<Map<String, Object>> appts : woAppointments.values()) {
            for (Map<String, Object> appt : appts) {
                Id saId = (Id) appt.get('id');
                appt.put('revisiones', revsBySA.containsKey(saId) ? revsBySA.get(saId) : new List<Map<String, Object>>());
            }
        }

        // 4. Tratamientos por WorkOrder — agregar desde SA.Producto_Relacionado__c
        Map<Id, List<String>> woTreatments = new Map<Id, List<String>>();
        for (Id woId : woAppointments.keySet()) {
            for (Map<String, Object> appt : woAppointments.get(woId)) {
                String t = (String) appt.get('treatments');
                if (String.isNotBlank(t)) {
                    if (!woTreatments.containsKey(woId)) {
                        woTreatments.put(woId, new List<String>());
                    }
                    if (!woTreatments.get(woId).contains(t)) {
                        woTreatments.get(woId).add(t);
                    }
                }
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
                   ServiceContractId, ServiceTerritoryId, ServiceTerritory.Name, Priority
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
                'territoryId'  => wo.ServiceTerritoryId != null ? wo.ServiceTerritoryId : '',
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

    // ── Asignación de técnico a Cita de Servicio ─────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getServiceResources() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (ServiceResource sr : [
            SELECT Id, Name
            FROM ServiceResource
            WHERE IsActive = true
            ORDER BY Name ASC
            LIMIT 200
        ]) {
            result.add(new Map<String, String>{ 'id' => sr.Id, 'label' => sr.Name });
        }
        return result;
    }

    @AuraEnabled
    public static void addTechnicianToSA(Id saId, Id serviceResourceId) {
        List<AssignedResource> existing = [
            SELECT Id FROM AssignedResource
            WHERE ServiceAppointmentId = :saId AND ServiceResourceId = :serviceResourceId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new AssignedResource(
                ServiceAppointmentId = saId,
                ServiceResourceId    = serviceResourceId
            );
        }
    }

    @AuraEnabled
    public static void removeTechnicianFromSA(Id assignedResourceId) {
        List<AssignedResource> toDelete = [
            SELECT Id FROM AssignedResource WHERE Id = :assignedResourceId LIMIT 1
        ];
        if (!toDelete.isEmpty()) delete toDelete;
    }

    // ── Revisiones de Cita de Servicio ──────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFormularios() {
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (Form_Template__c ft : [
            SELECT Id, Name FROM Form_Template__c WHERE Activo__c = true ORDER BY Name ASC LIMIT 200
        ]) {
            result.add(new Map<String, String>{ 'id' => ft.Id, 'label' => ft.Name });
        }
        return result;
    }

    @AuraEnabled
    public static void updateRevision(Id revId, String status, String tipo, Id formularioId) {
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(Id = revId);
        if (String.isNotBlank(status))    rev.Status__c                  = status;
        if (String.isNotBlank(tipo))      rev.Tipo_Reporte__c            = tipo;
        rev.Plantilla_de_Formulario__c = formularioId;
        update rev;
        if (String.isNotBlank(status)) {
            List<Revision_Cita_Servicio__c> r = [SELECT Cita_Servicio__c FROM Revision_Cita_Servicio__c WHERE Id = :revId LIMIT 1];
            if (!r.isEmpty()) recalcSAStatus(r[0].Cita_Servicio__c);
        }
    }

    @AuraEnabled
    public static Id createRevision(Id saId) {
        Integer count = [SELECT COUNT() FROM Revision_Cita_Servicio__c WHERE Cita_Servicio__c = :saId];
        Revision_Cita_Servicio__c rev = new Revision_Cita_Servicio__c(
            Cita_Servicio__c   = saId,
            Numero_Revision__c = count + 1,
            Status__c          = 'En Proceso'
        );
        insert rev;
        return rev.Id;
    }

    @AuraEnabled
    public static void cancelRevision(Id revId) {
        update new Revision_Cita_Servicio__c(Id = revId, Status__c = 'Cancelada');
        List<Revision_Cita_Servicio__c> rev = [
            SELECT Cita_Servicio__c FROM Revision_Cita_Servicio__c WHERE Id = :revId LIMIT 1
        ];
        if (!rev.isEmpty()) recalcSAStatus(rev[0].Cita_Servicio__c);
    }

    @AuraEnabled
    public static void pauseRevision(Id revId) {
        update new Revision_Cita_Servicio__c(Id = revId, Status__c = 'Pausado');
        List<Revision_Cita_Servicio__c> rev = [
            SELECT Cita_Servicio__c FROM Revision_Cita_Servicio__c WHERE Id = :revId LIMIT 1
        ];
        if (!rev.isEmpty()) recalcSAStatus(rev[0].Cita_Servicio__c);
    }

    // ── Historial de cambios ─────────────────────────────────────────────────

    @AuraEnabled
    public static List<Map<String, Object>> getRevisionHistory(Id revId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            String soql = 'SELECT CreatedDate, CreatedBy.Name, Field, OldValue, NewValue'
                        + ' FROM Revision_Cita_Servicio__History'
                        + ' WHERE ParentId = :revId'
                        + ' ORDER BY CreatedDate DESC LIMIT 50';
            for (SObject rec : Database.query(soql)) {
                result.add(new Map<String, Object>{
                    'fecha'    => ((Datetime) rec.get('CreatedDate')).format('dd/MM/yy HH:mm'),
                    'usuario'  => ((SObject) rec.getSObject('CreatedBy')).get('Name'),
                    'campo'    => rec.get('Field'),
                    'anterior' => rec.get('OldValue'),
                    'nuevo'    => rec.get('NewValue')
                });
            }
        } catch (Exception e) {}
        return result;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getSAHistory(Id saId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            String soql = 'SELECT CreatedDate, CreatedBy.Name, Field, OldValue, NewValue'
                        + ' FROM ServiceAppointmentHistory'
                        + ' WHERE ServiceAppointmentId = :saId AND Field = \'Status\''
                        + ' ORDER BY CreatedDate DESC LIMIT 50';
            for (SObject rec : Database.query(soql)) {
                result.add(new Map<String, Object>{
                    'fecha'    => ((Datetime) rec.get('CreatedDate')).format('dd/MM/yy HH:mm'),
                    'usuario'  => ((SObject) rec.getSObject('CreatedBy')).get('Name'),
                    'campo'    => rec.get('Field'),
                    'anterior' => rec.get('OldValue'),
                    'nuevo'    => rec.get('NewValue')
                });
            }
        } catch (Exception e) {}
        return result;
    }

    // ── Detalles de Cita de Servicio (Duración + Notas) ─────────────────────

    @AuraEnabled
    public static void updateSADetails(Id saId, String duration, String notes) {
        ServiceAppointment sa = new ServiceAppointment(Id = saId);
        if (String.isNotBlank(duration)) sa.Duration = Decimal.valueOf(duration);
        sa.Description = String.isNotBlank(notes) ? notes : null;
        update sa;
    }

    // ── Fecha de Cita de Servicio ────────────────────────────────────────────

    @AuraEnabled
    public static void updateSASchedStartTime(Id saId, String schedStartTime) {
        // schedStartTime = UTC ISO string: '2026-05-19T16:00:00.000Z'
        String clean = schedStartTime.replace('Z', '').replace('T', ' ');
        if (clean.length() > 19) clean = clean.substring(0, 19);
        Datetime newTime = Datetime.valueOfGmt(clean);
        update new ServiceAppointment(Id = saId, SchedStartTime = newTime);
    }

    // ── Fusión de Citas de Servicio ───────────────────────────────────────────

    /**
     * Devuelve grupos de SAs (solo las sin padre) agrupadas por fecha de SchedStartTime.
     * Solo retorna grupos con 2+ citas (los candidatos a fusión).
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSAsForFusion(Id serviceContractId) {
        // WOs del contrato
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : [
            SELECT Id FROM WorkOrder WHERE ServiceContractId = :serviceContractId
        ]) {
            woIds.add(wo.Id);
        }
        if (woIds.isEmpty()) return new List<Map<String, Object>>();

        // SAs sin padre de esos WOs
        List<ServiceAppointment> sas = [
            SELECT Id, AppointmentNumber, SchedStartTime, Status, Revisiones__c,
                   ParentRecordId, Producto_Relacionado__c,
                   Producto_Relacionado__r.Name, Producto_Relacionado__r.ProductCode,
                   (SELECT ServiceResource.Name FROM ServiceResources LIMIT 1)
            FROM ServiceAppointment
            WHERE ParentRecordId IN :woIds
              AND Cita_Padre__c = null
              AND SchedStartTime != null
            ORDER BY SchedStartTime ASC
        ];

        // Revisiones por SA (conteo + detalle para acordeón)
        Set<Id> saIds = new Set<Id>();
        for (ServiceAppointment sa : sas) saIds.add(sa.Id);

        Map<Id, Integer> revCountBySA    = new Map<Id, Integer>();
        Map<Id, List<Map<String, Object>>> revDetailBySA = new Map<Id, List<Map<String, Object>>>();
        Map<Id, Map<String, Object>> revByIdFusion = new Map<Id, Map<String, Object>>();
        for (Revision_Cita_Servicio__c rev : [
            SELECT Id, Name, Numero_Revision__c, Status__c, Tipo_Reporte__c, Datos_Formulario__c, Cita_Servicio__c
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :saIds
            ORDER BY Cita_Servicio__c, Numero_Revision__c ASC NULLS LAST
        ]) {
            if (!revDetailBySA.containsKey(rev.Cita_Servicio__c)) {
                revDetailBySA.put(rev.Cita_Servicio__c, new List<Map<String, Object>>());
                revCountBySA.put(rev.Cita_Servicio__c, 0);
            }
            Map<String, Object> revMap = new Map<String, Object>{
                'id'     => rev.Id,
                'folio'  => rev.Name != null ? rev.Name : '—',
                'tipo'   => rev.Tipo_Reporte__c != null ? rev.Tipo_Reporte__c : '—',
                'status' => rev.Status__c != null ? rev.Status__c : '—',
                'nc'     => countNoConformidades(rev.Datos_Formulario__c),
                'fotos'  => 0
            };
            revDetailBySA.get(rev.Cita_Servicio__c).add(revMap);
            revByIdFusion.put(rev.Id, revMap);
            revCountBySA.put(rev.Cita_Servicio__c, revCountBySA.get(rev.Cita_Servicio__c) + 1);
        }
        fillPhotoCounts(revByIdFusion);

        // Agrupar por fecha (yyyy-MM-dd)
        Map<String, List<Map<String, Object>>> byDate = new Map<String, List<Map<String, Object>>>();
        for (ServiceAppointment sa : sas) {
            String dateKey = sa.SchedStartTime.format('yyyy-MM-dd');
            if (!byDate.containsKey(dateKey)) byDate.put(dateKey, new List<Map<String, Object>>());
            String techName = sa.ServiceResources.isEmpty() ? '' : sa.ServiceResources[0].ServiceResource.Name;
            byDate.get(dateKey).add(new Map<String, Object>{
                'id'          => sa.Id,
                'number'      => sa.AppointmentNumber,
                'time'        => sa.SchedStartTime.format('HH:mm'),
                'status'      => sa.Status != null ? sa.Status : '',
                'maxRevisiones' => sa.Revisiones__c != null ? Integer.valueOf(sa.Revisiones__c) : 0,
                'revCount'    => revCountBySA.containsKey(sa.Id) ? revCountBySA.get(sa.Id) : 0,
                'revisiones'  => revDetailBySA.containsKey(sa.Id) ? revDetailBySA.get(sa.Id) : new List<Map<String, Object>>(),
                'technician'  => techName,
                'treatments'  => sa.Producto_Relacionado__c != null
                                 ? (String.isNotBlank(sa.Producto_Relacionado__r?.ProductCode)
                                    ? sa.Producto_Relacionado__r.ProductCode
                                    : (sa.Producto_Relacionado__r?.Name ?? ''))
                                 : ''
            });
        }

        // Solo grupos con 2+ citas
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (String dateKey : byDate.keySet()) {
            if (byDate.get(dateKey).size() < 2) continue;
            result.add(new Map<String, Object>{
                'fecha'  => dateKey,
                'label'  => byDate.get(dateKey)[0] != null
                            ? formatDateLabel(dateKey)
                            : dateKey,
                'citas'  => byDate.get(dateKey)
            });
        }
        result.sort(new DateKeyComparator());
        return result;
    }

    /**
     * Ejecuta la fusión: re-parentea revisiones al padre, actualiza Revisiones__c,
     * marca las hijas con Cita_Padre__c y recalcula estado del padre.
     * Retorna el número de revisiones migradas.
     */
    @AuraEnabled
    public static Integer fuseServiceAppointments(Id padreId, List<Id> hijaIds) {
        if (hijaIds == null || hijaIds.isEmpty()) return 0;

        // Revisiones de las hijas
        List<Revision_Cita_Servicio__c> revisiones = [
            SELECT Id, Cita_Servicio__c
            FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c IN :hijaIds
        ];

        // Re-parentear
        for (Revision_Cita_Servicio__c r : revisiones) {
            r.Cita_Servicio__c = padreId;
        }
        if (!revisiones.isEmpty()) update revisiones;

        // Sumar Revisiones__c + heredar Producto_Relacionado__c de hijas si padre no tiene
        List<ServiceAppointment> padre = [
            SELECT Id, Revisiones__c, Producto_Relacionado__c FROM ServiceAppointment WHERE Id = :padreId LIMIT 1
        ];
        List<ServiceAppointment> hijas = [
            SELECT Id, Revisiones__c, Producto_Relacionado__c FROM ServiceAppointment WHERE Id IN :hijaIds
        ];

        Decimal totalHijas = 0;
        for (ServiceAppointment h : hijas) {
            totalHijas += h.Revisiones__c != null ? h.Revisiones__c : 0;
        }

        ServiceAppointment p = padre[0];
        p.Revisiones__c = (p.Revisiones__c != null ? p.Revisiones__c : 0) + totalHijas;

        // Si el padre no tiene producto asignado, heredar el de la primera hija que tenga
        if (p.Producto_Relacionado__c == null) {
            for (ServiceAppointment h : hijas) {
                if (h.Producto_Relacionado__c != null) {
                    p.Producto_Relacionado__c = h.Producto_Relacionado__c;
                    break;
                }
            }
        }

        update p;

        // Marcar hijas con Cita_Padre__c
        for (ServiceAppointment h : hijas) {
            h.Cita_Padre__c = padreId;
        }
        update hijas;

        // Renumerar revisiones del padre secuencialmente tras fusión
        List<Revision_Cita_Servicio__c> allRevs = [
            SELECT Id FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :padreId
            ORDER BY CreatedDate ASC
        ];
        for (Integer i = 0; i < allRevs.size(); i++) {
            allRevs[i].Numero_Revision__c = i + 1;
        }
        if (!allRevs.isEmpty()) update allRevs;

        // Recalcular status del padre
        recalcSAStatus(padreId);

        return revisiones.size();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductosForContract(Id serviceContractId) {
        List<ServiceContract> scs = [
            SELECT AccountId FROM ServiceContract WHERE Id = :serviceContractId LIMIT 1
        ];
        if (scs.isEmpty() || scs[0].AccountId == null) return new List<Map<String, String>>();
        Id accountId = scs[0].AccountId;

        Set<Id> productIds = new Set<Id>();
        Map<Id, Map<String, String>> prodMap = new Map<Id, Map<String, String>>();

        // Productos de QuoteLineItems para Quotes ligados a Oportunidades de esta cuenta
        for (QuoteLineItem qli : [
            SELECT Product2Id, Product2.Name, Product2.ProductCode
            FROM QuoteLineItem
            WHERE Quote.Opportunity.AccountId = :accountId
            AND Product2Id != null
        ]) {
            if (!productIds.contains(qli.Product2Id)) {
                productIds.add(qli.Product2Id);
                String lbl = String.isNotBlank(qli.Product2?.ProductCode)
                    ? qli.Product2.ProductCode + ' — ' + qli.Product2.Name
                    : qli.Product2?.Name ?? '';
                prodMap.put(qli.Product2Id, new Map<String, String>{ 'id' => qli.Product2Id, 'label' => lbl });
            }
        }

        // Fallback: OpportunityLineItems si no hay QuoteLineItems
        if (prodMap.isEmpty()) {
            for (OpportunityLineItem oli : [
                SELECT Product2Id, Product2.Name, Product2.ProductCode
                FROM OpportunityLineItem
                WHERE Opportunity.AccountId = :accountId
                AND Product2Id != null
            ]) {
                if (!productIds.contains(oli.Product2Id)) {
                    productIds.add(oli.Product2Id);
                    String lbl = String.isNotBlank(oli.Product2?.ProductCode)
                        ? oli.Product2.ProductCode + ' — ' + oli.Product2.Name
                        : oli.Product2?.Name ?? '';
                    prodMap.put(oli.Product2Id, new Map<String, String>{ 'id' => oli.Product2Id, 'label' => lbl });
                }
            }
        }

        List<Map<String, String>> result = new List<Map<String, String>>(prodMap.values());
        result.sort(new LabelComparator());
        return result;
    }

    @AuraEnabled
    public static void updateSAProducto(Id saId, Id productoId) {
        ServiceAppointment sa = new ServiceAppointment(Id = saId, Producto_Relacionado__c = productoId);
        update sa;
    }

    @AuraEnabled
    public static void updateSAStatus(Id saId, String status) {
        ServiceAppointment sa = new ServiceAppointment(Id = saId, Status = status);
        update sa;
    }

    // ── Helpers privados ──────────────────────────────────────────────────────

    private static void recalcSAStatus(Id saId) {
        List<ServiceAppointment> sas = [
            SELECT Id, Revisiones__c FROM ServiceAppointment WHERE Id = :saId LIMIT 1
        ];
        if (sas.isEmpty()) return;
        ServiceAppointment sa = sas[0];
        Integer total       = sa.Revisiones__c != null ? Integer.valueOf(sa.Revisiones__c) : 0;
        Integer completadas = [
            SELECT COUNT() FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :saId AND Status__c = 'Completada'
        ];
        Integer pausadas = [
            SELECT COUNT() FROM Revision_Cita_Servicio__c
            WHERE Cita_Servicio__c = :saId AND Status__c = 'Pausado'
        ];
        String newStatus;
        if (total > 0 && completadas >= total) {
            newStatus = 'Completado';
        } else if (pausadas > 0) {
            newStatus = 'Pausado';
        } else if (completadas > 0) {
            newStatus = 'En curso';
        } else {
            return;
        }
        sa.Status = newStatus;
        try { update sa; } catch (Exception e) {}
    }

    private static String formatDateLabel(String dateKey) {
        String[] parts = dateKey.split('-');
        String[] months = new String[]{ '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
                                        'jul', 'ago', 'sep', 'oct', 'nov', 'dic' };
        Integer monthIdx = Integer.valueOf(parts[1]);
        return parts[2] + ' ' + months[monthIdx] + ' ' + parts[0];
    }

    private class LabelComparator implements Comparator<Map<String, String>> {
        public Integer compare(Map<String, String> a, Map<String, String> b) {
            return (a.get('label') ?? '').compareTo(b.get('label') ?? '');
        }
    }

    private class DateKeyComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            String fa = (String) a.get('fecha');
            String fb = (String) b.get('fecha');
            return fa.compareTo(fb);
        }
    }

    private static void fillPhotoCounts(Map<Id, Map<String, Object>> revById) {
        if (revById.isEmpty()) return;
        Map<Id, Set<Id>> docsByRev = new Map<Id, Set<Id>>();
        Set<Id> allDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :revById.keySet()
        ]) {
            if (!docsByRev.containsKey(cdl.LinkedEntityId))
                docsByRev.put(cdl.LinkedEntityId, new Set<Id>());
            docsByRev.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            allDocIds.add(cdl.ContentDocumentId);
        }
        if (allDocIds.isEmpty()) return;
        Set<Id> geoFotoIds = new Set<Id>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, FileType FROM ContentVersion
            WHERE ContentDocumentId IN :allDocIds AND IsLatest = true
        ]) {
            if (cv.FileType == 'JPG' || cv.FileType == 'JPEG' || cv.FileType == 'PNG' || cv.FileType == 'HEIC' || cv.FileType == 'GIF') {
                geoFotoIds.add(cv.ContentDocumentId);
            }
        }
        for (Id revId : docsByRev.keySet()) {
            Map<String, Object> m = revById.get(revId);
            if (m == null) continue;
            Integer cnt = 0;
            List<Id> fotoIds = new List<Id>();
            for (Id docId : docsByRev.get(revId)) {
                if (geoFotoIds.contains(docId)) {
                    cnt++;
                    fotoIds.add(docId);
                }
            }
            m.put('fotos', cnt);
            m.put('fotoIds', fotoIds);
        }
    }

    private static Integer countNoConformidades(String jsonStr) {
        if (String.isBlank(jsonStr)) return 0;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
            List<Object> respuestas  = (List<Object>) root.get('respuestas');
            if (respuestas == null) return 0;
            Integer count = 0;
            for (Object obj : respuestas) {
                Map<String, Object> m = (Map<String, Object>) obj;
                if (String.isNotBlank((String) m.get('deficiencia'))) count++;
            }
            return count;
        } catch (Exception e) { return 0; }
    }
}