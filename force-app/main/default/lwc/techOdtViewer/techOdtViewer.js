import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOdtsByAccount from '@salesforce/apex/OdtViewerController.getOdtsByAccount';
import getContractsForAccount from '@salesforce/apex/OdtViewerController.getContractsForAccount';
import getOppAndQuoteFromContract from '@salesforce/apex/OdtViewerController.getOppAndQuoteFromContract';
import getServiceTerritoriesForAccount from '@salesforce/apex/OdtViewerController.getServiceTerritoriesForAccount';
import assignWorkOrdersToContract from '@salesforce/apex/OdtViewerController.assignWorkOrdersToContract';
import bulkUpdateWorkOrders from '@salesforce/apex/OdtViewerController.bulkUpdateWorkOrders';
import getServiceResources from '@salesforce/apex/OdtViewerController.getServiceResources';
import getFormularios from '@salesforce/apex/OdtViewerController.getFormularios';
import updateRevision from '@salesforce/apex/OdtViewerController.updateRevision';
import addTechnicianToSA from '@salesforce/apex/OdtViewerController.addTechnicianToSA';
import removeTechnicianFromSA from '@salesforce/apex/OdtViewerController.removeTechnicianFromSA';
import createRevision from '@salesforce/apex/OdtViewerController.createRevision';
import cancelRevision from '@salesforce/apex/OdtViewerController.cancelRevision';
import pauseRevision from '@salesforce/apex/OdtViewerController.pauseRevision';
import getRevisionHistory from '@salesforce/apex/OdtViewerController.getRevisionHistory';
import getSAHistory from '@salesforce/apex/OdtViewerController.getSAHistory';
import updateSASchedStartTime from '@salesforce/apex/OdtViewerController.updateSASchedStartTime';
import updateSADetails from '@salesforce/apex/OdtViewerController.updateSADetails';
import updateSAStatus from '@salesforce/apex/OdtViewerController.updateSAStatus';
import getProductosForContract from '@salesforce/apex/OdtViewerController.getProductosForContract';
import updateSAProducto from '@salesforce/apex/OdtViewerController.updateSAProducto';

const STATUS_MAP = {
    'Completed'       : { label: 'Verificada',         css: 'status-badge badge-green'  },
    'Closed'          : { label: 'Cerrada',             css: 'status-badge badge-gray'   },
    'In Progress'     : { label: 'En Ejecución',        css: 'status-badge badge-blue'   },
    'Dispatched'      : { label: 'Enviada',             css: 'status-badge badge-blue'   },
    'On Site'         : { label: 'En Sitio',            css: 'status-badge badge-blue'   },
    'New'             : { label: 'Pendiente Ejecución', css: 'status-badge badge-orange' },
    'Scheduled'       : { label: 'Programada',          css: 'status-badge badge-orange' },
    'Cannot Complete' : { label: 'No Completada',       css: 'status-badge badge-red'    },
    'Canceled'        : { label: 'Cancelada',           css: 'status-badge badge-red'    }
};

const PENDING_STATUSES = new Set(['New', 'Scheduled', 'In Progress', 'Dispatched', 'On Site']);

const SC_STATUS_CSS = {
    'Activated' : 'sc-badge badge-sc-green',
    'Draft'     : 'sc-badge badge-sc-gray',
    'Expired'   : 'sc-badge badge-sc-red',
    'Cancelled' : 'sc-badge badge-sc-red'
};

const REV_STATUS_MAP = {
    'En Proceso' : 'rev-status-tag rev-inprogress',
    'Completada' : 'rev-status-tag rev-completed',
    'Pausado'    : 'rev-status-tag rev-paused',
    'Cancelada'  : 'rev-status-tag rev-cancelled'
};

export default class TechOdtViewer extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading        = true;
    @track isRefreshing     = false;
    @track hasError         = false;
    @track groups           = [];
    @track selectedIds      = new Set();
    @track expandedIds      = new Set();
    @track expandedRowIds   = new Set();
    @track editingRowId     = null;
    @track editRowData      = {};
    @track isSavingInline   = false;

    @track showWithOdts     = true;
    @track showWithoutOdts  = true;

    // Asignación a contrato
    @track showAssignModal    = false;
    @track isLoadingContracts = false;
    @track isAssigning        = false;
    @track availableContracts = [];
    @track selectedContractId = '';
    @track pendingAssignIds   = [];

    // Modal techWorkOrderConsole
    @track showContractModal    = false;
    @track isResolvingOpp       = false;
    @track contractModalOppId   = null;
    @track contractModalQuoteId = null;
    @track contractModalScId    = null;

    // Técnico(s) inline en SA — multi-tech pills
    @track addingTechSaId       = null;
    @track newTechValue         = '';
    @track isSavingAddTech      = false;
    @track isSavingRemoveTech   = false;
    @track serviceResources     = [];

    // Revisiones CRUD + inline edit
    @track isCreatingRev        = false;
    @track isSavingRevAction    = false;
    @track editingRevId         = null;
    @track editRevData          = {};
    @track isSavingRev          = false;
    @track formularios          = [];

    // Historial
    @track revHistoryMap        = {};
    @track saHistoryMap         = {};
    @track loadingHistRevIds    = new Set();
    @track loadingHistSaIds     = new Set();
    @track expandedRevHistIds   = new Set();
    @track expandedSaHistIds    = new Set();

    // Producto inline en SA
    @track editingSaProductoSaId   = null;
    @track editingSaProductoValue  = '';
    @track isSavingSaProducto      = false;
    @track productosCache          = {};   // { [contractId]: [{value, label}] }
    @track loadingProductosFor     = null; // saId que disparó la carga

    // Estado inline en SA
    @track editingSaStatusId    = null;
    @track editingSaStatusValue = '';
    @track isSavingSaStatus     = false;

    // Fecha inline en SA
    @track editingSaDateId      = null;
    @track editingSaDateValue   = '';
    @track isSavingSaDate       = false;

    // Acordeón revisiones por SA
    @track expandedSaRevIds         = new Set();

    // Duración y Notas inline en SA
    @track editingSaDetailsId       = null;
    @track editingSaDetailsDuration = '';
    @track editingSaDetailsNotes    = '';
    @track isSavingSaDetails        = false;

    // Fusión de citas
    @track showFusionWizard     = false;
    @track fusionContractId     = null;
    @track fusionContractName   = '';

    // Edición masiva
    @track showBulkEditModal    = false;
    @track isSavingBulk         = false;
    @track isLoadingTerritories = false;
    @track availableTerritories = [];
    bulkFields = { status: '', priority: '', startDate: '', contractId: '', territoryId: '', description: '' };

    // Filtros
    @track filterContract = '';
    @track filterDateFrom = '';
    @track filterDateTo   = '';
    @track filterStatus   = '';

    get revStatusOptions() {
        return [
            { value: 'En Proceso', label: 'En Proceso' },
            { value: 'Completada', label: 'Completada' },
            { value: 'Pausado',    label: 'Pausado'    },
            { value: 'Cancelada',  label: 'Cancelada'  }
        ];
    }

    get revTipoOptions() {
        return [
            { value: '', label: '— Sin tipo —' },
            ...['Bioenzmático','Limpieza de Trampa','Recolección de Grasa','Íntima','Desazolve',
                'Ductos','Aplicación de retardante','PLOM','Aromatizante','Bacter','Filtros',
                'Limpieza','Control de Plaga','Instalación','Elcla','Entrega']
            .map(v => ({ value: v, label: v }))
        ];
    }

    get formularioOptions() {
        const opts = [{ value: '', label: '— Sin formulario —' }];
        this.formularios.forEach(f => opts.push({ label: f.label, value: f.id }));
        return opts;
    }

    get saResourceOptions() {
        const opts = [{ label: '— Seleccionar técnico —', value: '' }];
        this.serviceResources.forEach(r => opts.push({ label: r.label, value: r.id }));
        return opts;
    }

    _getProductoOptions(contractId) {
        const cached = this.productosCache[contractId];
        if (!cached) return [];
        return [{ value: '', label: '— Sin producto —' }, ...cached];
    }

    get territoryOptions() {
        const opts = [{ value: '', label: '— Sin territorio —' }];
        this.availableTerritories.forEach(t => opts.push({ value: t.id, label: t.label }));
        return opts;
    }

    get saStatusOptions() {
        return [
            { value: 'Sin Estado',  label: 'Sin Estado'  },
            { value: 'Programada',  label: 'Programada'  },
            { value: 'En camino',   label: 'En camino'   },
            { value: 'En curso',    label: 'En curso'    },
            { value: 'En Sitio',    label: 'En Sitio'    },
            { value: 'Completada',  label: 'Completada'  },
            { value: 'Cancelada',   label: 'Cancelada'   }
        ];
    }

    get statusOptions() {
        return [
            { value: 'New',             label: 'Pendiente Ejecución' },
            { value: 'Scheduled',       label: 'Programada'          },
            { value: 'Dispatched',      label: 'Enviada'             },
            { value: 'In Progress',     label: 'En Ejecución'        },
            { value: 'On Site',         label: 'En Sitio'            },
            { value: 'Completed',       label: 'Verificada'          },
            { value: 'Cannot Complete', label: 'No Completada'       },
            { value: 'Closed',          label: 'Cerrada'             },
            { value: 'Canceled',        label: 'Cancelada'           }
        ];
    }

    _wiredResult;
    @wire(getOdtsByAccount, { accountId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.groups = data.map(g => {
                const wos = (g.workOrders || []).map(wo => this._mapWo(wo));
                return {
                    ...g,
                    workOrders: wos,
                    woCount: wos.length,
                    displayName: g.number !== '—' ? `Contrato ${g.number} — ${g.name}` : g.name,
                    statusClass: SC_STATUS_CSS[g.status] || 'sc-badge badge-sc-gray'
                };
            });
            this.expandedIds = new Set(this.groups.map(g => g.id));
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            console.error('OdtViewer error:', error);
        }
    }

    _mapWo(wo) {
        const info = STATUS_MAP[wo.status] || { label: wo.status, css: 'status-badge badge-gray' };
        const isPending = PENDING_STATUSES.has(wo.status);
        return {
            ...wo,
            appointments: wo.appointments || [],
            statusRaw:    wo.status,
            statusLabel:  info.label,
            status:       info.label,
            statusClass:  info.css,
            isPending,
            selected:     false,
            rowClass:     'odt-row',
            woUrl:        `/lightning/r/WorkOrder/${wo.id}/view`
        };
    }

    // ── Filtrado client-side ──────────────────────────────────────────────
    _filterWos(wos) {
        return wos.filter(wo => {
            if (this.filterStatus === 'pending'   && !wo.isPending)  return false;
            if (this.filterStatus === 'completed' &&  wo.isPending)  return false;
            if (this.filterDateFrom && wo.startDateRaw && wo.startDateRaw < this.filterDateFrom) return false;
            if (this.filterDateTo   && wo.startDateRaw && wo.startDateRaw > this.filterDateTo)   return false;
            return true;
        });
    }

    get visibleGroups() {
        return this.groups
            .filter(g => {
                if (this.filterContract && g.id !== this.filterContract) return false;
                return true;
            })
            .map(g => {
                const filtered = this._filterWos(g.workOrders).map(wo => ({
                    ...wo,
                    selected:        this.selectedIds.has(wo.id),
                    rowExpanded:     this.expandedRowIds.has(wo.id),
                    hasAppointments: wo.appointments.length > 0,
                    saChevronIcon:   this.expandedRowIds.has(wo.id) ? 'utility:chevrondown' : 'utility:chevronright',
                    isEditing:       wo.id === this.editingRowId,
                    editStartDate:    wo.id === this.editingRowId
                                        ? (this.editRowData.startDate   !== undefined ? this.editRowData.startDate   : wo.startDateRaw)
                                        : '',
                    editStatusValue:  wo.id === this.editingRowId
                                        ? (this.editRowData.status      !== undefined ? this.editRowData.status      : wo.statusRaw)
                                        : '',
                    editTerritoryId:  wo.id === this.editingRowId
                                        ? (this.editRowData.territoryId !== undefined ? this.editRowData.territoryId : (wo.territoryId || ''))
                                        : '',
                    appointments: wo.appointments.map(sa => {
                        const revs = (sa.revisiones || []).map(r => {
                            const isEditing = r.id === this.editingRevId;
                            return {
                                ...r,
                                statusClass:       REV_STATUS_MAP[r.status] || 'rev-status-tag rev-inprogress',
                                formularioLabel:   r.formularioName || '—',
                                canPause:          r.status === 'En Proceso',
                                canCancel:         r.status !== 'Cancelada',
                                revHistExpanded:   this.expandedRevHistIds.has(r.id),
                                revHistLoading:    this.loadingHistRevIds.has(r.id),
                                revHistory:        this.revHistoryMap[r.id] || [],
                                hasRevHistory:     (this.revHistoryMap[r.id] || []).length > 0,
                                isEditing,
                                editStatus:       isEditing ? (this.editRevData.status        ?? r.status)       : r.status,
                                editTipo:         isEditing ? (this.editRevData.tipo           ?? r.tipo)         : r.tipo,
                                editFormularioId: isEditing ? (this.editRevData.formularioId   ?? r.formularioId) : r.formularioId
                            };
                        });
                        const techs = (sa.technicians || []);
                        const isEditingProducto = sa.id === this.editingSaProductoSaId;
                        return {
                            ...sa,
                            saUrl:              `/lightning/r/ServiceAppointment/${sa.id}/view`,
                            contractId:         g.id,
                            isAddingTech:       sa.id === this.addingTechSaId,
                            newTechVal:         sa.id === this.addingTechSaId ? this.newTechValue : '',
                            hasTechnicians:     techs.length > 0,
                            technicians:        techs,
                            isEditingStatus:    sa.id === this.editingSaStatusId,
                            editSaStatusValue:  sa.id === this.editingSaStatusId ? this.editingSaStatusValue : sa.status,
                            isEditingProducto,
                            editProductoValue:  isEditingProducto ? this.editingSaProductoValue : (sa.productoId || ''),
                            productoLabel:      sa.treatments || '—',
                            productoOptions:    this._getProductoOptions(g.id),
                            loadingProductos:   this.loadingProductosFor === sa.id,
                            isEditingDate:      sa.id === this.editingSaDateId,
                            editDateValue:      sa.id === this.editingSaDateId ? this.editingSaDateValue : (sa.schedDateRaw || ''),
                            hasRevisiones:      revs.length > 0,
                            revExpanded:        this.expandedSaRevIds.has(sa.id),
                            revChevronIcon:     this.expandedSaRevIds.has(sa.id) ? 'utility:chevrondown' : 'utility:chevronright',
                            revCount:           revs.length,
                            tiposCount:         new Set(revs.map(r => r.tipo).filter(t => t && t !== '—')).size,
                            revisiones:         revs,
                            isEditingDetails:   sa.id === this.editingSaDetailsId,
                            editDuration:       sa.id === this.editingSaDetailsId ? this.editingSaDetailsDuration : (sa.durationRaw || ''),
                            editNotes:          sa.id === this.editingSaDetailsId ? this.editingSaDetailsNotes    : (sa.notes || ''),
                            saHistExpanded:     this.expandedSaHistIds.has(sa.id),
                            saHistLoading:      this.loadingHistSaIds.has(sa.id),
                            saHistory:          this.saHistoryMap[sa.id] || [],
                            hasSaHistory:       (this.saHistoryMap[sa.id] || []).length > 0
                        };
                    })
                }));
                const selectedInGroup = filtered.filter(wo => wo.selected).length;
                const expanded = this.expandedIds.has(g.id);

                if (!expanded) {
                    if (!g.woCount && !this.showWithoutOdts) return null;
                    if ( g.woCount && !this.showWithOdts)    return null;
                }

                return {
                    ...g,
                    filteredWorkOrders:    filtered,
                    filteredCount:         filtered.length,
                    hasFilteredWorkOrders: filtered.length > 0,
                    hasWorkOrders:         g.woCount > 0,
                    expanded,
                    chevronIcon:   expanded ? 'utility:chevrondown' : 'utility:chevronright',
                    selectedCount: selectedInGroup,
                    hasSelected:   selectedInGroup > 0,
                    hasContractId: g.id !== 'sin-contrato'
                };
            })
            .filter(g => {
                if (!g) return false;
                if (!g.hasWorkOrders && !this.showWithoutOdts) return false;
                if ( g.hasWorkOrders && !this.showWithOdts)    return false;
                return true;
            });
    }

    get contractOptions() {
        return this.groups.map(g => ({ value: g.id, label: g.displayName }));
    }

    get totalWorkOrders() {
        return this.groups.reduce((s, g) => s + g.woCount, 0);
    }

    get selectedCount() { return this.selectedIds.size; }
    get hasSelected()   { return this.selectedIds.size > 0; }
    get isEmpty()       { return !this.isLoading && this.groups.length === 0; }

    // ── Handlers filtros ─────────────────────────────────────────────────
    handleContractFilter(e) { this.filterContract = e.target.value; }
    handleDateFromChange(e) { this.filterDateFrom = e.target.value; }
    handleDateToChange(e)   { this.filterDateTo   = e.target.value; }
    handleStatusFilter(e)   { this.filterStatus   = e.target.value; }

    handleClearSelection() { this.selectedIds = new Set(); }

    handleRefresh() {
        this.isRefreshing = true;
        refreshApex(this._wiredResult).finally(() => { this.isRefreshing = false; });
    }

    handleClearFilters() {
        this.filterContract = '';
        this.filterDateFrom = '';
        this.filterDateTo   = '';
        this.filterStatus   = '';
        this.template.querySelectorAll('select').forEach(s => s.value = '');
        this.template.querySelectorAll('input[type="date"]').forEach(i => i.value = '');
    }

    handleToggleWithOdts(e)    { this.showWithOdts    = e.target.checked; }
    handleToggleWithoutOdts(e) { this.showWithoutOdts = e.target.checked; }

    // ── Handlers grupos ──────────────────────────────────────────────────
    handleToggleGroup(e) {
        const id = e.currentTarget.dataset.id;
        const next = new Set(this.expandedIds);
        next.has(id) ? next.delete(id) : next.add(id);
        this.expandedIds = next;
    }

    // ── Checkboxes ───────────────────────────────────────────────────────
    handleSelectRow(e) {
        const id = e.target.dataset.id;
        const next = new Set(this.selectedIds);
        e.target.checked ? next.add(id) : next.delete(id);
        this.selectedIds = next;
    }

    handleSelectAllInGroup(e) {
        const groupId = e.target.dataset.groupId;
        const checked = e.target.checked;
        const group   = this.groups.find(g => g.id === groupId);
        if (!group) return;
        const next = new Set(this.selectedIds);
        this._filterWos(group.workOrders).forEach(wo => {
            checked ? next.add(wo.id) : next.delete(wo.id);
        });
        this.selectedIds = next;
    }

    // ── Navegación ───────────────────────────────────────────────────────
    handleViewWorkOrder(e) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: e.currentTarget.dataset.id, objectApiName: 'WorkOrder', actionName: 'view' }
        });
    }

    // ── SA accordion ─────────────────────────────────────────────────────
    handleToggleRowExpand(e) {
        const id = e.currentTarget.dataset.id;
        const next = new Set(this.expandedRowIds);
        next.has(id) ? next.delete(id) : next.add(id);
        this.expandedRowIds = next;
    }

    // ── Inline edit ──────────────────────────────────────────────────────
    handleOpenInlineEdit(e) {
        this._loadTerritories();
        const id = e.currentTarget.dataset.id;
        let statusRaw = '', startDateRaw = '', territoryId = '';
        for (const g of this.groups) {
            const wo = g.workOrders.find(w => w.id === id);
            if (wo) { statusRaw = wo.statusRaw; startDateRaw = wo.startDateRaw; territoryId = wo.territoryId || ''; break; }
        }
        this.editingRowId = id;
        this.editRowData  = { status: statusRaw, startDate: startDateRaw, territoryId };
    }

    handleCancelInlineEdit() {
        this.editingRowId = null;
        this.editRowData  = {};
    }

    handleInlineFieldChange(e) {
        const field = e.target.dataset.field;
        const value = e.detail?.value !== undefined ? e.detail.value : e.target.value;
        this.editRowData = { ...this.editRowData, [field]: value };
    }

    handleSaveInlineEdit(e) {
        const id = e.currentTarget.dataset.id;
        const f  = this.editRowData;
        this.isSavingInline = true;
        bulkUpdateWorkOrders({
            workOrderIds: [id],
            status:       f.status      || null,
            priority:     null,
            startDate:    f.startDate   || null,
            contractId:   null,
            territoryId:  f.territoryId || null,
            description:  null
        })
        .then(() => {
            this.isSavingInline = false;
            this.editingRowId   = null;
            this.editRowData    = {};
            this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: 'ODT actualizada.', variant: 'success' }));
            return refreshApex(this._wiredResult);
        })
        .catch(err => {
            this.isSavingInline = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
        });
    }

    // ── Bulk edit ────────────────────────────────────────────────────────
    handleOpenBulkEdit() {
        this.bulkFields = { status: '', priority: '', startDate: '', contractId: '', territoryId: '', description: '' };
        this.showBulkEditModal = true;
        this._loadContracts();
        this._loadTerritories();
    }

    handleCloseBulkEdit() { this.showBulkEditModal = false; }

    handleBulkFieldChange(e) {
        const field = e.target.dataset.field;
        this.bulkFields = { ...this.bulkFields, [field]: e.target.value };
    }

    handleConfirmBulkEdit() {
        const ids = [...this.selectedIds];
        if (!ids.length) return;
        const f = this.bulkFields;
        const hasChange = f.status || f.priority || f.startDate || f.contractId || f.territoryId || f.description;
        if (!hasChange) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Sin cambios', message: 'Modifica al menos un campo.', variant: 'warning' }));
            return;
        }
        this.isSavingBulk = true;
        bulkUpdateWorkOrders({
            workOrderIds: ids,
            status:       f.status      || null,
            priority:     f.priority    || null,
            startDate:    f.startDate   || null,
            contractId:   f.contractId  || null,
            territoryId:  f.territoryId || null,
            description:  f.description || null
        })
        .then(() => {
            this.isSavingBulk = false;
            this.showBulkEditModal = false;
            this.selectedIds = new Set();
            this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: `${ids.length} ODT actualizadas.`, variant: 'success' }));
            return refreshApex(this._wiredResult);
        })
        .catch(err => {
            this.isSavingBulk = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
        });
    }

    handleOpenAssignFromBulk() {
        this.pendingAssignIds = [...this.selectedIds];
        this._loadContractsAndOpenModal();
    }

    _loadContracts() {
        if (this.availableContracts.length) return;
        this.isLoadingContracts = true;
        getContractsForAccount({ accountId: this.recordId })
            .then(data => { this.availableContracts = data; this.isLoadingContracts = false; })
            .catch(() => { this.isLoadingContracts = false; });
    }

    _loadTerritories() {
        if (this.availableTerritories.length) return;
        this.isLoadingTerritories = true;
        getServiceTerritoriesForAccount()
            .then(data => { this.availableTerritories = data; this.isLoadingTerritories = false; })
            .catch(() => { this.isLoadingTerritories = false; });
    }

    handleReorganizar(e) {
        const contractId = e.currentTarget.dataset.contractId;
        if (contractId === 'sin-contrato') {
            const group    = this.groups.find(g => g.id === 'sin-contrato');
            const selected = group ? group.workOrders.filter(wo => this.selectedIds.has(wo.id)) : [];
            if (selected.length === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sin selección',
                    message: 'Selecciona las ODTs que deseas asignar a un contrato.',
                    variant: 'warning'
                }));
                return;
            }
            this.pendingAssignIds = selected.map(wo => wo.id);
            this._loadContractsAndOpenModal();
            return;
        }
        this.contractModalOppId = null;
        this.contractModalScId  = contractId;
        this.isResolvingOpp     = true;
        this.showContractModal  = true;
        getOppAndQuoteFromContract({ contractId })
            .then(result => {
                this.contractModalOppId   = result.oppId;
                this.contractModalQuoteId = result.quoteId;
                this.isResolvingOpp       = false;
            })
            .catch(err => {
                this.isResolvingOpp    = false;
                this.showContractModal = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sin oportunidad vinculada',
                    message: err.body?.message || 'Este contrato no tiene oportunidad asociada.',
                    variant: 'warning'
                }));
            });
    }

    handleCloseContractModal() {
        this.showContractModal    = false;
        this.contractModalOppId   = null;
        this.contractModalQuoteId = null;
        this.contractModalScId    = null;
        refreshApex(this._wiredResult);
    }

    _loadContractsAndOpenModal() {
        this.showAssignModal    = true;
        this.selectedContractId = '';
        this._loadContracts();
    }

    get pendingAssignCount() { return this.pendingAssignIds.length; }

    handleContractSelect(e) { this.selectedContractId = e.target.value; }

    handleCloseAssignModal() {
        this.showAssignModal    = false;
        this.pendingAssignIds   = [];
        this.selectedContractId = '';
    }

    handleConfirmAssign() {
        if (!this.selectedContractId) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Requerido', message: 'Selecciona un contrato.', variant: 'warning' }));
            return;
        }
        this.isAssigning = true;
        assignWorkOrdersToContract({ workOrderIds: this.pendingAssignIds, contractId: this.selectedContractId })
            .then(() => {
                this.isAssigning        = false;
                this.showAssignModal    = false;
                this.selectedIds        = new Set();
                this.pendingAssignIds   = [];
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Asignadas',
                    message: 'ODTs vinculadas al contrato.',
                    variant: 'success'
                }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.isAssigning = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: err.body?.message || 'No se pudo realizar la asignación.',
                    variant: 'error'
                }));
            });
    }

    // ── Técnicos (multi) inline en SA ───────────────────────────────────────
    handleShowAddTech(e) {
        const saId = e.currentTarget.dataset.saId;
        this.addingTechSaId = saId;
        this.newTechValue   = '';
        if (!this.serviceResources.length) {
            getServiceResources()
                .then(data => { this.serviceResources = data; })
                .catch(() => {});
        }
    }

    handleCancelAddTech() {
        this.addingTechSaId = null;
        this.newTechValue   = '';
    }

    handleNewTechChange(e) {
        this.newTechValue = e.detail.value;
    }

    handleConfirmAddTech(e) {
        const saId  = e.currentTarget.dataset.saId;
        const resId = this.newTechValue;
        if (!resId) return;
        this.isSavingAddTech = true;
        addTechnicianToSA({ saId, serviceResourceId: resId })
            .then(() => {
                this.addingTechSaId  = null;
                this.newTechValue    = '';
                this.dispatchEvent(new ShowToastEvent({ title: 'Técnico asignado', message: 'Técnico añadido a la cita.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'No se pudo asignar el técnico.', variant: 'error' }));
            })
            .finally(() => { this.isSavingAddTech = false; });
    }

    handleRemoveTech(e) {
        const arId = e.currentTarget.dataset.arId;
        this.isSavingRemoveTech = true;
        removeTechnicianFromSA({ assignedResourceId: arId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Técnico removido', message: 'Técnico retirado de la cita.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'No se pudo remover el técnico.', variant: 'error' }));
            })
            .finally(() => { this.isSavingRemoveTech = false; });
    }

    // ── Revisiones CRUD ──────────────────────────────────────────────────────
    handleCreateRevision(e) {
        const saId = e.currentTarget.dataset.saId;
        this.isCreatingRev = true;
        createRevision({ saId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Revisión creada', message: 'Nueva revisión agregada.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'No se pudo crear la revisión.', variant: 'error' }));
            })
            .finally(() => { this.isCreatingRev = false; });
    }

    handlePauseRevision(e) {
        const revId = e.currentTarget.dataset.revId;
        this.isSavingRevAction = true;
        pauseRevision({ revId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Pausada', message: 'Revisión pausada.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al pausar.', variant: 'error' }));
            })
            .finally(() => { this.isSavingRevAction = false; });
    }

    handleCancelRevision(e) {
        const revId = e.currentTarget.dataset.revId;
        this.isSavingRevAction = true;
        cancelRevision({ revId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Cancelada', message: 'Revisión cancelada.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al cancelar.', variant: 'error' }));
            })
            .finally(() => { this.isSavingRevAction = false; });
    }

    // ── Inline edit de revisión ──────────────────────────────────────────────
    handleEditRev(e) {
        const revId = e.currentTarget.dataset.revId;
        let rev;
        outer: for (const g of this.groups) {
            for (const wo of g.workOrders) {
                for (const sa of wo.appointments) {
                    rev = (sa.revisiones || []).find(r => r.id === revId);
                    if (rev) break outer;
                }
            }
        }
        this.editingRevId = revId;
        this.editRevData  = {
            status:      rev ? rev.status      : 'En Proceso',
            tipo:        rev ? rev.tipo        : '',
            formularioId: rev ? rev.formularioId : null
        };
        if (!this.formularios.length) {
            getFormularios()
                .then(data => { this.formularios = data; })
                .catch(() => {});
        }
    }

    handleCancelEditRev() {
        this.editingRevId = null;
        this.editRevData  = {};
    }

    handleRevFieldChange(e) {
        const field = e.target.dataset.field;
        const value = e.detail?.value !== undefined ? e.detail.value : e.target.value;
        this.editRevData = { ...this.editRevData, [field]: value || null };
    }

    handleSaveRev(e) {
        const revId = e.currentTarget.dataset.revId;
        const d     = this.editRevData;
        this.isSavingRev = true;
        updateRevision({
            revId,
            status:      d.status      || null,
            tipo:        d.tipo        || null,
            formularioId: d.formularioId || null
        })
        .then(() => {
            this.editingRevId = null;
            this.editRevData  = {};
            this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: 'Revisión actualizada.', variant: 'success' }));
            return refreshApex(this._wiredResult);
        })
        .catch(err => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
        })
        .finally(() => { this.isSavingRev = false; });
    }

    // ── Historial ────────────────────────────────────────────────────────────
    handleToggleRevHistory(e) {
        const revId = e.currentTarget.dataset.revId;
        const next  = new Set(this.expandedRevHistIds);
        if (next.has(revId)) { next.delete(revId); this.expandedRevHistIds = next; return; }
        next.add(revId);
        this.expandedRevHistIds = next;
        if (!this.revHistoryMap[revId]) {
            const loading = new Set(this.loadingHistRevIds);
            loading.add(revId);
            this.loadingHistRevIds = loading;
            getRevisionHistory({ revId })
                .then(data => {
                    this.revHistoryMap = { ...this.revHistoryMap, [revId]: data };
                    const l2 = new Set(this.loadingHistRevIds);
                    l2.delete(revId);
                    this.loadingHistRevIds = l2;
                })
                .catch(() => {
                    const l2 = new Set(this.loadingHistRevIds);
                    l2.delete(revId);
                    this.loadingHistRevIds = l2;
                });
        }
    }

    handleToggleSaHistory(e) {
        const saId = e.currentTarget.dataset.saId;
        const next = new Set(this.expandedSaHistIds);
        if (next.has(saId)) { next.delete(saId); this.expandedSaHistIds = next; return; }
        next.add(saId);
        this.expandedSaHistIds = next;
        if (!this.saHistoryMap[saId]) {
            const loading = new Set(this.loadingHistSaIds);
            loading.add(saId);
            this.loadingHistSaIds = loading;
            getSAHistory({ saId })
                .then(data => {
                    this.saHistoryMap = { ...this.saHistoryMap, [saId]: data };
                    const l2 = new Set(this.loadingHistSaIds);
                    l2.delete(saId);
                    this.loadingHistSaIds = l2;
                })
                .catch(() => {
                    const l2 = new Set(this.loadingHistSaIds);
                    l2.delete(saId);
                    this.loadingHistSaIds = l2;
                });
        }
    }

    // ── Duración y Notas inline en SA ────────────────────────────────────────
    handleEditSaDetails(e) {
        const saId = e.currentTarget.dataset.saId;
        let durationRaw = '', notes = '';
        outer: for (const g of this.groups) {
            for (const wo of g.workOrders) {
                const sa = wo.appointments.find(a => a.id === saId);
                if (sa) { durationRaw = sa.durationRaw || ''; notes = sa.notes || ''; break outer; }
            }
        }
        this.editingSaDetailsId       = saId;
        this.editingSaDetailsDuration = durationRaw;
        this.editingSaDetailsNotes    = notes;
    }

    handleCancelSaDetails() {
        this.editingSaDetailsId       = null;
        this.editingSaDetailsDuration = '';
        this.editingSaDetailsNotes    = '';
    }

    handleSaDetailsChange(e) {
        const field = e.target.dataset.field;
        if (field === 'duration') this.editingSaDetailsDuration = e.target.value;
        else if (field === 'notes') this.editingSaDetailsNotes   = e.target.value;
    }

    handleSaveSaDetails(e) {
        const saId = e.currentTarget.dataset.saId;
        this.isSavingSaDetails = true;
        updateSADetails({ saId, duration: this.editingSaDetailsDuration, notes: this.editingSaDetailsNotes })
            .then(() => {
                this.editingSaDetailsId       = null;
                this.editingSaDetailsDuration = '';
                this.editingSaDetailsNotes    = '';
                this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: 'Detalles actualizados.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
            })
            .finally(() => { this.isSavingSaDetails = false; });
    }

    // ── Acordeón revisiones SA ───────────────────────────────────────────────
    handleToggleSaRevExpand(e) {
        const saId = e.currentTarget.dataset.saId;
        const next = new Set(this.expandedSaRevIds);
        next.has(saId) ? next.delete(saId) : next.add(saId);
        this.expandedSaRevIds = next;
    }

    // ── Producto inline en SA ────────────────────────────────────────────────
    handleEditSaProducto(e) {
        const saId      = e.currentTarget.dataset.saId;
        const contractId = e.currentTarget.dataset.contractId;
        // Buscar productoId actual
        let currentId = '';
        outer: for (const g of this.groups) {
            for (const wo of g.workOrders) {
                const sa = (wo.appointments || []).find(a => a.id === saId);
                if (sa) { currentId = sa.productoId || ''; break outer; }
            }
        }
        this.editingSaProductoSaId  = saId;
        this.editingSaProductoValue = currentId;
        // Cargar productos del contrato si no están en caché
        if (!this.productosCache[contractId] && contractId && contractId !== 'sin-contrato') {
            this.loadingProductosFor = saId;
            getProductosForContract({ serviceContractId: contractId })
                .then(data => {
                    this.productosCache = {
                        ...this.productosCache,
                        [contractId]: data.map(p => ({ value: p.id, label: p.label }))
                    };
                })
                .catch(() => {
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudieron cargar los productos.', variant: 'error' }));
                })
                .finally(() => { this.loadingProductosFor = null; });
        }
    }

    handleSaProductoChange(e) {
        this.editingSaProductoValue = e.detail.value;
    }

    handleCancelSaProducto() {
        this.editingSaProductoSaId  = null;
        this.editingSaProductoValue = '';
    }

    handleSaveSaProducto(e) {
        const saId = e.currentTarget.dataset.saId;
        this.isSavingSaProducto = true;
        updateSAProducto({ saId, productoId: this.editingSaProductoValue || null })
            .then(() => {
                this.editingSaProductoSaId  = null;
                this.editingSaProductoValue = '';
                this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: 'Tratamiento actualizado.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
            })
            .finally(() => { this.isSavingSaProducto = false; });
    }

    // ── Estado inline en SA ──────────────────────────────────────────────────
    handleEditSaStatus(e) {
        const saId = e.currentTarget.dataset.saId;
        let currentStatus = '';
        outer: for (const g of this.groups) {
            for (const wo of g.workOrders) {
                const sa = (wo.appointments || []).find(a => a.id === saId);
                if (sa) { currentStatus = sa.status || ''; break outer; }
            }
        }
        this.editingSaStatusId    = saId;
        this.editingSaStatusValue = currentStatus;
    }

    handleSaStatusChange(e) {
        this.editingSaStatusValue = e.detail.value;
    }

    handleCancelSaStatus() {
        this.editingSaStatusId    = null;
        this.editingSaStatusValue = '';
    }

    handleSaveSaStatus(e) {
        const saId = e.currentTarget.dataset.saId;
        if (!this.editingSaStatusValue) return;
        this.isSavingSaStatus = true;
        updateSAStatus({ saId, status: this.editingSaStatusValue })
            .then(() => {
                this.editingSaStatusId    = null;
                this.editingSaStatusValue = '';
                this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: 'Estado de cita actualizado.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
            })
            .finally(() => { this.isSavingSaStatus = false; });
    }

    // ── Fecha inline en SA ───────────────────────────────────────────────────
    handleEditSaDate(e) {
        const saId = e.currentTarget.dataset.saId;
        let rawVal = '';
        outer: for (const g of this.groups) {
            for (const wo of g.workOrders) {
                const sa = wo.appointments.find(a => a.id === saId);
                if (sa) { rawVal = sa.schedDateRaw || ''; break outer; }
            }
        }
        this.editingSaDateId    = saId;
        this.editingSaDateValue = rawVal;
    }

    handleCancelSaDate() {
        this.editingSaDateId    = null;
        this.editingSaDateValue = '';
    }

    handleSaDateChange(e) {
        this.editingSaDateValue = e.target.value;
    }

    handleSaveSaDate(e) {
        const saId = e.currentTarget.dataset.saId;
        if (!this.editingSaDateValue) return;
        const utcStr = new Date(this.editingSaDateValue).toISOString();
        this.isSavingSaDate = true;
        updateSASchedStartTime({ saId, schedStartTime: utcStr })
            .then(() => {
                this.editingSaDateId    = null;
                this.editingSaDateValue = '';
                this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message: 'Fecha actualizada.', variant: 'success' }));
                return refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' }));
            })
            .finally(() => { this.isSavingSaDate = false; });
    }

    // ── Fusión de Citas de Servicio ──────────────────────────────────────────
    handleOpenFusionWizard(e) {
        e.stopPropagation();
        this.fusionContractId   = e.currentTarget.dataset.contractId;
        this.fusionContractName = e.currentTarget.dataset.contractName;
        this.showFusionWizard   = true;
    }

    handleCloseFusionWizard() {
        this.showFusionWizard   = false;
        this.fusionContractId   = null;
        this.fusionContractName = '';
    }

    handleFusionComplete() {
        this.showFusionWizard   = false;
        this.fusionContractId   = null;
        this.fusionContractName = '';
        refreshApex(this._wiredResult);
    }
}