import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord, deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValuesByRecordType, getObjectInfo } from 'lightning/uiObjectInfoApi';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import ID_FIELD from '@salesforce/schema/Opportunity.Id';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import SUBSTAGE_FIELD from '@salesforce/schema/Opportunity.Subetapa__c';
import STATUS_FIELD from '@salesforce/schema/Opportunity.Estado_Subetapa__c';
import getOpportunitiesList from '@salesforce/apex/OperationsController.getOpportunitiesList';
import getOpportunitiesByAccount from '@salesforce/apex/OperationsController.getOpportunitiesByAccount';
import saveStageTracking from '@salesforce/apex/OperationsController.saveStageTracking';
import getProcessHistory from '@salesforce/apex/OperationsController.getProcessHistory';
import saveTechnicalData from '@salesforce/apex/QuoteController.saveTechnicalData';
import TechSlackModal from 'c/techSlackModal';

export default class TechOperations360 extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    // --- ESTADO DEL MODAL ---
    @track isCreationModalOpen = false;
    @track activeOppId = null; 
    
    // LISTA DE CAMPOS SEGÚN x.txt
    @track opportunityFields = [
        'CloseDate', 
        'Name', 
        'StageName', 
        'Amount', 
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
        const result = await TechSlackModal.open({
            size: 'large',
            description: 'Modal de comunicación Slack 360',
            recordId: targetId,
            currentPhase: this.currentStage ? this.currentStage.label : 'General'
        });
    }

    // --- ESTADO DEL DASHBOARD ---
    @track opportunities = [];
    @track isLoading = false;
    
    columns = [
        { label: 'Oportunidad', fieldName: 'name', type: 'button', initialWidth: 250,
            typeAttributes: { label: { fieldName: 'name' }, name: 'open_360', variant: 'base', class: 'opportunity-link' }
        },
        { label: 'Cliente', fieldName: 'account', type: 'text' },
        { label: 'Etapa', fieldName: 'stageName', type: 'text' },
        { label: 'Monto', fieldName: 'amount', type: 'currency', cellAttributes: { alignment: 'left' } },
        { label: 'Fecha de Cierre', fieldName: 'closeDate', type: 'date' },
        { label: 'Propietario', fieldName: 'owner', type: 'text' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'Abrir Expediente 360', name: 'open_360', iconName: 'standard:omni_channel' },
            { label: 'Eliminar', name: 'delete', iconName: 'utility:delete', variant: 'destructive' }
        ] } }
    ];

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
            if (this.effectiveRecordId) this.loadProcessHistory();
        } else if (error) console.error('Error metadatos:', error);
    }

    loadProcessHistory() {
        const targetId = this.effectiveRecordId;
        if (!targetId) return;
        getProcessHistory({ opportunityId: targetId })
            .then(data => {
                // Guardamos los datos tal cual vienen (read-only por defecto)
                this.processHistory = data || [];
                this.updateCurrentStatusFromHistory();
            })
            .catch(error => console.error('Error history:', error));
    }

    updateCurrentStatusFromHistory() {
        // Blindaje contra nulos y listas vacías
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
        if (!this.currentStep && this.stages.length > 0) this.currentStep = this.stages[0].value;
    }

    handleStatusChange(event) {
        const newValue = event.detail.value;
        this.currentStatus = newValue;
        
        const step = this.currentStep || '';
        const phase = this.subPhase || '';

        // PATRÓN DE INMUTABILIDAD: Creamos una nueva referencia del array
        let history = this.processHistory ? [...this.processHistory] : [];
        const idx = history.findIndex(h => h && h.Etapa__c === step && h.Subetapa__c === phase);

        if (idx !== -1) {
            // Reemplazamos el objeto por uno nuevo con el cambio
            // Esto evita modificar el objeto original congelado
            history[idx] = { ...history[idx], Estado__c: newValue };
        } else {
            history.push({ 
                Etapa__c: step, 
                Subetapa__c: phase, 
                Estado__c: newValue 
            });
        }
        
        // Asignamos la nueva referencia para disparar la reactividad de LWC
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
                this.currentStep = 'Definición';
                this.currentSubStep = '1';
                this.quoteViewMode = 'list';
                this.loadProcessHistory();
            } else if (this.isAccountContext) {
                this.activeOppId = null;
                this.loadOpportunities();
            }
        } else {
            this.activeOppId = null;
            this.loadOpportunities();
        }
    }

    get showDashboard() { 
        if (this.isAccountContext) return !this.activeOppId || this.viewingDashboard;
        return !this.recordId || (this.recordId && this.viewingDashboard); 
    }

    @track viewingDashboard = false;

    loadOpportunities() {
        this.isLoading = true;
        const action = this.isAccountContext ? getOpportunitiesByAccount({ accountId: this.recordId }) : getOpportunitiesList();
        action.then(data => { 
                this.opportunities = data; 
                this.isLoading = false; 
            })
            .catch(error => { console.error('Error:', error); this.isLoading = false; });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'open_360') {
            this.activeOppId = row.id;
            this.viewingDashboard = false;
            this.currentStep = 'Definición';
            this.currentSubStep = '1';
            this.quoteViewMode = 'list';
            this.loadProcessHistory();
        } else if (actionName === 'delete') {
            if (confirm('¿Está seguro de que desea eliminar esta oportunidad?')) {
                this.isLoading = true;
                deleteRecord(row.id)
                    .then(() => {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Éxito',
                                message: 'Oportunidad eliminada correctamente',
                                variant: 'success'
                            })
                        );
                        this.loadOpportunities();
                    })
                    .catch(error => {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Error al eliminar',
                                message: error.body.message,
                                variant: 'error'
                            })
                        );
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

    get subPhase() {
        const sub = (this.currentSubStages || []).find(ss => ss.value === this.currentSubStep);
        return sub ? sub.label : '';
    }

    get statusOptions() {
        if (!this.allStatusOptions || !this.statusControllerValues) return [];
        
        const controllerIndex = this.statusControllerValues[this.subPhase];
        
        // Caso 1: La subetapa existe en los metadatos de Salesforce (Etapas comerciales)
        if (controllerIndex !== undefined) {
            return this.allStatusOptions.filter(opt => opt.validFor.includes(controllerIndex));
        }
        
        // Caso 2: Etapas operativas/manuales (Altas, Organización)
        // Devolvemos opciones genéricas para permitir el avance del flujo
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

    handleNewOpportunity() {
        this.isCreationModalOpen = true;
    }

    closeCreationModal() {
        this.isCreationModalOpen = false;
    }

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
            // 1. Guardar el tracking de la etapa
            await saveStageTracking({ 
                opportunityId: targetId, 
                stage: this.currentStep, 
                subStage: this.subPhase, 
                status: 'En proceso' 
            });

            // 2. Crear la cotización técnica
            const payload = {
                opportunityId: targetId,
                name: 'Nuevo Presupuesto Técnico',
                status: 'Borrador',
                lineItems: '[]'
            };
            const newQuoteId = await saveTechnicalData({ data: payload });

            this.selectedQuoteId = newQuoteId;
            this.quoteViewMode = 'edit';
        } catch (error) {
            console.error('Error creando cotización:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'No se pudo crear la cotización. Revise la consola.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToQuoteList() { this.quoteViewMode = 'list'; this.selectedQuoteId = null; }
    handleContractGenerated(event) { this.selectedContractId = event.detail; }

    get isFirstStep() { return this.isDefinicion && this.currentSubStep === '1'; }
    get isLastStep() { 
        if (!this.stages || this.stages.length === 0) return false;
        const lastStage = this.stages[this.stages.length - 1];
        return this.currentStep === lastStage.value && this.currentSubStep === lastStage.subStages.length.toString();
    }

    handleStepClick(event) {
        this.currentStep = event.target.value;
        this.currentSubStep = '1';
        this.currentStatus = ''; 
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
    }

    handleSubStepClick(event) {
        this.currentSubStep = event.target.value;
        this.currentStatus = ''; 
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
    }

    get overallProgress() {
        if (!this.stages.length || !this.currentStep) return 0;
        let totalSubStages = 0;
        let completedSubStages = 0;
        let foundCurrent = false;

        this.stages.forEach(stage => {
            stage.subStages.forEach(sub => {
                totalSubStages++;
                if (!foundCurrent) {
                    if (stage.value === this.currentStep && sub.value === this.currentSubStep) {
                        foundCurrent = true; completedSubStages++;
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

        if (this.isLevantamientoPhase) {
            const surveyComp = this.template.querySelector('c-tech-levantamiento-manager');
            if (surveyComp) {
                const saved = await surveyComp.save();
                if (!saved) return;
            }
        }

        const maxSubSteps = this.currentSubStages.length;
        let nextSub = parseInt(this.currentSubStep) + 1;

        if (nextSub <= maxSubSteps) this.currentSubStep = nextSub.toString();
        else {
            const currentIndex = this.stages.findIndex(s => s.value === this.currentStep);
            if (currentIndex < this.stages.length - 1) {
                this.currentStep = this.stages[currentIndex + 1].value;
                this.currentSubStep = '1';
            }
        }
        this.currentStatus = '';
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
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
}