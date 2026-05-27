import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSAsForFusion          from '@salesforce/apex/OdtViewerController.getSAsForFusion';
import fuseServiceAppointments  from '@salesforce/apex/OdtViewerController.fuseServiceAppointments';
import getProductosForContract  from '@salesforce/apex/OdtViewerController.getProductosForContract';
import updateSAProducto         from '@salesforce/apex/OdtViewerController.updateSAProducto';
import updateSAStatus           from '@salesforce/apex/OdtViewerController.updateSAStatus';
import updateSASchedStartTime   from '@salesforce/apex/OdtViewerController.updateSASchedStartTime';
import addTechnicianToSA        from '@salesforce/apex/OdtViewerController.addTechnicianToSA';
import removeTechnicianFromSA   from '@salesforce/apex/OdtViewerController.removeTechnicianFromSA';
import getServiceResources      from '@salesforce/apex/OdtViewerController.getServiceResources';
import updateRevision           from '@salesforce/apex/OdtViewerController.updateRevision';
import getFormularios           from '@salesforce/apex/OdtViewerController.getFormularios';

const STEP_LOAD    = 'load';
const STEP_SELECT  = 'select';
const STEP_CONFIRM = 'confirm';
const STEP_DONE    = 'done';
const STEP_EMPTY   = 'empty';

export default class TechFusionWizard extends LightningElement {
    @api contractId;
    @api contractName;

    @track step           = STEP_LOAD;
    @track grupos         = [];
    @track isFusing       = false;
    @track expandedRevIds = new Set();

    @track revisionesMigradas = 0;
    @track gruposFusionados   = 0;

    // tratamiento
    @track editingTratamientoId    = null;
    @track editingTratamientoValue = '';
    @track isSavingTratamiento     = false;
    @track productosOptions        = [];
    @track loadingProductos        = false;

    // estado SA
    @track editingStatusId    = null;
    @track editingStatusValue = '';
    @track isSavingStatus     = false;

    // hora SA
    @track editingTimeId    = null;
    @track editingTimeValue = '';
    @track isSavingTime     = false;

    // técnico SA
    @track addingTechSaId    = null;
    @track newTechValue      = '';
    @track serviceResources  = [];
    @track loadingResources  = false;

    // revisión
    @track editingRevId  = null;
    @track editRevData   = {};
    @track isSavingRev   = false;
    @track formularios   = [];
    @track loadingForms  = false;

    get isLoad()    { return this.step === STEP_LOAD; }
    get isSelect()  { return this.step === STEP_SELECT; }
    get isConfirm() { return this.step === STEP_CONFIRM; }
    get isDone()    { return this.step === STEP_DONE; }
    get isEmpty()   { return this.step === STEP_EMPTY; }

    get canConfirm()    { return this.grupos.every(g => !!g.padreId); }
    get cannotConfirm() { return !this.canConfirm; }

    get saStatusOptions() {
        return [
            { value: 'Sin Estado', label: 'Sin Estado' },
            { value: 'Programada', label: 'Programada' },
            { value: 'En camino',  label: 'En camino'  },
            { value: 'En curso',   label: 'En curso'   },
            { value: 'En Sitio',   label: 'En Sitio'   },
            { value: 'Completada', label: 'Completada' },
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

    get revStatusOptions() {
        return [
            { value: 'En Proceso',  label: 'En Proceso'  },
            { value: 'Completada',  label: 'Completada'  },
            { value: 'Pausada',     label: 'Pausada'     },
            { value: 'Cancelada',   label: 'Cancelada'   }
        ];
    }

    get formularioOptions() {
        const opts = [{ value: '', label: '— Sin formulario —' }];
        this.formularios.forEach(f => opts.push({ label: f.label, value: f.id }));
        return opts;
    }

    get resourceOptions() {
        const opts = [{ label: '— Seleccionar técnico —', value: '' }];
        this.serviceResources.forEach(r => opts.push({ label: r.label, value: r.id }));
        return opts;
    }

    get gruposConSeleccion() {
        return this.grupos.map(g => ({
            ...g,
            citas: g.citas.map(c => ({
                ...c,
                isSelected:            c.id === g.padreId,
                hasRevisiones:         c.revisiones && c.revisiones.length > 0,
                revExpanded:           this.expandedRevIds.has(c.id),
                revChevronIcon:        this.expandedRevIds.has(c.id) ? 'utility:chevrondown' : 'utility:chevronright',
                // tratamiento
                isEditingTratamiento:  c.id === this.editingTratamientoId,
                editTratamientoValue:  c.id === this.editingTratamientoId ? this.editingTratamientoValue : (c.productoId || ''),
                // estado
                isEditingStatus:       c.id === this.editingStatusId,
                editStatusValue:       c.id === this.editingStatusId ? this.editingStatusValue : c.status,
                // hora
                isEditingTime:         c.id === this.editingTimeId,
                editTimeValue:         c.id === this.editingTimeId ? this.editingTimeValue : (c.schedDateRaw || ''),
                // técnico
                isAddingTech:          c.id === this.addingTechSaId,
                hasTechnicians:        (c.technicians || []).length > 0,
                // revisiones con edición
                revisiones: (c.revisiones || []).map(r => ({
                    ...r,
                    isEditing:        r.id === this.editingRevId,
                    editTipo:         r.id === this.editingRevId ? (this.editRevData.tipo        ?? r.tipo)        : r.tipo,
                    editStatus:       r.id === this.editingRevId ? (this.editRevData.status      ?? r.status)      : r.status,
                    editFormularioId: r.id === this.editingRevId ? (this.editRevData.formularioId ?? r.formularioId) : r.formularioId
                }))
            }))
        }));
    }

    get confirmRows() {
        return this.grupos.map(g => {
            const padre = g.citas.find(c => c.id === g.padreId);
            const hijas = g.citas.filter(c => c.id !== g.padreId);
            const maxRevPadre = padre ? padre.maxRevisiones : 0;
            const sumaHijas   = hijas.reduce((s, c) => s + c.maxRevisiones, 0);
            return {
                fecha:       g.label,
                padreNum:    padre ? padre.number : '',
                padreTime:   padre ? padre.time : '',
                hijas:       hijas.map(h => ({ number: h.number, time: h.time, revCount: h.revCount })),
                maxRevNuevo: maxRevPadre + sumaHijas,
                revMigradas: hijas.reduce((s, c) => s + c.revCount, 0)
            };
        });
    }

    connectedCallback() {
        this._load();
        this._loadResources();
        this._loadFormularios();
    }

    _load() {
        this.step = STEP_LOAD;
        getSAsForFusion({ serviceContractId: this.contractId })
            .then(data => {
                if (!data || data.length === 0) { this.step = STEP_EMPTY; return; }
                this.grupos = data.map(g => ({
                    ...g,
                    padreId: g.citas[0].id,
                    citas: g.citas.map(c => ({ ...c, radioClass: 'fusion-radio-opt' }))
                }));
                this.step = STEP_SELECT;
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'No se pudieron cargar las citas.', variant: 'error' }));
                this._close();
            });
    }

    _loadResources() {
        this.loadingResources = true;
        getServiceResources()
            .then(data => { this.serviceResources = data; })
            .finally(() => { this.loadingResources = false; });
    }

    _loadFormularios() {
        this.loadingForms = true;
        getFormularios()
            .then(data => { this.formularios = data; })
            .finally(() => { this.loadingForms = false; });
    }

    // ── Selección padre ──────────────────────────────────────────────────────
    handleToggleFusionRev(e) {
        const citaId = e.currentTarget.dataset.citaId;
        const next = new Set(this.expandedRevIds);
        next.has(citaId) ? next.delete(citaId) : next.add(citaId);
        this.expandedRevIds = next;
    }

    handleSelectPadre(e) {
        const fecha   = e.currentTarget.dataset.fecha;
        const padreId = e.currentTarget.dataset.id;
        this.grupos = this.grupos.map(g => g.fecha === fecha ? { ...g, padreId } : g);
    }

    // ── Navegación ───────────────────────────────────────────────────────────
    handleNext()    { this.step = STEP_CONFIRM; }
    handleBack()    { this.step = STEP_SELECT; }

    handleConfirm() {
        this.isFusing = true;
        let totalMigradas = 0, gruposDone = 0;
        const promises = this.grupos.map(g => {
            const hijaIds = g.citas.filter(c => c.id !== g.padreId).map(c => c.id);
            return fuseServiceAppointments({ padreId: g.padreId, hijaIds })
                .then(count => { totalMigradas += count; gruposDone++; });
        });
        Promise.all(promises)
            .then(() => { this.revisionesMigradas = totalMigradas; this.gruposFusionados = gruposDone; this.step = STEP_DONE; })
            .catch(err => { this.dispatchEvent(new ShowToastEvent({ title: 'Error en fusión', message: err.body?.message || 'Ocurrió un error al fusionar.', variant: 'error' })); })
            .finally(() => { this.isFusing = false; });
    }

    handleDone()  { this.dispatchEvent(new CustomEvent('fusioncomplete')); }
    handleClose() { this._close(); }
    _close()      { this.dispatchEvent(new CustomEvent('close')); }

    // ── Tratamiento ──────────────────────────────────────────────────────────
    handleEditTratamiento(e) {
        const citaId = e.currentTarget.dataset.citaId;
        let currentId = '';
        for (const g of this.grupos) {
            const c = g.citas.find(x => x.id === citaId);
            if (c) { currentId = c.productoId || ''; break; }
        }
        this.editingTratamientoId    = citaId;
        this.editingTratamientoValue = currentId;
        if (this.productosOptions.length === 0 && !this.loadingProductos) {
            this.loadingProductos = true;
            getProductosForContract({ serviceContractId: this.contractId })
                .then(data => { this.productosOptions = data.map(p => ({ value: p.id, label: p.label.split(' — ')[0] })); })
                .catch(() => { this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudieron cargar los productos.', variant: 'error' })); })
                .finally(() => { this.loadingProductos = false; });
        }
    }

    handleTratamientoChange(e)  { this.editingTratamientoValue = e.detail.value; }
    handleCancelTratamiento()   { this.editingTratamientoId = null; this.editingTratamientoValue = ''; }

    handleSaveTratamiento(e) {
        const citaId = e.currentTarget.dataset.citaId;
        const newId  = this.editingTratamientoValue || null;
        this.isSavingTratamiento = true;
        updateSAProducto({ saId: citaId, productoId: newId })
            .then(() => {
                const label = newId ? (this.productosOptions.find(p => p.value === newId)?.label || '') : '';
                this._updateCita(citaId, { productoId: newId || '', treatments: label });
                this.editingTratamientoId = null; this.editingTratamientoValue = '';
                this._toast('Tratamiento actualizado.');
            })
            .catch(err => { this._toastError(err); })
            .finally(() => { this.isSavingTratamiento = false; });
    }

    // ── Estado SA ────────────────────────────────────────────────────────────
    handleEditStatus(e) {
        const citaId = e.currentTarget.dataset.citaId;
        let current = '';
        for (const g of this.grupos) { const c = g.citas.find(x => x.id === citaId); if (c) { current = c.status || ''; break; } }
        this.editingStatusId    = citaId;
        this.editingStatusValue = current;
    }

    handleStatusChange(e)  { this.editingStatusValue = e.detail.value; }
    handleCancelStatus()   { this.editingStatusId = null; this.editingStatusValue = ''; }

    handleSaveStatus(e) {
        const citaId = e.currentTarget.dataset.citaId;
        this.isSavingStatus = true;
        updateSAStatus({ saId: citaId, status: this.editingStatusValue })
            .then(() => {
                this._updateCita(citaId, { status: this.editingStatusValue });
                this.editingStatusId = null; this.editingStatusValue = '';
                this._toast('Estado actualizado.');
            })
            .catch(err => { this._toastError(err); })
            .finally(() => { this.isSavingStatus = false; });
    }

    // ── Hora SA ──────────────────────────────────────────────────────────────
    handleEditTime(e) {
        const citaId = e.currentTarget.dataset.citaId;
        let current = '';
        for (const g of this.grupos) { const c = g.citas.find(x => x.id === citaId); if (c) { current = c.schedDateRaw || ''; break; } }
        this.editingTimeId    = citaId;
        this.editingTimeValue = current;
    }

    handleTimeChange(e)  { this.editingTimeValue = e.target.value; }
    handleCancelTime()   { this.editingTimeId = null; this.editingTimeValue = ''; }

    handleSaveTime(e) {
        const citaId = e.currentTarget.dataset.citaId;
        this.isSavingTime = true;
        updateSASchedStartTime({ saId: citaId, schedStartTime: this.editingTimeValue })
            .then(() => {
                const dt = new Date(this.editingTimeValue);
                const timeStr = dt.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
                this._updateCita(citaId, { schedDateRaw: this.editingTimeValue, time: timeStr });
                this.editingTimeId = null; this.editingTimeValue = '';
                this._toast('Hora actualizada.');
            })
            .catch(err => { this._toastError(err); })
            .finally(() => { this.isSavingTime = false; });
    }

    // ── Técnico SA ───────────────────────────────────────────────────────────
    handleStartAddTech(e) {
        this.addingTechSaId = e.currentTarget.dataset.citaId;
        this.newTechValue   = '';
    }

    handleNewTechChange(e) { this.newTechValue = e.detail.value; }
    handleCancelAddTech()  { this.addingTechSaId = null; this.newTechValue = ''; }

    handleAddTech(e) {
        const citaId = e.currentTarget.dataset.citaId;
        if (!this.newTechValue) return;
        addTechnicianToSA({ saId: citaId, serviceResourceId: this.newTechValue })
            .then(arId => {
                const res = this.serviceResources.find(r => r.id === this.newTechValue);
                const newTech = { arId, resId: this.newTechValue, name: res?.label || '' };
                for (const g of this.grupos) {
                    const c = g.citas.find(x => x.id === citaId);
                    if (c) { c.technicians = [...(c.technicians || []), newTech]; c.technician = c.technicians[0]?.name || ''; break; }
                }
                this.grupos = [...this.grupos];
                this.addingTechSaId = null; this.newTechValue = '';
                this._toast('Técnico asignado.');
            })
            .catch(err => { this._toastError(err); });
    }

    handleRemoveTech(e) {
        const arId   = e.currentTarget.dataset.arId;
        const citaId = e.currentTarget.dataset.citaId;
        removeTechnicianFromSA({ assignedResourceId: arId })
            .then(() => {
                for (const g of this.grupos) {
                    const c = g.citas.find(x => x.id === citaId);
                    if (c) { c.technicians = (c.technicians || []).filter(t => t.arId !== arId); c.technician = c.technicians[0]?.name || ''; break; }
                }
                this.grupos = [...this.grupos];
                this._toast('Técnico removido.');
            })
            .catch(err => { this._toastError(err); });
    }

    // ── Revisión inline ──────────────────────────────────────────────────────
    handleEditRev(e) {
        const revId = e.currentTarget.dataset.revId;
        let rev;
        outer: for (const g of this.grupos) for (const c of g.citas) { rev = (c.revisiones || []).find(r => r.id === revId); if (rev) break outer; }
        this.editingRevId = revId;
        this.editRevData  = { tipo: rev?.tipo || '', status: rev?.status || '', formularioId: rev?.formularioId || '' };
    }

    handleRevTipoChange(e)       { this.editRevData = { ...this.editRevData, tipo: e.detail.value }; }
    handleRevStatusChange(e)     { this.editRevData = { ...this.editRevData, status: e.detail.value }; }
    handleRevFormularioChange(e) { this.editRevData = { ...this.editRevData, formularioId: e.detail.value }; }
    handleCancelRevEdit()        { this.editingRevId = null; this.editRevData = {}; }

    handleSaveRev(e) {
        const revId = e.currentTarget.dataset.revId;
        this.isSavingRev = true;
        updateRevision({ revId, status: this.editRevData.status, tipo: this.editRevData.tipo, formularioId: this.editRevData.formularioId || null })
            .then(() => {
                const formName = this.formularios.find(f => f.id === this.editRevData.formularioId)?.label || '';
                this._updateRev(revId, { ...this.editRevData, formularioName: formName });
                this.editingRevId = null; this.editRevData = {};
                this._toast('Revisión actualizada.');
            })
            .catch(err => { this._toastError(err); })
            .finally(() => { this.isSavingRev = false; });
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    _updateCita(citaId, patch) {
        this.grupos = this.grupos.map(g => ({
            ...g,
            citas: g.citas.map(c => c.id === citaId ? { ...c, ...patch } : c)
        }));
    }

    _updateRev(revId, patch) {
        this.grupos = this.grupos.map(g => ({
            ...g,
            citas: g.citas.map(c => ({
                ...c,
                revisiones: (c.revisiones || []).map(r => r.id === revId ? { ...r, ...patch } : r)
            }))
        }));
    }

    _toast(message)    { this.dispatchEvent(new ShowToastEvent({ title: 'Guardado', message, variant: 'success' })); }
    _toastError(err)   { this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body?.message || 'Error al guardar.', variant: 'error' })); }
}
