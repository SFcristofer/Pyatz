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
import LightningConfirm from 'lightning/confirm';

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

    get treatmentsWithTechOptions() {
        return this.sedesList.flatMap(sede => 
            sede.tratamientos.map(tra => {
                const options = this.tecnicosOptions.map(opt => ({
                    ...opt,
                    selected: tra.tecnicosIds ? tra.tecnicosIds.includes(opt.value) : false
                }));
                
                const updatedRows = (tra.schedulingRows || []).map(row => {
                    const techPills = (row.tecnicosIds || []).map(tId => {
                        const opt = this.tecnicosOptions.find(o => o.value === tId);
                        return { id: tId, label: opt ? opt.label : '...' };
                    });
                    return {
                        ...row,
                        hasTechs: techPills.length > 0,
                        techPills: techPills,
                        notesVariant: row.showNotes ? 'brand' : 'border-filled'
                    };
                });
                
                return { ...tra, options, schedulingRows: updatedRows };
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
                tratamientos: data.tratamientos ? data.tratamientos.map(t => t.name).join(', ') : 'Ninguno',
                treatmentsRaw: data.tratamientos || []
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
                        code: t.code || 'N/A',
                        quantity: t.quantity || 1,
                        numTecnicos: t.tecnicosIds ? t.tecnicosIds.length : 1,
                        duration: t.schedulingRows && t.schedulingRows[0] ? t.schedulingRows[0].duration : 60,
                        zonas: t.zonas || 'Sin descripción técnica',
                        numTecnicosSeleccionados: t.tecnicosIds ? t.tecnicosIds.length : 0,
                        tecnicosIds: t.tecnicosIds || [],
                        schedulingRows: t.schedulingRows ? t.schedulingRows.map((row, rIdx) => ({
                            label: `${rIdx + 1}º Fecha`,
                            saId: row.saId || '',
                            date: row.date || new Date().toISOString().split('T')[0],
                            startTime: row.startTime || '08:00:00.000',
                            locked: row.locked || false,
                            duration: row.duration || 60,
                            travelTime: row.travelTime || row.arrivalMargin || 0,
                            tecnicosIds: row.tecnicosIds || (row.tecnicoId ? [row.tecnicoId] : []),
                            executed: false,
                            showNotes: false,
                            notes: row.notes || ''
                        })) : this.generateSchedulingRows(t.quantity || 1)
                    }))
                }];
            }
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            console.error('Error cargando datos ODT:', error);
        }
    }

    getNextValidDate(dateObj) {
        const allowedDays = [];
        const dayMap = { 'Domingo': 0, 'Lunes': 1, 'Martes': 2, 'Miércoles': 3, 'Jueves': 4, 'Viernes': 5, 'Sábado': 6 };
        this.daysOfWeek.forEach(d => {
            if (d.checked) allowedDays.push(dayMap[d.label]);
        });
        
        if (allowedDays.length === 0) allowedDays.push(1, 2, 3, 4, 5);

        let testDate = new Date(dateObj);
        let safetyCounter = 0;
        while (!allowedDays.includes(testDate.getDay()) && safetyCounter < 10) {
            testDate.setDate(testDate.getDate() + 1);
            safetyCounter++;
        }
        return testDate;
    }

    generateSchedulingRows(quantity, baseDateParam = null) {
        const rows = [];
        let baseDate = baseDateParam ? new Date(baseDateParam + 'T00:00:00') : new Date();
        baseDate = this.getNextValidDate(baseDate);

        for (let i = 1; i <= quantity; i++) {
            let nextDate = new Date(baseDate);
            nextDate.setMonth(baseDate.getMonth() + (i - 1));
            nextDate = this.getNextValidDate(nextDate);

            rows.push({
                label: `${i}º Fecha`,
                saId: '',
                date: nextDate.toISOString().split('T')[0],
                startTime: '08:00:00.000',
                locked: false,
                duration: 60,
                travelTime: 0,
                tecnicosIds: [],
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
                    
                    if (field === 'duration') {
                        const totalMinutes = parseInt(val) || 0;
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
                    const newDates = this.generateSchedulingRows(tra.schedulingRows.length, firstRow.date);

                    const updatedRows = tra.schedulingRows.map((row, idx) => {
                        if (idx === 0 || row.locked) return row;
                        return { 
                            ...row, 
                            date: newDates[idx].date,
                            startTime: firstRow.startTime, 
                            duration: firstRow.duration,
                            travelTime: firstRow.travelTime,
                            tecnicosIds: firstRow.tecnicosIds,
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
            message: 'Se han replicado los valores y ajustado las fechas a días hábiles.',
            variant: 'info'
        }));
    }

    handleTecnicoChange(event) {
        const traId = event.target.dataset.traId || event.currentTarget.dataset.traId;
        let selectedOptions = [];
        
        if (event.detail && Array.isArray(event.detail.value)) {
            selectedOptions = event.detail.value;
        } else if (event.target.selectedOptions) {
            selectedOptions = Array.from(event.target.selectedOptions).map(option => option.value);
        }

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
        const field = event.target.dataset.field || event.currentTarget.dataset.field;
        const rowIndex = event.target.dataset.rowIndex || event.currentTarget.dataset.rowIndex;
        const traId = event.target.dataset.traId || event.currentTarget.dataset.traId;
        
        let val;
        let isToggle = false;
        if (event.target.type === 'checkbox') {
            val = event.target.checked;
        } else if (event.currentTarget.tagName === 'LIGHTNING-BUTTON-ICON' || event.currentTarget.tagName === 'LIGHTNING-BUTTON') {
            isToggle = true;
        } else {
            val = event.target.value;
        }

        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === traId) {
                    const newRows = [...tra.schedulingRows];
                    if (isToggle) {
                        newRows[rowIndex] = { ...newRows[rowIndex], [field]: !newRows[rowIndex][field] };
                    } else {
                        newRows[rowIndex] = { ...newRows[rowIndex], [field]: val };
                    }
                    return { ...tra, schedulingRows: newRows };
                }
                return tra;
            })
        }));
    }

    // Modal Methods for Technicians Picker
    @track isTechModalOpen = false;
    currentModalTraId = null;
    currentModalRowIndex = null;
    @track currentModalTechs = [];
    @track currentModalLogistica = {};

    get selectedModalTechsData() {
        return this.currentModalTechs.map(techId => {
            const opt = this.tecnicosOptions.find(o => o.value === techId);
            const log = this.currentModalLogistica[techId] || { ida: 0, espera: 0, regreso: 0 };
            return {
                id: techId,
                label: opt ? opt.label : techId,
                ida: log.ida,
                espera: log.espera,
                regreso: log.regreso
            };
        });
    }

    handleTechTimeChange(event) {
        const techId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const val = parseInt(event.target.value, 10) || 0;
        if (!this.currentModalLogistica[techId]) {
            this.currentModalLogistica[techId] = { ida: 0, espera: 0, regreso: 0 };
        }
        this.currentModalLogistica[techId][field] = val;
    }

    openTechModal(event) {
        this.currentModalRowIndex = parseInt(event.currentTarget.dataset.rowIndex, 10);
        this.currentModalTraId = event.currentTarget.dataset.traId;
        
        let existingTechs = [];
        let existingLog = {};
        this.sedesList.forEach(sede => {
            sede.tratamientos.forEach(tra => {
                if (tra.id === this.currentModalTraId) {
                    existingTechs = tra.schedulingRows[this.currentModalRowIndex].tecnicosIds || [];
                    existingLog = tra.schedulingRows[this.currentModalRowIndex].tecnicosLogistica || {};
                }
            });
        });
        
        this.currentModalTechs = existingTechs;
        this.currentModalLogistica = JSON.parse(JSON.stringify(existingLog));
        this.isTechModalOpen = true;
    }

    closeTechModal() {
        this.isTechModalOpen = false;
        this.currentModalTraId = null;
        this.currentModalRowIndex = null;
        this.currentModalTechs = [];
        this.currentModalLogistica = {};
    }

    handleModalTechChange(event) {
        this.currentModalTechs = event.detail.value;
    }

    saveTechModal() {
        const val = this.currentModalTechs;
        const log = this.currentModalLogistica;
        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === this.currentModalTraId) {
                    const newRows = [...tra.schedulingRows];
                    newRows[this.currentModalRowIndex] = { 
                        ...newRows[this.currentModalRowIndex], 
                        tecnicosIds: val,
                        tecnicosLogistica: log
                    };
                    return { ...tra, schedulingRows: newRows };
                }
                return tra;
            })
        }));
        
        this.closeTechModal();
    }

    handleRemovePill(event) {
        const traId = event.currentTarget.dataset.traId;
        const rowIndex = parseInt(event.currentTarget.dataset.rowIndex, 10);
        const techToRemove = event.detail.item.name;

        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (tra.id === traId) {
                    const newRows = [...tra.schedulingRows];
                    let currentTechs = newRows[rowIndex].tecnicosIds || [];
                    newRows[rowIndex] = { 
                        ...newRows[rowIndex], 
                        tecnicosIds: currentTechs.filter(id => id !== techToRemove)
                    };
                    return { ...tra, schedulingRows: newRows };
                }
                return tra;
            })
        }));
    }

    handleOpenZoneBrowser(event) {
        const traId = event.currentTarget.dataset.traId;
        let currentZones = '';
        
        // Buscar el texto actual de zonas para este tratamiento
        this.sedesList.forEach(sede => {
            sede.tratamientos.forEach(tra => {
                if (tra.id === traId) currentZones = tra.zonas;
            });
        });

        const drawer = this.template.querySelector('c-tech-zone-browser-drawer');
        if (drawer) drawer.open(traId, currentZones);
    }

    handleZoneSelection(event) {
        const { traIds, zones } = event.detail;
        const zonesNames = zones.map(z => z.Name).join(', ');

        this.sedesList = this.sedesList.map(sede => ({
            ...sede,
            tratamientos: sede.tratamientos.map(tra => {
                if (traIds.includes(tra.id)) {
                    return { 
                        ...tra, 
                        zonas: zonesNames,
                        selectedZonesData: zones // Guardamos los objetos completos (ID, Nombre, Plantilla)
                    };
                }
                return tra;
            })
        }));

        this.dispatchEvent(new ShowToastEvent({
            title: 'Zonas Actualizadas',
            message: `Se han configurado ${zones.length} zonas en ${traIds.length} tratamientos.`,
            variant: 'success'
        }));
    }

    handleBackToContract() { this.dispatchEvent(new CustomEvent('back')); }
    handleViewQuote() { /* Lógica para abrir PDF */ }
    handleAddCandidateDates() { this.showSchedulingSection = !this.showSchedulingSection; }

    toggleAccordion(event) {
        const accordionBody = event.currentTarget.nextElementSibling;
        accordionBody.style.display = accordionBody.style.display === 'none' ? 'block' : 'none';
    }

    async handleGenerateODTs() {
        if (this.isSaving) return;

        // Validaciones preventivas
        if (!this.contractData.direccionSede || this.contractData.direccionSede.trim() === '') {
            this.dispatchEvent(new ShowToastEvent({ title: 'Atención', message: 'Falta la dirección de ejecución.', variant: 'warning' }));
            return;
        }

        let hasError = false;
        let errorMsg = '';
        let missingTechs = false;

        this.sedesList.forEach(sede => {
            sede.tratamientos.forEach(tra => {
                tra.schedulingRows.forEach(row => {
                    if (!row.tecnicosIds || row.tecnicosIds.length === 0) {
                        missingTechs = true;
                    }
                    if (!row.date || !row.startTime) {
                        hasError = true;
                        errorMsg = `El tratamiento ${tra.name} tiene citas sin fecha u hora asignada.`;
                    }
                });
            });
        });

        if (hasError) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Datos Incompletos', message: errorMsg, variant: 'warning' }));
            return;
        }

        if (missingTechs) {
            const confirmed = await LightningConfirm.open({
                message: 'Estás dejando tratamientos sin un Equipo Base asignado.\n\nEstos servicios se crearán en estado "Por Asignar" y tendrás que programar a los técnicos después desde el Calendario General.\n\n¿Deseas continuar y generar las citas así?',
                variant: 'header',
                label: 'Servicios Sin Asignar',
                theme: 'warning'
            });

            if (!confirmed) {
                return; // Se cancela la acción
            }
        }

        this.isSaving = true;

        const payload = {
            existingWorkOrderId: this.existingWorkOrderId || null,
            quoteId: this.internalQuoteId || null,
            serviceContractId: this.internalServiceContractId || null,
            oppId: this.oppId || null,
            accountId: this.accountId || null,
            folio: this.contractFolio,
            notes: '',
            priority: this.contractData.prioridad,
            territoryId: this.contractData.territoryId,
            executionAddress: this.contractData.direccionSede,
            contactPerson: this.contractData.contactoPerson,
            sedesList: JSON.parse(JSON.stringify(this.sedesList)),
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

    get firstSedeTreatments() {
        return (this.sedesList && this.sedesList.length > 0) ? this.sedesList[0].tratamientos : [];
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

    get ganttBodyStyle() {
        let maxLanesUsed = 0;
        const { start, end, total } = this.getGanttRange();
        const rawItems = [];

        this.sedesList.forEach(sede => {
            sede.tratamientos.forEach(tra => {
                tra.schedulingRows.forEach((row) => {
                    const rowDate = new Date(row.date + 'T00:00:00');
                    if (rowDate >= start && rowDate <= end) {
                        rawItems.push({ rowDateMs: rowDate.getTime() });
                    }
                });
            });
        });

        rawItems.sort((a, b) => a.rowDateMs - b.rowDateMs);
        const msPerPixel = total / 2500;
        const visualCardDurationMs = 160 * msPerPixel;
        const lanes = [];

        rawItems.forEach(item => {
            let assignedLane = -1;
            for (let i = 0; i < lanes.length; i++) {
                if (item.rowDateMs >= lanes[i]) {
                    assignedLane = i; break;
                }
            }
            if (assignedLane === -1) { assignedLane = lanes.length; lanes.push(0); }
            lanes[assignedLane] = item.rowDateMs + visualCardDurationMs;
            if (assignedLane > maxLanesUsed) maxLanesUsed = assignedLane;
        });

        const h = Math.max(300, (maxLanesUsed + 2) * 75);
        return `height: ${h}px; position: relative;`;
    }

    get ganttItems() {
        const items = [];
        const { start, end, total } = this.getGanttRange();
        const rawItems = [];

        this.sedesList.forEach(sede => {
            sede.tratamientos.forEach(tra => {
                tra.schedulingRows.forEach((row, idx) => {
                    const rowTechNames = (row.tecnicosIds || []).map(id => {
                        const opt = this.tecnicosOptions.find(o => o.value === id);
                        return opt ? opt.label : '...';
                    }).join(', ');

                    const rowDate = new Date(row.date + 'T00:00:00');
                    if (rowDate >= start && rowDate <= end) {
                        rawItems.push({
                            id: `${tra.id}-${idx}`,
                            name: tra.name,
                            techs: rowTechNames || 'Sin asignar',
                            area: tra.zonas || 'Sede Principal',
                            dateStr: row.date,
                            timeStr: row.startTime ? row.startTime.substring(0, 5) : '--:--',
                            rowDateMs: rowDate.getTime(),
                            color: Math.abs(tra.name.length)
                        });
                    }
                });
            });
        });

        // Sort items by time to assign lanes properly
        rawItems.sort((a, b) => a.rowDateMs - b.rowDateMs);

        // Approximate container width = 2500px, card width = 160px with margin
        const msPerPixel = total / 2500;
        const visualCardDurationMs = 160 * msPerPixel;
        const lanes = [];

        rawItems.forEach(item => {
            const offsetMs = item.rowDateMs - start.getTime();
            const leftPercent = (offsetMs / total) * 100;

            // Find first available lane
            let assignedLane = -1;
            for (let i = 0; i < lanes.length; i++) {
                if (item.rowDateMs >= lanes[i]) {
                    assignedLane = i;
                    break;
                }
            }

            if (assignedLane === -1) {
                // Create a new lane
                assignedLane = lanes.length;
                lanes.push(0);
            }

            // Update lane occupied until this card visually ends
            lanes[assignedLane] = item.rowDateMs + visualCardDurationMs;

            const colors = ['#4299e1', '#48bb78', '#ed8936', '#9f7aea', '#f56565'];
            const colorStr = colors[item.color % colors.length];

            items.push({
                ...item,
                style: `left: ${leftPercent}%; top: ${assignedLane * 75}px; border-left: 4px solid ${colorStr};`,
                fullLabel: `Tratamiento: ${item.name}\nFecha: ${item.dateStr}\nHora: ${item.timeStr}\nTécnicos: ${item.techs}\nZonas: ${item.area}`
            });
        });

        return items;
    }
}