import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord, deleteRecord } from 'lightning/uiRecordApi';
import { getRecord } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import getRecentVisits from '@salesforce/apex/FloorPlanController.getRecentVisits';
import logVisit from '@salesforce/apex/FloorPlanController.logVisit';
import deleteControlPoint from '@salesforce/apex/FloorPlanController.deleteControlPoint';
import userId from '@salesforce/user/Id';

const CP_FIELDS = [
    'ControlPoint__c.Id',
    'ControlPoint__c.Name',
    'ControlPoint__c.XPercent__c',
    'ControlPoint__c.YPercent__c',
    'ControlPoint__c.PointType__c',
    'ControlPoint__c.Status__c',
    'ControlPoint__c.Notes__c',
    'ControlPoint__c.LastVisitDate__c'
];

const RESULT_LABELS = {
    'No Activity': 'Sin Actividad',
    'Capture': 'Captura',
    'Consumption': 'Consumo',
    'Incident': 'Incidente',
    'Maintenance': 'Mantenimiento'
};

const RESULT_COLORS = {
    'No Activity': '#9ca3af',
    'Capture': '#ef4444',
    'Consumption': '#f97316',
    'Incident': '#eab308',
    'Maintenance': '#3b82f6'
};

const POINT_TYPE_LABELS = {
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

const STATUS_BADGE_COLORS = {
    'Active': 'background:#22c55e;color:white',
    'Triggered': 'background:#ef4444;color:white',
    'Inactive': 'background:#9ca3af;color:white'
};

export default class ControlPointModal extends LightningElement {
    @api mode = 'create';
    @api floorPlanId;
    @api xPercent = 0;
    @api yPercent = 0;
    @api controlPointId = null;

    @track controlPointData = {};
    @track recentVisits = [];
    @track showVisitForm = false;
    @track isSaving = false;
    @track errorMessage = null;

    // Crear
    @track newPointType = 'Trap';
    @track newStatus = 'Active';
    @track newNotes = '';

    // Visita
    @track visitResult = 'No Activity';
    @track visitQuantity = null;
    @track visitObservations = '';

    @wire(getRecord, { recordId: '$controlPointId', fields: CP_FIELDS })
    wiredPoint({ data, error }) {
        if (data) {
            this.controlPointData = {
                Id: data.id,
                Name: data.fields.Name.value,
                XPercent__c: data.fields.XPercent__c.value,
                YPercent__c: data.fields.YPercent__c.value,
                PointType__c: data.fields.PointType__c.value,
                Status__c: data.fields.Status__c.value,
                Notes__c: data.fields.Notes__c.value,
                LastVisitDate__c: data.fields.LastVisitDate__c.value
            };
        } else if (error) {
            this.errorMessage = 'Error al cargar datos del punto.';
        }
    }

    @wire(getRecentVisits, { controlPointId: '$controlPointId' })
    wiredVisits({ data, error }) {
        if (data) {
            this.recentVisits = data.map(v => ({
                ...v,
                formattedDate: v.VisitDate__c ? new Date(v.VisitDate__c).toLocaleString('es-MX') : '',
                resultLabel: RESULT_LABELS[v.Result__c] || v.Result__c,
                resultDotStyle: `background:${RESULT_COLORS[v.Result__c] || '#9ca3af'};width:12px;height:12px;border-radius:50%;margin-top:4px`
            }));
        } else if (error) {
            this.errorMessage = 'Error al cargar historial de visitas.';
        }
    }

    get isCreateMode() { return this.mode === 'create'; }
    get isViewMode() { return this.mode === 'view'; }

    get modalTitle() {
        if (this.isCreateMode) return 'Nuevo Punto de Control';
        if (this.showVisitForm) return 'Registrar Visita';
        return this.controlPointData.Name || 'Punto de Control';
    }

    get modalSubtitle() {
        if (this.isCreateMode) return `Posición: X ${this.xPercent}% / Y ${this.yPercent}%`;
        return this.pointTypeLabel;
    }

    get pointTypeLabel() {
        return POINT_TYPE_LABELS[this.controlPointData.PointType__c] || this.controlPointData.PointType__c || '';
    }

    get pointStatusLabel() {
        return STATUS_LABELS[this.controlPointData.Status__c] || this.controlPointData.Status__c || '';
    }

    get statusBadgeStyle() {
        return STATUS_BADGE_COLORS[this.controlPointData.Status__c] || '';
    }

    get lastVisitFormatted() {
        if (!this.controlPointData.LastVisitDate__c) return 'Sin visitas';
        return new Date(this.controlPointData.LastVisitDate__c).toLocaleDateString('es-MX');
    }

    get hasVisits() { return this.recentVisits.length > 0; }

    get canDelete() {
        return true;
    }

    get pointTypeOptions() {
        return [
            { label: 'Trampa', value: 'Trap' },
            { label: 'Estación de Cebo', value: 'Bait Station' },
            { label: 'Sensor', value: 'Sensor' },
            { label: 'Área de Inspección', value: 'Inspection Area' },
            { label: 'Otro', value: 'Other' }
        ];
    }

    get statusOptions() {
        return [
            { label: 'Activo', value: 'Active' },
            { label: 'Activado', value: 'Triggered' },
            { label: 'Inactivo', value: 'Inactive' }
        ];
    }

    get resultOptions() {
        return [
            { label: 'Sin Actividad', value: 'No Activity' },
            { label: 'Captura', value: 'Capture' },
            { label: 'Consumo', value: 'Consumption' },
            { label: 'Incidente', value: 'Incident' },
            { label: 'Mantenimiento', value: 'Maintenance' }
        ];
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handlePointTypeChange(e) { this.newPointType = e.detail.value; }
    handleStatusChange(e) { this.newStatus = e.detail.value; }
    handleNotesChange(e) { this.newNotes = e.detail.value; }
    handleVisitResultChange(e) { this.visitResult = e.detail.value; }
    handleVisitQuantityChange(e) { this.visitQuantity = parseFloat(e.detail.value) || null; }
    handleVisitObservationsChange(e) { this.visitObservations = e.detail.value; }

    async handleSavePoint() {
        if (!this.newPointType) {
            this.errorMessage = 'El tipo de punto es requerido.';
            return;
        }
        this.isSaving = true;
        this.errorMessage = null;
        try {
            const fields = {
                FloorPlan__c: this.floorPlanId,
                XPercent__c: this.xPercent,
                YPercent__c: this.yPercent,
                PointType__c: this.newPointType,
                Status__c: this.newStatus,
                Notes__c: this.newNotes
            };
            await createRecord({ apiName: 'ControlPoint__c', fields });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Punto de control creado.',
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('pointsaved'));
        } catch (err) {
            this.errorMessage = err.body?.message || 'Error al crear punto.';
        } finally {
            this.isSaving = false;
        }
    }

    handleShowVisitForm() { this.showVisitForm = true; }
    handleHideVisitForm() { this.showVisitForm = false; }

    async handleSaveVisit() {
        if (!this.visitResult) {
            this.errorMessage = 'El resultado es requerido.';
            return;
        }
        this.isSaving = true;
        this.errorMessage = null;
        try {
            await logVisit({
                controlPointId: this.controlPointId,
                result: this.visitResult,
                quantity: this.visitQuantity,
                observations: this.visitObservations
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Visita registrada correctamente.',
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('pointsaved'));
        } catch (err) {
            this.errorMessage = err.body?.message || 'Error al registrar visita.';
        } finally {
            this.isSaving = false;
        }
    }

    async handleDeletePoint() {
        if (!confirm('¿Eliminar este punto de control y todas sus visitas?')) return;
        this.isSaving = true;
        this.errorMessage = null;
        try {
            await deleteControlPoint({ controlPointId: this.controlPointId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Eliminado',
                message: 'Punto de control eliminado.',
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('pointsaved'));
        } catch (err) {
            this.errorMessage = err.body?.message || 'Error al eliminar punto.';
        } finally {
            this.isSaving = false;
        }
    }
}