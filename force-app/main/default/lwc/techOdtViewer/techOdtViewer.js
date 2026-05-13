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

export default class TechOdtViewer extends NavigationMixin(LightningElement) {
    @api recordId;

    @track isLoading        = true;
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
            rowClass:     'odt-row'
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
                    editStartDate:   wo.id === this.editingRowId
                                       ? (this.editRowData.startDate !== undefined ? this.editRowData.startDate : wo.startDateRaw)
                                       : '',
                    editStatusValue: wo.id === this.editingRowId
                                       ? (this.editRowData.status !== undefined ? this.editRowData.status : wo.statusRaw)
                                       : ''
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
                    hasSelected:   selectedInGroup > 0
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
        const id = e.currentTarget.dataset.id;
        let statusRaw = '', startDateRaw = '';
        for (const g of this.groups) {
            const wo = g.workOrders.find(w => w.id === id);
            if (wo) { statusRaw = wo.statusRaw; startDateRaw = wo.startDateRaw; break; }
        }
        this.editingRowId = id;
        this.editRowData  = { status: statusRaw, startDate: startDateRaw };
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
            status:       f.status    || null,
            priority:     null,
            startDate:    f.startDate || null,
            contractId:   null,
            territoryId:  null,
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
}
