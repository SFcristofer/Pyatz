import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord } from 'lightning/uiRecordApi';
import { getPicklistValuesByRecordType, getObjectInfo } from 'lightning/uiObjectInfoApi';
import OPPORTUNITY_OBJECT from '@salesforce/schema/Opportunity';
import ID_FIELD from '@salesforce/schema/Opportunity.Id';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import SUBSTAGE_FIELD from '@salesforce/schema/Opportunity.Subetapa__c';
import STATUS_FIELD from '@salesforce/schema/Opportunity.Estado_Subetapa__c';
import getOpportunitiesList from '@salesforce/apex/QuoteTechnicalController.getOpportunitiesList';

export default class TechOperations360 extends NavigationMixin(LightningElement) {
    @api recordId;
    
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
        { type: 'action', typeAttributes: { rowActions: [{ label: 'Abrir Expediente 360', name: 'open_360', iconName: 'standard:omni_channel' }] } }
    ];

    // --- MOTOR HÍBRIDO DE ETAPAS ---
    @track stages = [];
    @track currentStep = '';
    @track currentSubStep = '1';
    @track currentStatus = ''; 
    @track allStatusOptions = [];
    @track quoteViewMode = 'list';
    @track selectedQuoteId = null;

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
            this.buildHybridStages(data.picklistFieldValues);
        } else if (error) {
            console.error('Error metadatos:', error);
        }
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

    // --- LÓGICA DE ESTADOS (DROPDOWN) ---
    get statusOptions() {
        if (!this.allStatusOptions.length || !this.subPhase) return [];
        return this.allStatusOptions.filter(opt => {
            const label = this.subPhase;
            if (label === 'Levantamiento' || label === 'Memoria') 
                return ['Pendiente confirmación cliente', 'Pendiente confirmación Pyatz', 'En proceso', 'Realizado'].includes(opt.label);
            if (label === 'Def. solución') return ['Falta información', 'Realizado'].includes(opt.label);
            if (label === 'Presupuesto') return ['En proceso - en tiempo', 'Falta información', 'Realizado'].includes(opt.label);
            if (label === 'Envío cotización') return ['Pendiente definición', 'Pendiente de envío a cliente', 'Recepción no confirmada con cliente.', 'Recepción confirmada con cliente'].includes(opt.label);
            if (label === 'Seguimiento') return ['Sin seguimiento', 'Sin respuesta del cliente', 'Seguimiento activo', 'Pendiente definición'].includes(opt.label);
            if (label === 'Autorización') return ['Rechazado', 'En proceso de autorización', 'Ajuste de presupuesto', 'Aceptado'].includes(opt.label);
            return true;
        });
    }

    handleStatusChange(event) {
        this.currentStatus = event.detail.value;
        this.syncOpportunityStatus();
    }

    // --- SINCRONIZACIÓN CON SALESFORCE ---
    async syncOpportunityStatus() {
        if (!this.recordId || !this.currentStep) return;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[STAGE_FIELD.fieldApiName] = this.currentStep;
        fields[SUBSTAGE_FIELD.fieldApiName] = this.subPhase;
        if (this.currentStatus) fields[STATUS_FIELD.fieldApiName] = this.currentStatus;

        const recordInput = { fields };
        try {
            await updateRecord(recordInput);
            console.log('Sincronización Exitosa: ' + this.currentStep + ' > ' + this.subPhase + ' (' + this.currentStatus + ')');
        } catch (error) { console.error('Error sync:', error); }
    }

    connectedCallback() {
        if (!this.recordId) this.loadOpportunities();
    }

    get showDashboard() { return !this.recordId; }

    loadOpportunities() {
        this.isLoading = true;
        getOpportunitiesList()
            .then(data => { this.opportunities = data; this.isLoading = false; })
            .catch(error => { console.error('Error:', error); this.isLoading = false; });
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'open_360') {
            this.recordId = event.detail.row.id;
            this.currentStep = 'Definición';
            this.currentSubStep = '1';
            // Intentar cargar estado actual si viene en el row
            this.currentStatus = event.detail.row.stageName === 'Definición' ? 'En proceso' : ''; 
            this.quoteViewMode = 'list';
            this.syncOpportunityStatus();
        }
    }

    handleBackToDashboard() { this.recordId = null; this.loadOpportunities(); }

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

    get isDefinicion() { return this.currentStep === 'Definición'; }
    get isCosteo() { return this.currentStep === 'Costeo'; }
    get isLevantamientoPhase() { return this.isDefinicion && this.currentSubStep === '1'; }
    get isMemoriaPhase() { return this.isDefinicion && this.currentSubStep === '2'; }
    get isDefSolucionPhase() { return this.isCosteo && this.currentSubStep === '1'; }
    get isPresupuestoPhase() { return this.isCosteo && this.currentSubStep === '2'; }
    get isContratoPhase() { return this.currentStep === 'Organización' && this.currentSubStep === '2'; }
    get isWorkOrderPhase() { return this.currentStep === 'Organización' && this.currentSubStep === '3'; }

    get showQuoteList() { return this.isPresupuestoPhase && this.quoteViewMode === 'list'; }
    get showQuoteEditor() { return this.isPresupuestoPhase && this.quoteViewMode === 'edit'; }

    handleEditQuote(event) { this.selectedQuoteId = event.detail; this.quoteViewMode = 'edit'; }
    handleCreateNewQuote() { this.selectedQuoteId = null; this.quoteViewMode = 'edit'; }
    handleBackToQuoteList() { this.quoteViewMode = 'list'; this.selectedQuoteId = null; }

    get isFirstStep() { return this.isDefinicion && this.currentSubStep === '1'; }
    get isLastStep() { 
        if (!this.stages || this.stages.length === 0) return false;
        const lastStage = this.stages[this.stages.length - 1];
        return this.currentStep === lastStage.value && this.currentSubStep === lastStage.subStages.length.toString();
    }

    handleStepClick(event) {
        this.currentStep = event.target.value;
        this.currentSubStep = '1';
        this.currentStatus = ''; // Reset estado al cambiar macro-etapa
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
    }

    handleSubStepClick(event) {
        this.currentSubStep = event.target.value;
        this.currentStatus = ''; 
        this.quoteViewMode = 'list';
        this.syncOpportunityStatus();
    }

    // --- CÁLCULO DE PROGRESO GLOBAL ---
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
                        foundCurrent = true;
                        completedSubStages++;
                    } else {
                        completedSubStages++;
                    }
                }
            });
        });

        if (totalSubStages === 0) return 0;
        return Math.round((completedSubStages / totalSubStages) * 100);
    }

    async handleNext() {
        if (this.isLevantamientoPhase) {
            const surveyComp = this.template.querySelector('c-tech-levantamiento-manager');
            if (surveyComp) {
                const saved = await surveyComp.save();
                if (!saved) return;
            }
        }

        const maxSubSteps = this.currentSubStages.length;
        let nextSub = parseInt(this.currentSubStep) + 1;

        if (nextSub <= maxSubSteps) {
            this.currentSubStep = nextSub.toString();
        } else {
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
        if (prevSub >= 1) {
            this.currentSubStep = prevSub.toString();
        } else {
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