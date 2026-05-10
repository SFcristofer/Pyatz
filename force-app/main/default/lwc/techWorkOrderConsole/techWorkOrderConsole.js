import { LightningElement, track, api, wire } from 'lwc';
import getInitialWorkOrderData from '@salesforce/apex/TechWorkOrderController.getInitialWorkOrderData';
import saveWorkOrders from '@salesforce/apex/TechWorkOrderController.saveWorkOrders';
import getServiceResources from '@salesforce/apex/TechWorkOrderController.getServiceResources';
import getRecentWorkOrders from '@salesforce/apex/TechWorkOrderController.getRecentWorkOrders';
import getWorkOrderTemplateData from '@salesforce/apex/TechWorkOrderController.getWorkOrderTemplateData';
import getServiceTerritories from '@salesforce/apex/TechWorkOrderController.getServiceTerritories';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import WORK_ORDER_OBJECT from '@salesforce/schema/WorkOrder';
import PRIORITY_FIELD from '@salesforce/schema/WorkOrder.Priority';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class TechWorkOrderConsole extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity ID
    @api quoteId;  // Quote ID específico
    @api serviceContractId; // ID del contrato formal nativo

    @track isLoading = true;
    @track isSaving = false;
    @track isUpdateMode = false;
    @track existingWorkOrderId = '';

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
        fechaLimiteServicios: '---',
        prioridad: 'Medium',
        territoryId: '0HhV9000000EWODKA4',
        direccionSede: '',
        contactoPerson: ''
    };

    @track sedesList = [];
    @track showSchedulingSection = true; 

    @track daysOfWeek = [
        { label: 'Lunes', checked: true }, { label: 'Martes', checked: true }, 
        { label: 'Miércoles', checked: true }, { label: 'Jueves', checked: true }, 
        { label: 'Viernes', checked: true }, { label: 'Sábado', checked: false }, 
        { label: 'Domingo', checked: false }
    ];

    @track tecnicosOptions = [];
    @track priorityOptions = [];
    @track territoryOptions = [];
    @track ganttView = 'months'; // 'days', 'weeks', 'months'

    @wire(getServiceResources)
    wiredResources({ error, data }) {
        if (data) {
            this.tecnicosOptions = data.map(sr => ({ label: sr.name, value: sr.id }));
        } else if (error) {
            console.error('Error cargando recursos de servicio:', error);
        }
    }

    @wire(getServiceTerritories)
    wiredTerritories({ error, data }) {
        if (data) {
            this.territoryOptions = data;
        } else if (error) {
            console.error('Error cargando territorios:', error);
        }
    }

    @wire(getObjectInfo, { objectApiName: WORK_ORDER_OBJECT })
    workOrderInfo;

    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: PRIORITY_FIELD })
    wiredPriority({ error, data }) {
        if (data) {
            console.log('Prioridades cargadas:', data.values);
            this.priorityOptions = data.values;
        } else if (error) {
            console.error('Error cargando prioridades:', error);
        }
    }

    handlePriorityChange(event) {
        this.contractData.prioridad = event.detail.value;
    }

    handleTerritoryChange(event) {
        this.contractData.territoryId = event.detail.value;
    }

    handleGanttViewChange(event) {
        this.ganttView = event.target.value;
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

    @wire(getInitialWorkOrderData, { oppId: '$recordId', quoteId: '$quoteId', serviceContractId: '$serviceContractId' })
    wiredData({ error, data }) {
        if (data) {
            if (this.contractFolio === data.folio && this.sedesList.length > 0 && !data.isUpdateMode) {
                this.isLoading = false;
                return;
            }

            this.contractFolio = data.folio;
            this.accountId = data.accountId;
            this.oppId = data.oppId;
            this.internalQuoteId = data.quoteId;
            this.internalServiceContractId = this.serviceContractId || data.serviceContractId;
            this.isUpdateMode = data.isUpdateMode || false;
            this.existingWorkOrderId = data.existingWorkOrderId || '';
            
            this.contractData = {
                cliente: data.cliente || 'Sin cliente',
                lineaNegocio: data.lineaNegocio || 'No definida',
                sedes: data.sedes || 'Sin sedes asignadas',
                sedeSeleccionada: data.sedes ? data.sedes.split(',')[0] : 'Sede Principal',
                folioSede: data.folio ? 'S-' + data.folio : 'Pendiente',
                direccionSede: data.direccion || 'Consultar en el expediente del Cliente',
                contactoPerson: data.contacto || 'Responsable de Sede',
                prioridad: data.prioridad || 'Medium', 
                territoryId: this.contractData.territoryId,
                fechaInicio: data.fechaInicio || 'N/A',
                fechaFin: data.fechaFin || 'N/A',
                fechaPrimerTratamiento: data.fechaPrimerTratamiento || 'Pendiente',
                fechaLimiteServicios: data.fechaLimiteServicios || 'Pendiente',
                tratamientos: data.tratamientos ? data.tratamientos.map(t => t.name).join(', ') : 'Ninguno'
            };

            if (this.isUpdateMode && data.tratamientosExistentes) {
                this.sedesList = [{
                    id: 'main-sede',
                    name: data.sedes || 'Sede Principal',
                    startTime: '08:00:00.000',
                    endTime: '18:00:00.000',
                    startTime2: '',
                    endTime2: '',
                    tratamientos: data.tratamientosExistentes.map(t => ({
                        id: t.id,
                        name: t.name,
                        quantity: t.quantity || 1,
                        numTecnicos: t.tecnicosIds.length || 1,
                        durationHours: Math.floor((t.schedulingRows[0]?.duration || 60) / 60),
                        durationMinutes: (t.schedulingRows[0]?.duration || 60) % 60,
                        durationSeconds: 0,
                        zonas: t.zonas || 'Sin descripción técnica',
                        numTecnicosSeleccionados: t.tecnicosIds.length,
                        tecnicosIds: t.tecnicosIds,
                        schedulingRows: t.schedulingRows.map((row, rIdx) => ({
                            label: `${rIdx + 1}º Fecha`,
                            date: row.date || new Date().toISOString().split('T')[0],
                            startTime: row.startTime || '08:00:00.000',
                            locked: false,
                            duration: row.duration || 60,
                            arrivalMargin: row.arrivalMargin || 0,
                            tecnicoId: row.tecnicoId || '',
                            executed: false,
                            showNotes: false,
                            notes: row.notes || ''
                        }))
                    }))
                }];
            } else if (data.tratamientos && data.tratamientos.length > 0) {
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
                arrivalMargin: 0,
                tecnicoId: '',
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
                if (tra.id === traId) {
                    const updatedTra = { ...tra, [field]: val };
                    
                    if (field === 'durationHours' || field === 'durationMinutes') {
                        const totalMinutes = (parseInt(updatedTra.durationHours) || 0) * 60 + (parseInt(updatedTra.durationMinutes) || 0);
                        updatedTra.schedulingRows = updatedTra.schedulingRows.map(row => {
                            if (!row.locked) return { ...row, duration: totalMinutes };
                            return row;
                        });
                    }
                    return updatedTra;
                }
                return tra;
            })
        }));
    }

    handleSyncAllRows(event) {
        const traId = event.target.dataset.traId;
        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === traId && tra.schedulingRows.length > 1) {
                    const firstRow = tra.schedulingRows[0];
                    const updatedRows = tra.schedulingRows.map((row, idx) => {
                        if (idx === 0 || row.locked) return row;
                        return { 
                            ...row, 
                            startTime: firstRow.startTime, 
                            duration: firstRow.duration,
                            arrivalMargin: firstRow.arrivalMargin,
                            tecnicoId: firstRow.tecnicoId,
                            notes: firstRow.notes 
                        };
                    });
                    return { ...tra, schedulingRows: updatedRows };
                }
                return tra;
            })
        }));
        this.dispatchEvent(new ShowToastEvent({
            title: 'Sincronizado',
            message: 'Se han replicado los valores de la primera fecha a las demás.',
            variant: 'info'
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

    handleOpenZoneBrowser() {
        const drawer = this.template.querySelector('c-tech-zone-browser-drawer');
        if (drawer) drawer.open();
    }

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
            existingWorkOrderId: this.existingWorkOrderId,
            quoteId: this.internalQuoteId,
            serviceContractId: this.internalServiceContractId,
            oppId: this.oppId,
            accountId: this.accountId,
            folio: this.contractFolio,
            notes: '',
            priority: this.contractData.prioridad,
            territoryId: this.contractData.territoryId,
            executionAddress: this.contractData.direccionSede,
            contactPerson: this.contractData.contactoPerson,
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

    get saveButtonLabel() {
        return this.isUpdateMode ? 'ACTUALIZAR ÓRDENES DE TRABAJO' : 'GENERAR ÓRDENES DE TRABAJO';
    }

    get daysVariant() { return this.ganttView === 'days' ? 'brand' : 'neutral'; }
    get weeksVariant() { return this.ganttView === 'weeks' ? 'brand' : 'neutral'; }
    get monthsVariant() { return this.ganttView === 'months' ? 'brand' : 'neutral'; }

    getGanttRange() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        let start = new Date(today);
        let end = new Date(today);
        let units = 0;

        if (this.ganttView === 'months') {
            start = new Date(today.getFullYear(), today.getMonth(), 1);
            end = new Date(start);
            end.setMonth(start.getMonth() + 12);
            units = 12;
        } else if (this.ganttView === 'weeks') {
            const day = today.getDay();
            start.setDate(today.getDate() - day);
            end = new Date(start);
            end.setDate(start.getDate() + (7 * 24));
            units = 24;
        } else {
            start = new Date(today);
            end = new Date(start);
            end.setDate(start.getDate() + 60);
            units = 60;
        }

        return { start, end, total: end.getTime() - start.getTime(), units };
    }

    get ganttAxisLabels() {
        const { start, total, units } = this.getGanttRange();
        const result = [];
        const dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
        
        if (this.ganttView === 'months') {
            const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
            for (let i = 0; i < units; i++) {
                const d = new Date(start.getFullYear(), start.getMonth() + i, 1);
                const offsetMs = d.getTime() - start.getTime();
                result.push({ 
                    id: i, 
                    label: months[d.getMonth()], 
                    subLabel: d.getFullYear(),
                    style: `left: ${(offsetMs / total) * 100}%` 
                });
            }
        } else if (this.ganttView === 'weeks') {
            for (let i = 0; i < units; i++) {
                const d = new Date(start);
                d.setDate(start.getDate() + (i * 7));
                const offsetMs = d.getTime() - start.getTime();
                result.push({ 
                    id: i, 
                    label: `Sem ${i + 1}`, 
                    subLabel: `${d.getDate()}/${d.getMonth() + 1}`,
                    style: `left: ${(offsetMs / total) * 100}%`
                });
            }
        } else {
            for (let i = 0; i <= units; i++) {
                const d = new Date(start);
                d.setDate(start.getDate() + i);
                if (i % 2 === 0 || i === 0) { 
                    const offsetMs = d.getTime() - start.getTime();
                    result.push({ 
                        id: i, 
                        label: dayNames[d.getDay()], 
                        subLabel: d.getDate(),
                        style: `left: ${(offsetMs / total) * 100}%`
                    });
                }
            }
        }
        return result;
    }

    get todayMarkerStyle() {
        const today = new Date();
        const { start, total } = this.getGanttRange();
        const offsetMs = today.getTime() - start.getTime();
        const leftPercent = (offsetMs / total) * 100;
        return `left: ${leftPercent}%; border-left: 2px dashed #f56565; height: 100%; position: absolute; z-index: 10; top: 0;`;
    }

    get ganttItems() {
        const items = [];
        const { start, total } = this.getGanttRange();

        this.sedesList.forEach(sede => {
            sede.tratamientos.forEach(tra => {
                const techNames = (tra.tecnicosIds || []).map(id => {
                    const opt = this.tecnicosOptions.find(o => o.value === id);
                    return opt ? opt.label : '...';
                }).join(', ');

                tra.schedulingRows.forEach((row, idx) => {
                    const rowDate = new Date(row.date + 'T00:00:00');
                    const { end } = this.getGanttRange();
                    if (rowDate >= start && rowDate <= end) {
                        const offsetMs = rowDate.getTime() - start.getTime();
                        const leftPercent = (offsetMs / total) * 100;

                        const colors = ['#4299e1', '#48bb78', '#ed8936', '#9f7aea', '#f56565'];
                        const color = colors[Math.abs(tra.name.length) % colors.length];

                        items.push({
                            id: `${tra.id}-${idx}`,
                            name: tra.name,
                            techs: techNames || 'Sin asignar',
                            area: tra.zonas || 'Sede Principal',
                            dateStr: row.date,
                            timeStr: row.startTime ? row.startTime.substring(0, 5) : '--:--',
                            style: `left: ${leftPercent}%; top: ${(idx % 5) * 70}px; border-left: 4px solid ${color};`,
                            fullLabel: `${tra.name} - ${row.date} ${row.startTime}`
                        });
                    }
                });
            });
        });
        return items;
    }
}