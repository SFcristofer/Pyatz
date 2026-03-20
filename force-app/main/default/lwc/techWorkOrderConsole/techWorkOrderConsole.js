import { LightningElement, track, api, wire } from 'lwc';
import getInitialWorkOrderData from '@salesforce/apex/TechWorkOrderController.getInitialWorkOrderData';
import saveWorkOrders from '@salesforce/apex/TechWorkOrderController.saveWorkOrders';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class TechWorkOrderConsole extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity ID
    @api quoteId;  // Quote ID específico
    @api serviceContractId; // ID del contrato formal nativo
    
    @track isLoading = true;
    @track isSaving = false;

    // IDs de respaldo para el guardado
    accountId;
    oppId;

    @track contractFolio = 'CARGANDO...';
    @track contractData = {
        cliente: '---',
        lineaNegocio: '---',
        sedes: '---',
        fechaInicio: '---',
        fechaPrimerTratamiento: '---',
        tratamientos: '---',
        fechaFin: '---',
        fechaLimiteServicios: '---'
    };

    @track sedesList = [];
    @track woNotes = '';
    @track startDate = '';
    @track endDate = '';
    @track showSchedulingSection = false;

    @track daysOfWeek = [
        { label: 'Lunes', checked: true }, { label: 'Martes', checked: true }, 
        { label: 'Miércoles', checked: true }, { label: 'Jueves', checked: true }, 
        { label: 'Viernes', checked: true }, { label: 'Sábado', checked: false }, 
        { label: 'Domingo', checked: false }
    ];

    tecnicosOptions = [
        { label: 'Técnico 1 - Juan Pérez', value: 't1' },
        { label: 'Técnico 2 - María López', value: 't2' }
    ];

    @wire(getInitialWorkOrderData, { oppId: '$recordId', quoteId: '$quoteId', serviceContractId: '$serviceContractId' })
    wiredData({ error, data }) {
        if (data) {
            // GUARDIA: Solo procesar si es un contrato nuevo o si el ID ha cambiado
            if (this.oppId === data.oppId && this.sedesList.length > 0) {
                return; 
            }

            this.contractFolio = data.folio;
            this.accountId = data.accountId;
            this.oppId = data.oppId;
            this.quoteId = data.quoteId;

            this.contractData = {
                cliente: data.cliente || 'Sin cliente',
                lineaNegocio: data.lineaNegocio || 'No definida',
                sedes: data.sedes || 'Sin sedes asignadas',
                fechaInicio: data.fechaInicio || 'N/A',
                fechaFin: data.fechaFin || 'N/A',
                fechaPrimerTratamiento: data.fechaPrimerTratamiento || 'Pendiente',
                fechaLimiteServicios: data.fechaLimiteServicios || 'Pendiente',
                tratamientos: data.tratamientos.map(t => t.name).join(', ')
            };

            this.sedesList = [{
                id: 'main-sede',
                name: data.sedes,
                startTime: '08:00:00.000',
                endTime: '18:00:00.000',
                startTime2: '',
                endTime2: '',
                tratamientos: data.tratamientos.map(t => ({
                    id: t.id,
                    name: t.name,
                    quantity: t.quantity,
                    numTecnicos: 1,
                    durationHours: 1,
                    durationMinutes: 0,
                    durationSeconds: 0,
                    zonas: t.zonas || t.description || 'Sin descripción técnica',
                    schedulingRows: this.generateSchedulingRows(t.quantity)
                }))
            }];
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false; // DETENER SPINNER EN ERROR
            console.error('Error cargando datos ODT:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error de carga',
                message: error.body ? error.body.message : 'Error desconocido al recuperar datos del contrato.',
                variant: 'error'
            }));
        }
    }

    generateSchedulingRows(quantity) {
        const rows = [];
        const baseDate = new Date();
        for (let i = 1; i <= quantity; i++) {
            const nextDate = new Date(baseDate);
            nextDate.setMonth(baseDate.getMonth() + (i - 1));
            rows.push({
                label: `${i}º Fecha`,
                date: nextDate.toISOString().split('T')[0],
                locked: false,
                duration: 60,
                executed: false,
                showNotes: false,
                notes: ''
            });
        }
        return rows;
    }

    // MANEJADORES DE INTERFAZ
    handleSedeChange(event) {
        const field = event.target.dataset.field;
        const val = event.target.value;
        this.sedesList = this.sedesList.map(s => ({ ...s, [field]: val }));
    }

    handleDayChange(event) {
        const day = event.target.dataset.day;
        const checked = event.target.checked;
        this.daysOfWeek = this.daysOfWeek.map(d => d.label === day ? { ...d, checked } : d);
    }

    handleTraConfigChange(event) {
        const field = event.target.dataset.field;
        const traId = event.target.dataset.traId;
        const val = event.target.value;
        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === traId) return { ...tra, [field]: val };
                return tra;
            })
        }));
    }

    handleRowChange(event) {
        const field = event.target.dataset.field;
        const rowIndex = event.target.dataset.rowIndex;
        const traId = event.target.dataset.traId;
        const val = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === traId) {
                    const newRows = [...tra.schedulingRows];
                    newRows[rowIndex] = { ...newRows[rowIndex], [field]: val };
                    return { ...tra, schedulingRows: newRows };
                }
                return tra;
            })
        }));
    }

    handleNoteChange(event) { this.woNotes = event.target.value; }
    handleBackToContract() { this.dispatchEvent(new CustomEvent('back')); }
    handleViewQuote() { /* Lógica para abrir PDF */ }
    handleAddCandidateDates() { this.showSchedulingSection = !this.showSchedulingSection; }
    
    toggleAccordion(event) {
        const accordionBody = event.currentTarget.nextElementSibling;
        accordionBody.style.display = accordionBody.style.display === 'none' ? 'block' : 'none';
    }

    handleGenerateODTs() {
        if (this.isSaving) return;
        this.isSaving = true;

        const payload = {
            quoteId: this.quoteId,
            oppId: this.oppId,
            accountId: this.accountId,
            folio: this.contractFolio,
            notes: this.woNotes,
            sedesList: this.sedesList,
            daysAllowed: this.daysOfWeek.filter(d => d.checked).map(d => d.label)
        };

        saveWorkOrders({ payloadJson: JSON.stringify(payload) })
            .then(woId => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Órdenes de Trabajo generadas correctamente.',
                    variant: 'success'
                }));
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: woId, objectApiName: 'WorkOrder', actionName: 'view' }
                });
                this.isSaving = false;
            })
            .catch(error => {
                this.isSaving = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }

    get remainingChars() {
        return 2048 - (this.woNotes ? this.woNotes.length : 0);
    }
}