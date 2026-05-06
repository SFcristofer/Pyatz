import { LightningElement, track, api, wire } from 'lwc';
import getInitialWorkOrderData from '@salesforce/apex/TechWorkOrderController.getInitialWorkOrderData';
import saveWorkOrders from '@salesforce/apex/TechWorkOrderController.saveWorkOrders';
import getServiceResources from '@salesforce/apex/TechWorkOrderController.getServiceResources';
import getRecentWorkOrders from '@salesforce/apex/TechWorkOrderController.getRecentWorkOrders';
import getWorkOrderTemplateData from '@salesforce/apex/TechWorkOrderController.getWorkOrderTemplateData';
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
    internalQuoteId;
    internalServiceContractId;

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
    @track showSchedulingSection = true; 

    @track daysOfWeek = [
        { label: 'Lunes', checked: true }, { label: 'Martes', checked: true }, 
        { label: 'Miércoles', checked: true }, { label: 'Jueves', checked: true }, 
        { label: 'Viernes', checked: true }, { label: 'Sábado', checked: false }, 
        { label: 'Domingo', checked: false }
    ];

    @track tecnicosOptions = [];
    @track recentWorkOrders = [];
    @track selectedTemplateId = '';
    @track templateStatus = ''; // Feedback visual

    @wire(getServiceResources)
    wiredResources({ error, data }) {
        if (data) {
            this.tecnicosOptions = data.map(sr => ({ label: sr.name, value: sr.id }));
        } else if (error) {
            console.error('Error cargando recursos de servicio:', error);
        }
    }

    // Transformamos las opciones de técnicos para que cada tratamiento sepa cuáles están seleccionados
    get treatmentsWithTechOptions() {
        return this.sedesList.flatMap(sede => 
            sede.tratamientos.map(tra => {
                const options = this.tecnicosOptions.map(opt => ({
                    ...opt,
                    selected: tra.tecnicosIds ? tra.tecnicosIds.includes(opt.value) : false
                }));
                return { ...tra, options };
            })
        );
    }

    @wire(getRecentWorkOrders, { accountId: '$accountId' })
    wiredRecentWOs({ error, data }) {
        if (data) {
            this.recentWorkOrders = data.map(wo => ({ label: wo.name, value: wo.id }));
        }
    }

    @wire(getInitialWorkOrderData, { oppId: '$recordId', quoteId: '$quoteId', serviceContractId: '$serviceContractId' })
    wiredData({ error, data }) {
        if (data) {
            if (this.contractFolio === data.folio && this.sedesList.length > 0) {
                this.isLoading = false;
                return;
            }

            this.contractFolio = data.folio;
            this.accountId = data.accountId;
            this.oppId = data.oppId;
            this.internalQuoteId = data.quoteId;
            this.internalServiceContractId = this.serviceContractId || data.serviceContractId;

            this.contractData = {
                cliente: data.cliente || 'Sin cliente',
                lineaNegocio: data.lineaNegocio || 'No definida',
                sedes: data.sedes || 'Sin sedes asignadas',
                sedeSeleccionada: data.sedes ? data.sedes.split(',')[0] : 'Sede Principal',
                folioSede: data.folio ? 'S-' + data.folio : 'Pendiente',
                direccionSede: data.direccion || 'Consultar en el expediente del Cliente',
                contactoPerson: data.contacto || 'Responsable de Sede',
                prioridad: 'Media', 
                fechaInicio: data.fechaInicio || 'N/A',
                fechaFin: data.fechaFin || 'N/A',
                fechaPrimerTratamiento: data.fechaPrimerTratamiento || 'Pendiente',
                fechaLimiteServicios: data.fechaLimiteServicios || 'Pendiente',
                tratamientos: data.tratamientos ? data.tratamientos.map(t => t.name).join(', ') : 'Ninguno'
            };

            if (data.tratamientos && data.tratamientos.length > 0) {
                this.sedesList = [{
                    id: 'main-sede',
                    name: data.sedes || 'Sede Principal',
                    startTime: '08:00:00.000',
                    endTime: '18:00:00.000',
                    startTime2: '',
                    endTime2: '',
                    tratamientos: data.tratamientos.map(t => ({
                        id: t.id,
                        name: t.name,
                        quantity: t.quantity || 1,
                        numTecnicos: 1,
                        durationHours: 1,
                        durationMinutes: 0,
                        durationSeconds: 0,
                        zonas: t.zonas || t.description || 'Sin descripción técnica',
                        numTecnicosSeleccionados: 0,
                        tecnicosIds: [],
                        schedulingRows: this.generateSchedulingRows(t.quantity || 1)
                    }))
                }];
            }
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            console.error('Error cargando datos ODT:', error);
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
                startTime: '08:00:00.000',
                locked: false,
                duration: 60,
                executed: false,
                showNotes: false,
                notes: ''
            });
        }
        return rows;
    }

    // CLONACIÓN / PLANTILLA
    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    handleLoadTemplate() {
        if (!this.selectedTemplateId) return;
        this.isLoading = true;
        
        // Buscar el nombre de la ODT seleccionada para el status
        const selectedWO = this.recentWorkOrders.find(wo => wo.value === this.selectedTemplateId);
        const woName = selectedWO ? selectedWO.label.split(' - ')[0] : 'ODT';

        getWorkOrderTemplateData({ workOrderId: this.selectedTemplateId })
            .then(data => {
                this.woNotes = data.notes;
                this.templateStatus = `Configuración cargada desde: ${woName}`;

                // Mapear tratamientos de la plantilla a la sedesList actual
                // Solo mapeamos si el nombre coincide para seguridad
                this.sedesList = this.sedesList.map(sede => {
                    const updatedTratamientos = sede.tratamientos.map(tra => {
                        const templateTra = data.tratamientos.find(t => t.name === tra.name);
                        if (templateTra) {
                            return {
                                ...tra,
                                numTecnicos: templateTra.tecnicosIds.length || 1,
                                tecnicosIds: templateTra.tecnicosIds,
                                numTecnicosSeleccionados: templateTra.tecnicosIds.length,
                                durationHours: Math.floor((templateTra.schedulingRows[0]?.duration || 60) / 60),
                                durationMinutes: (templateTra.schedulingRows[0]?.duration || 60) % 60,
                                // Regenerar filas pero con la duración de la plantilla
                                schedulingRows: tra.schedulingRows.map(row => ({
                                    ...row,
                                    duration: templateTra.schedulingRows[0]?.duration || 60
                                }))
                            };
                        }
                        return tra;
                    });
                    return { ...sede, tratamientos: updatedTratamientos };
                });

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Configuración cargada desde ODT anterior.',
                    variant: 'success'
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error cargando plantilla:', error);
            });
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

    handleTecnicoChange(event) {
        const traId = event.target.dataset.traId;
        const selectedOptions = Array.from(event.target.selectedOptions).map(option => option.value);

        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === traId) {
                    return { 
                        ...tra, 
                        tecnicosIds: selectedOptions,
                        numTecnicosSeleccionados: selectedOptions.length 
                    };
                }
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
            quoteId: this.internalQuoteId,
            serviceContractId: this.internalServiceContractId,
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