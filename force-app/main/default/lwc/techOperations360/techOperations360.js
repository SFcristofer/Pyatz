import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord, deleteRecord, getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValuesByRecordType, getObjectInfo } from 'lightning/uiObjectInfoApi';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import ID_FIELD from '@salesforce/schema/Opportunity.Id';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import SUBSTAGE_FIELD from '@salesforce/schema/Opportunity.Subetapa__c';
import STATUS_FIELD from '@salesforce/schema/Opportunity.Estado_Subetapa__c';

const OPPORTUNITY_FIELDS = [STAGE_FIELD, SUBSTAGE_FIELD, STATUS_FIELD];
import getOpportunitiesList from '@salesforce/apex/OperationsController.getOpportunitiesList';
import getOpportunitiesByAccount from '@salesforce/apex/OperationsController.getOpportunitiesByAccount';
import saveStageTracking from '@salesforce/apex/OperationsController.saveStageTracking';
import getProcessHistory from '@salesforce/apex/OperationsController.getProcessHistory';
import saveTechnicalData from '@salesforce/apex/QuoteController.saveTechnicalData';
import getQuotesList from '@salesforce/apex/QuoteController.getQuotesList';
import TechSlackModal from 'c/techSlackModal';
import TechCalendarModal from 'c/techCalendarModal';

export default class TechOperations360 extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    // --- ESTADO DEL MODAL ---
    @track isCreationModalOpen = false;
    @track isSummaryModalOpen = false;
    @track activeOppId = null; 
    
    // LISTA DE CAMPOS SEGÚN x.txt
    @track opportunityFields = [
        'CloseDate', 
        'Name', 
        'StageName', 
        'Estado_Oportunidad__c',
        'Amount', 
        'Linea_de_negocio__c',
        'Tipo_de_venta__c',
        'Subetapa__c', 
        'Auxiliar_oportunidad__c', 
        'Estado_Subetapa__c'
    ];

    // --- DETECCIÓN DE CONTEXTO ---
    get isAccountContext() {
        return this.objectApiName === 'Account';
    }

    get effectiveRecordId() {
        return this.isAccountContext ? this.activeOppId : this.recordId;
    }
    
    // --- ACCIÓN GLOBAL: SLACK 360 ---
    async handleOpenSlack() {
        const targetId = this.effectiveRecordId;
        await TechSlackModal.open({
            size: 'large',
            description: 'Modal de comunicación Slack 360',
            recordId: targetId,
            currentPhase: this.currentStage ? this.currentStage.label : 'General'
        });
    }

    async handleOpenCalendar() {
        const targetId = this.effectiveRecordId;
        await TechCalendarModal.open({
            size: 'medium',
            description: 'Cronograma de Actividades 360',
            recordId: targetId
        });
    }

    // --- ESTADO DEL DASHBOARD ---
    @track opportunities = [];
    @track isLoading = false;
    @track searchTerm = '';
    @track draftValues = []; // Para edición en tabla

    columns = [
        { label: 'Oportunidad', fieldName: 'name', type: 'button', initialWidth: 250,
            typeAttributes: { label: { fieldName: 'name' }, name: 'open_360', variant: 'base', class: 'opportunity-link' }
        },
        { label: 'Cliente', fieldName: 'account', type: 'text' },
        { label: 'Etapa', fieldName: 'stageName', type: 'text' },
        { label: 'Estado Oportunidad', fieldName: 'statusOpp', type: 'text' },
        { label: 'Monto', fieldName: 'amount', type: 'currency', cellAttributes: { alignment: 'left' } },
        { label: 'Fecha de Cierre', fieldName: 'closeDate', type: 'date' },
        { label: 'Propietario', fieldName: 'owner', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'Abrir Expediente 360', name: 'open_360', iconName: 'standard:omni_channel' },
            { label: 'Eliminar', name: 'delete', iconName: 'utility:delete', variant: 'destructive' }
        ] } }
    ];

    wiredOppsResult;
    @wire(getOpportunitiesList, { searchTerm: '$searchTerm' })
    wiredOpps(result) {
        this.wiredOppsResult = result;
        const { error, data } = result;
        if (this.isAccountContext) return;
        this.isLoading = true;
        if (data) {
            this.opportunities = data;
        } else if (error) {
            console.error('Error fetching opps:', error);
        }
        this.isLoading = false;
    }

    async handleSave(event) {
        const recordInputs = event.detail.draftValues.map(draft => {
            const fields = { ...draft };
            // Mapear fieldName de la tabla al API Name de Salesforce
            if (fields.statusOpp) {
                fields['Estado_Oportunidad__c'] = fields.statusOpp;
                delete fields.statusOpp;
            }
            return { fields };
        });

        const promises = recordInputs.map(recordInput => updateRecord(recordInput));
        try {
            await Promise.all(promises);
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Oportunidad actualizada', variant: 'success' }));
            this.draftValues = [];
            // Forzar recarga de datos
            if (this.isAccountContext) {
                this.loadOpportunities();
            } else {
                // Si estamos en dashboard, el wire se refresca con refreshApex (necesitaríamos importar refreshApex)
                location.reload(); // Opción simple para asegurar refresco global
            }
        } catch (error) {
            console.error('Error al guardar:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo actualizar el estado.', variant: 'error' }));
        }
    }

    // Handler para cambios rápidos en el encabezado
    handleHeaderStatusChange() {
        this.template.querySelector('.header-edit-form').submit();
    }

    handleHeaderSuccess() {
        this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Estado actualizado correctamente', variant: 'success' }));
        if (this.isAccountContext) this.loadOpportunities();
    }

    handlePicklistChange(event) {
        // Placeholder para futura implementación de picklist en datatable
        console.log('Picklist changed:', event.detail);
    }

    handleSearchChange(event) {
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
        this.delayTimeout = setTimeout(() => {
            this.searchTerm = searchKey;
        }, 400);
    }
    
    // --- MOTOR HÍBRIDO DE ETAPAS ---
    @track stages = [];
    @track currentStep = '';
    @track currentSubStep = '1';
    @track currentStatus = ''; 
    @track allStatusOptions = [];
    @track statusControllerValues = {}; // Mapa de dependencias
    @track processHistory = []; 
    @track quoteViewMode = 'list';
    @track selectedQuoteId = null;
    @track selectedContractId = null;

    // Control de sincronización para evitar reinicio involuntario
    _metadataLoaded = false;
    _recordLoaded = false;
    _pendingStage = null;
    _pendingSubStage = null;
    _pendingStatus = null;

    OPERATIONAL_STAGES = [
        {
            value: 'Altas', label: 'Altas',
            subStages: [
                { value: '1', label: 'Alta cliente (Clientes nuevos)' },
                { value: '2', label: 'Alta pyatz (Clientes nuevos)' }
            ]
        },
        {
            value: 'Organización', label: 'Organización',
            subStages: [
                { value: '1', label: 'Calendario' },
                { value: '2', label: 'Contrato' },
                { value: '3', label: "Creación ODT's" },
                { value: '4', label: 'Enhorabuena' }
            ]
        }
    ];

    @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT })
    objectInfo;

    @wire(getPicklistValuesByRecordType, { 
        objectApiName: OPPORTUNITY_OBJECT, 
        recordTypeId: '$objectInfo.data.defaultRecordTypeId' 
    })
    wiredPicklists({ error, data }) {
        if (data) {
            this.allStatusOptions = data.picklistFieldValues.Estado_Subetapa__c.values;
            this.statusControllerValues = data.picklistFieldValues.Estado_Subetapa__c.controllerValues;
            this.buildHybridStages(data.picklistFieldValues);
            this._metadataLoaded = true;
            this.applyPersistence();
            if (this.effectiveRecordId) this.loadProcessHistory();
        } else if (error) console.error('Error metadatos:', error);
    }

    // --- PERSISTENCIA DE NAVEGACIÓN ---
    @wire(getRecord, { recordId: '$activeOppId', fields: OPPORTUNITY_FIELDS })
    wiredOppRecord({ error, data }) {
        if (data && this.activeOppId && !this.viewingDashboard) {
            this._pendingStage = data.fields.StageName.value;
            this._pendingSubStage = data.fields.Subetapa__c.value;
            this._pendingStatus = data.fields.Estado_Subetapa__c.value;
            this._recordLoaded = true;
            this.applyPersistence();
        } else if (error) {
            console.error('Error loading navigation state:', error);
        }
    }

    /**
     * Lógica de Sincronización Segura:
     * Solo aplica la posición del wizard cuando tenemos metadatos (etapas) y datos de registro.
     */
    applyPersistence() {
        if (!this._metadataLoaded || !this._recordLoaded || !this._pendingStage) return;

        const foundStage = this.stages.find(s => s.value === this._pendingStage || s.label === this._pendingStage);
        if (foundStage) {
            this.currentStep = foundStage.value;
            const foundSub = foundStage.subStages.find(ss => ss.label === this._pendingSubStage);
            if (foundSub) {
                this.currentSubStep = foundSub.value;
            }
        }
        this.currentStatus = this._pendingStatus || '';
        this.updateCurrentStatusFromHistory();
        
        // Limpiar para evitar reprocesos innecesarios
        this._recordLoaded = false; 
    }

    loadProcessHistory() {
        const targetId = this.effectiveRecordId;
        if (!targetId) return;
        getProcessHistory({ opportunityId: targetId })
            .then(data => {
                this.processHistory = data || [];
                this.updateCurrentStatusFromHistory();
            })
            .catch(error => console.error('Error history:', error));
    }

    updateCurrentStatusFromHistory() {
        if (!this.processHistory || !this.processHistory.length || !this.subPhase) {
            this.currentStatus = '';
            return;
        }
        const record = this.processHistory.find(h => 
            h && 
            String(h.Etapa__c || '').trim() === String(this.currentStep || '').trim() && 
            String(h.Subetapa__c || '').trim() === String(this.subPhase || '').trim()
        );
        this.currentStatus = record ? record.Estado__c : '';
    }

    buildHybridStages(picklists) {
        const stageNames = picklists.StageName.values;
        const subEtapas = picklists.Subetapa__c;
        const commercialStages = ['Definición', 'Costeo', 'Negociación', 'Cierre'];
        
        let dynamicStages = stageNames
            .filter(s => commercialStages.includes(s.label))
            .map(s => {
                const validSubStages = subEtapas.values
                    .filter(sub => {
                        if (s.label === 'Definición') return ['Levantamiento', 'Memoria'].includes(sub.label);
                        if (s.label === 'Costeo') return ['Def. solución', 'Presupuesto'].includes(sub.label);
                        if (s.label === 'Negociación') return ['Envío cotización', 'Seguimiento'].includes(sub.label);
                        if (s.label === 'Cierre') return ['Autorización'].includes(sub.label);
                        return false;
                    })
                    .map((sub, index) => ({ value: (index + 1).toString(), label: sub.label }));

                return { value: s.value, label: s.label, subStages: validSubStages };
            });

        this.stages = [...dynamicStages, ...this.OPERATIONAL_STAGES];
        if (!this.currentStep && this.stages.length > 0 && !this._pendingStage) {
            this.currentStep = this.stages[0].value;
        }
    }

    handleStatusChange(event) {
        const newValue = event.detail.value;
        this.currentStatus = newValue;
        const step = this.currentStep || '';
        const phase = this.subPhase || '';

        let history = this.processHistory ? [...this.processHistory] : [];
        const idx = history.findIndex(h => h && h.Etapa__c === step && h.Subetapa__c === phase);

        if (idx !== -1) {
            history[idx] = { ...history[idx], Estado__c: newValue };
        } else {
            history.push({ Etapa__c: step, Subetapa__c: phase, Estado__c: newValue });
        }
        
        this.processHistory = history;
        this.syncOpportunityStatus();
    }

    async syncOpportunityStatus() {
        const targetId = this.effectiveRecordId;
        if (!targetId || !this.currentStep) return;
        if (!this.currentStatus) this.updateCurrentStatusFromHistory();

        if (this.subPhase && this.currentStatus) {
            try {
                await saveStageTracking({
                    opportunityId: targetId,
                    stage: this.currentStep,
                    subStage: this.subPhase,
                    status: this.currentStatus
                });
                const summaryComp = this.template.querySelector('c-tech-process-summary');
                if (summaryComp) summaryComp.refreshData();
            } catch (e) { console.error('Error tracking:', e); }
        }

        const fields = {};
        fields[ID_FIELD.fieldApiName] = targetId;
        fields[STAGE_FIELD.fieldApiName] = this.currentStep;
        fields[SUBSTAGE_FIELD.fieldApiName] = this.subPhase;
        if (this.currentStatus) fields[STATUS_FIELD.fieldApiName] = this.currentStatus;

        const recordInput = { fields };
        try {
            await updateRecord(recordInput);
        } catch (error) { console.error('Error sync:', error); }
    }

    connectedCallback() {
        if (this.recordId) {
            if (this.objectApiName === 'Opportunity') {
                this.activeOppId = this.recordId;
                this.quoteViewMode = 'list';
                this.loadProcessHistory();
            } else if (this.isAccountContext) {
                this.activeOppId = null;
                this.loadOpportunities();
            }
        } else {
            this.activeOppId = null;
            this.viewingDashboard = true;
        }
    }

    get showDashboard() { 
        if (this.isAccountContext) return !this.activeOppId || this.viewingDashboard;
        return !this.recordId || (this.recordId && this.viewingDashboard); 
    }

    loadOpportunities() {
        this.isLoading = true;
        if (this.isAccountContext) {
            getOpportunitiesByAccount({ accountId: this.recordId })
                .then(data => { this.opportunities = data; })
                .catch(error => { console.error('Error:', error); })
                .finally(() => { this.isLoading = false; });
        } else {
            this.isLoading = false; 
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'open_360') {
            this.activeOppId = row.id;
            this.viewingDashboard = false;
            // No reseteamos currentStep aquí, dejamos que la persistencia actúe
            this.quoteViewMode = 'list';
            this.loadProcessHistory();
        } else if (actionName === 'delete') {
            if (confirm('¿Está seguro de que desea eliminar esta oportunidad?')) {
                this.isLoading = true;
                deleteRecord(row.id)
                    .then(() => {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Oportunidad eliminada', variant: 'success' }));
                        this.loadOpportunities();
                    })
                    .catch(error => {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
                        this.isLoading = false;
                    });
            }
        }
    }

    handleBackToDashboard() { 
        this.viewingDashboard = true;
        this.activeOppId = null;
        this.loadOpportunities();
    }

    get currentStage() { return this.stages.find(s => s.value === this.currentStep); }

    get currentSubStages() {
        return (this.currentStage ? this.currentStage.subStages : []).map(sub => {
            return {
                ...sub,
                buttonClass: sub.value === this.currentSubStep 
                    ? 'slds-button slds-button_brand active-substep' 
                    : 'slds-button slds-button_neutral'
            };
        });
    }

    get processedStages() {
        if (!this.stages) return [];
        let maxStageIndex = 0;
        const currentStageIdx = this.stages.findIndex(s => s.value === this.currentStep);
        
        if (this.processHistory && this.processHistory.length > 0) {
            this.processHistory.forEach(h => {
                const idx = this.stages.findIndex(s => s.value === h.Etapa__c || s.label === h.Etapa__c);
                if (idx > maxStageIndex) maxStageIndex = idx;
            });
        }
        if (currentStageIdx > maxStageIndex) maxStageIndex = currentStageIdx;

        return this.stages.map((stage, index) => {
            let cssClass = 'slds-path__item ';
            let isCompleted = false;
            let isCurrent = false;
            if (index === currentStageIdx) {
                cssClass += 'slds-is-current slds-is-active';
                isCurrent = true;
            } else if (index <= maxStageIndex) {
                cssClass += 'slds-is-complete';
                isCompleted = true;
            } else {
                cssClass += 'slds-is-incomplete';
            }
            return { ...stage, cssClass, isCompleted, isCurrent };
        });
    }

    get processedSubStages() {
        const subStages = this.currentSubStages;
        if (!subStages || subStages.length === 0) return [];
        let maxSubIndex = 0;
        const currentSubIdx = subStages.findIndex(s => s.value === this.currentSubStep);

        if (this.processHistory && this.processHistory.length > 0) {
            const stageHistory = this.processHistory.filter(h => h.Etapa__c === this.currentStep || h.Etapa__c === (this.currentStage ? this.currentStage.label : ''));
            stageHistory.forEach(h => {
                const idx = subStages.findIndex(s => s.value === h.Subetapa__c || s.label === h.Subetapa__c);
                if (idx > maxSubIndex) maxSubIndex = idx;
            });
        }
        if (currentSubIdx > maxSubIndex) maxSubIndex = currentSubIdx;

        return subStages.map((sub, index) => {
            let cssClass = 'slds-path__item ';
            let isCompleted = false;
            let isCurrent = false;
            if (index === currentSubIdx) {
                cssClass += 'slds-is-current slds-is-active';
                isCurrent = true;
            } else if (index <= maxSubIndex) {
                cssClass += 'slds-is-complete';
                isCompleted = true;
            } else {
                cssClass += 'slds-is-incomplete';
            }
            return { ...sub, cssClass, isCompleted, isCurrent };
        });
    }

    get subPhase() {
        const sub = (this.currentSubStages || []).find(ss => ss.value === this.currentSubStep);
        return sub ? sub.label : '';
    }

    get statusOptions() {
        if (!this.allStatusOptions || !this.statusControllerValues) return [];
        const controllerIndex = this.statusControllerValues[this.subPhase];
        if (controllerIndex !== undefined) {
            return this.allStatusOptions.filter(opt => opt.validFor.includes(controllerIndex));
        }
        return [
            { label: 'En proceso', value: 'En proceso' },
            { label: 'Realizado', value: 'Realizado' },
            { label: 'Pendiente', value: 'Pendiente' }
        ];
    }

    get isDefinicion() { return this.currentStep === 'Definición'; }
    get isCosteo() { return this.currentStep === 'Costeo'; }
    get isLevantamientoPhase() { return this.isDefinicion && this.currentSubStep === '1'; }
    get isMemoriaPhase() { return this.isDefinicion && this.currentSubStep === '2'; }
    get isDefSolucionPhase() { return this.isCosteo && this.currentSubStep === '1'; }
    get isPresupuestoPhase() { return this.isCosteo && this.currentSubStep === '2'; }
    get isEnvioPhase() { return this.currentStep === 'Negociación' && this.currentSubStep === '1'; }
    get isSeguimientoPhase() { return this.currentStep === 'Negociación' && this.currentSubStep === '2'; }
    get isAltaCliente() { return this.currentStep === 'Altas' && this.currentSubStep === '1'; }
    get isAltaPyatz() { return this.currentStep === 'Altas' && this.currentSubStep === '2'; }
    get isAutorizacionPhase() { return this.currentStep === 'Cierre' && this.currentSubStep === '1'; }
    get isCalendarioPhase() { return this.currentStep === 'Organización' && this.currentSubStep === '1'; }
    get isContratoPhase() { return this.currentStep === 'Organización' && this.currentSubStep === '2'; }
    get isWorkOrderPhase() { return this.currentStep === 'Organización' && this.currentSubStep === '3'; }
    get isEnhorabuenaPhase() { return this.currentStep === 'Organización' && this.currentSubStep === '4'; }

    handleLogCall() { this.navigateToGlobalAction('LogACall'); }
    handleNewTask() { this.navigateToGlobalAction('NewTask'); }

    handleNewOpportunity() { this.isCreationModalOpen = true; }
    closeCreationModal() { this.isCreationModalOpen = false; }

    openSummaryModal() { this.isSummaryModalOpen = true; }
    closeSummaryModal() { this.isSummaryModalOpen = false; }

    handleOpportunitySuccess(event) {
        const newOppId = event.detail.id;
        this.isCreationModalOpen = false;
        this.activeOppId = newOppId;
        this.viewingDashboard = false;
        this.currentStep = 'Definición';
        this.currentSubStep = '1';
        this.quoteViewMode = 'list';
        this.loadProcessHistory();
    }

    navigateToGlobalAction(actionName) {
        const targetId = this.effectiveRecordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: `Global.${actionName}` },
            state: { recordId: targetId, contextId: targetId, defaultFieldValues: `WhatId=${targetId}` }
        });
    }

    get showQuoteList() { return this.isPresupuestoPhase && this.quoteViewMode === 'list'; }
    get showQuoteEditor() { return this.isPresupuestoPhase && this.quoteViewMode === 'edit'; }

    handleEditQuote(event) { this.selectedQuoteId = event.detail; this.quoteViewMode = 'edit'; }
    
    async handleCreateNewQuote() {
        this.isLoading = true;
        const targetId = this.effectiveRecordId;
        try {
            await saveStageTracking({ opportunityId: targetId, stage: this.currentStep, subStage: this.subPhase, status: 'En proceso' });
            const payload = { opportunityId: targetId, name: 'Nuevo Presupuesto Técnico', status: 'Borrador', lineItems: '[]' };
            const newQuoteId = await saveTechnicalData({ data: payload });
            this.selectedQuoteId = newQuoteId;
            this.quoteViewMode = 'edit';
        } catch (error) {
            console.error('Error creando cotización:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo crear la cotización.', variant: 'error' }));
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToQuoteList() { this.quoteViewMode = 'list'; this.selectedQuoteId = null; }
    handleContractGenerated(event) { this.selectedContractId = event.detail; }

    async handlePhaseSuccess(event) {
        const phase = event.detail.phase;
        if (phase === 'Negociación') {
            this.currentStatus = 'Realizado';
            this.currentSubStep = '2'; 
            await this.syncOpportunityStatus();
            this.dispatchEvent(new ShowToastEvent({ title: 'Flujo Automatizado', message: 'Correo enviado. Avanzando...', variant: 'info' }));
        }
    }

    async handleContractFinalized(event) {
        this.selectedContractId = event.detail;
        this.currentStatus = 'Realizado';
        this.currentSubStep = '3'; 
        await this.syncOpportunityStatus();
    }

    get isFirstStep() { return this.isDefinicion && this.currentSubStep === '1'; }
    get isLastStep() { 
        if (!this.stages || this.stages.length === 0) return false;
        const lastStage = this.stages[this.stages.length - 1];
        return this.currentStep === lastStage.value && this.currentSubStep === lastStage.subStages.length.toString();
    }

    handleStepClick(event) {
        this.currentStep = event.currentTarget.dataset.value || event.target.value;
        this.currentSubStep = '1';
        this.currentStatus = ''; 
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
        if (this.isPresupuestoPhase) this.autoNavigateQuote();
    }

    handleSubStepClick(event) {
        this.currentSubStep = event.currentTarget.dataset.value || event.target.value;
        this.currentStatus = ''; 
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
        if (this.isPresupuestoPhase) this.autoNavigateQuote();
    }

    get overallProgress() {
        if (!this.stages || !this.stages.length || !this.currentStep) return 0;
        let totalSubStages = 0;
        let completedSubStages = 0;
        let foundCurrent = false;
        this.stages.forEach(stage => {
            stage.subStages.forEach(sub => {
                totalSubStages++;
                if (!foundCurrent) {
                    if (stage.value === this.currentStep && sub.value === this.currentSubStep) {
                        foundCurrent = true; 
                        completedSubStages++;
                    } else completedSubStages++;
                }
            });
        });
        if (totalSubStages === 0) return 0;
        return Math.round((completedSubStages / totalSubStages) * 100);
    }

    async handleNext() {
        const statusCombo = this.template.querySelector('.status-combobox');
        if (statusCombo && !statusCombo.checkValidity()) {
            statusCombo.reportValidity();
            return;
        }
        this.isLoading = true;
        try {
            if (this.isLevantamientoPhase) {
                const surveyComp = this.template.querySelector('c-tech-levantamiento-manager');
                if (surveyComp) {
                    const saved = await surveyComp.save();
                    if (!saved) { this.isLoading = false; return; }
                }
            }
            const maxSubSteps = this.currentSubStages.length;
            let nextSub = parseInt(this.currentSubStep) + 1;
            if (nextSub <= maxSubSteps) {
                this.currentSubStep = nextSub.toString();
            } else {
                const currentIndex = this.stages.findIndex(s => s.value === this.currentStep);
                if (currentIndex !== -1 && currentIndex < this.stages.length - 1) {
                    this.currentStep = this.stages[currentIndex + 1].value;
                    this.currentSubStep = '1';
                }
            }
            this.currentStatus = '';
            this.quoteViewMode = 'list';
            await this.syncOpportunityStatus();
            if (this.isPresupuestoPhase) await this.autoNavigateQuote();
        } catch (error) {
            console.error('Error en navegación:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Ocurrió un error al avanzar.', variant: 'error' }));
        } finally {
            this.isLoading = false;
        }
    }

    handlePrev() {
        let prevSub = parseInt(this.currentSubStep) - 1;
        if (prevSub >= 1) this.currentSubStep = prevSub.toString();
        else {
            const currentIndex = this.stages.findIndex(s => s.value === this.currentStep);
            if (currentIndex > 0) {
                const prevStage = this.stages[currentIndex - 1];
                this.currentStep = prevStage.value;
                this.currentSubStep = prevStage.subStages.length.toString();
            }
        }
        this.currentStatus = '';
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
    }

    async autoNavigateQuote() {
        const targetId = this.effectiveRecordId;
        if (!targetId) return;
        this.isLoading = true;
        try {
            const result = await getQuotesList({ opportunityId: targetId });
            if (result && result.length > 0) {
                this.selectedQuoteId = result[0].id;
                this.quoteViewMode = 'edit';
            } else {
                await this.handleCreateNewQuote();
            }
        } catch (error) {
            console.error('Error en auto-navegación:', error);
            this.quoteViewMode = 'list';
        } finally {
            this.isLoading = false;
        }
    }
}