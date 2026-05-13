import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getControlPointsWithVisits from '@salesforce/apex/FloorPlanController.getControlPointsWithVisits';
import logVisit from '@salesforce/apex/FloorPlanController.logVisit';

const TYPE_LABELS = {
    'Trap': 'Trampa',
    'Bait Station': 'Estación de Cebo',
    'Sensor': 'Sensor',
    'Inspection Area': 'Área de Inspección',
    'Other': 'Otro'
};

const STATUS_LABELS = {
    'Active': 'Activo',
    'Triggered': 'Activado',
    'Inactive': 'Inactivo'
};

const STATUS_PILL_STYLES = {
    'Active':    'background:#dcfce7;color:#166534',
    'Triggered': 'background:#fee2e2;color:#991b1b',
    'Inactive':  'background:#f3f4f6;color:#6b7280'
};

const RESULT_LABELS = {
    'No Activity': 'Sin Actividad',
    'Capture':     'Captura',
    'Consumption': 'Consumo',
    'Incident':    'Incidente',
    'Maintenance': 'Mantenimiento'
};

const RESULT_COLORS = {
    'No Activity': '#9ca3af',
    'Capture':     '#ef4444',
    'Consumption': '#f97316',
    'Incident':    '#eab308',
    'Maintenance': '#3b82f6'
};

export default class FloorPlanSidebar extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track activeSections = [];

    // Estado local del formulario por punto (keyed by point Id)
    _formState = {};
    _wiredResult;
    _rawWrappers = [];

    @wire(getControlPointsWithVisits, { floorPlanId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        if (result.data) {
            this._rawWrappers = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.isLoading = false;
        }
    }

    get controlPointItems() {
        return this._rawWrappers.map(w => {
            const p = w.point;
            const fs = this._formState[p.Id] || {};
            const visits = (w.visits || []).map(v => ({
                ...v,
                resultLabel: RESULT_LABELS[v.Result__c] || v.Result__c,
                dateLabel: v.VisitDate__c
                    ? new Date(v.VisitDate__c).toLocaleDateString('es-MX', { day:'2-digit', month:'short', year:'numeric' })
                    : '',
                dotStyle: `background:${RESULT_COLORS[v.Result__c] || '#9ca3af'}`
            }));

            return {
                id: p.Id,
                point: p,
                visits,
                hasVisits: visits.length > 0,
                accordionLabel: p.Name,
                typeLabel: TYPE_LABELS[p.PointType__c] || p.PointType__c,
                statusLabel: STATUS_LABELS[p.Status__c] || p.Status__c,
                statusPillStyle: STATUS_PILL_STYLES[p.Status__c] || '',
                lastVisitLabel: p.LastVisitDate__c
                    ? new Date(p.LastVisitDate__c).toLocaleDateString('es-MX', { day:'2-digit', month:'short', year:'numeric' })
                    : 'Sin visitas',
                showForm: !!fs.showForm,
                formResult: fs.result || 'No Activity',
                formQuantity: fs.quantity || null,
                formObservations: fs.observations || '',
                isSaving: !!fs.isSaving,
                formError: fs.error || null
            };
        });
    }

    get hasPoints() {
        return this._rawWrappers.length > 0;
    }

    get countActive() {
        return this._rawWrappers.filter(w => w.point.Status__c === 'Active').length;
    }
    get countTriggered() {
        return this._rawWrappers.filter(w => w.point.Status__c === 'Triggered').length;
    }
    get countInactive() {
        return this._rawWrappers.filter(w => w.point.Status__c === 'Inactive').length;
    }

    get resultOptions() {
        return [
            { label: 'Sin Actividad', value: 'No Activity' },
            { label: 'Captura',       value: 'Capture' },
            { label: 'Consumo',       value: 'Consumption' },
            { label: 'Incidente',     value: 'Incident' },
            { label: 'Mantenimiento', value: 'Maintenance' }
        ];
    }

    _setFormState(pointId, patch) {
        const current = this._formState[pointId] || {};
        this._formState = { ...this._formState, [pointId]: { ...current, ...patch } };
    }

    handleShowForm(event) {
        const id = event.currentTarget.dataset.id;
        this._setFormState(id, { showForm: true, result: 'No Activity', quantity: null, observations: '', error: null });
    }

    handleHideForm(event) {
        const id = event.currentTarget.dataset.id;
        this._setFormState(id, { showForm: false, error: null });
    }

    handleFormResultChange(event) {
        const id = event.currentTarget.dataset.id;
        this._setFormState(id, { result: event.detail.value });
    }

    handleFormQuantityChange(event) {
        const id = event.currentTarget.dataset.id;
        this._setFormState(id, { quantity: parseFloat(event.detail.value) || null });
    }

    handleFormObservationsChange(event) {
        const id = event.currentTarget.dataset.id;
        this._setFormState(id, { observations: event.detail.value });
    }

    async handleSaveVisit(event) {
        const id = event.currentTarget.dataset.id;
        const fs = this._formState[id] || {};

        if (!fs.result) {
            this._setFormState(id, { error: 'El resultado es requerido.' });
            return;
        }

        this._setFormState(id, { isSaving: true, error: null });

        try {
            await logVisit({
                controlPointId: id,
                result: fs.result,
                quantity: fs.quantity,
                observations: fs.observations
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Visita registrada.',
                variant: 'success'
            }));

            this._setFormState(id, { showForm: false, isSaving: false });
            await refreshApex(this._wiredResult);

        } catch (err) {
            this._setFormState(id, {
                isSaving: false,
                error: err.body?.message || 'Error al guardar visita.'
            });
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).finally(() => {
            this.isLoading = false;
        });
    }
}