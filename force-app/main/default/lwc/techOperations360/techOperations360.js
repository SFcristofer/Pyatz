import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getOpportunitiesList from '@salesforce/apex/QuoteTechnicalController.getOpportunitiesList';

export default class TechOperations360 extends NavigationMixin(LightningElement) {
    @api recordId;
    
    // --- ESTADO DEL DASHBOARD INICIAL ---
    @track opportunities = [];
    @track isLoading = false;
    
    columns = [
        { label: 'Oportunidad', fieldName: 'name', type: 'text', initialWidth: 250 },
        { label: 'Cliente', fieldName: 'account', type: 'text' },
        { label: 'Etapa', fieldName: 'stageName', type: 'text' },
        { label: 'Monto', fieldName: 'amount', type: 'currency', cellAttributes: { alignment: 'left' } },
        { label: 'Fecha de Cierre', fieldName: 'closeDate', type: 'date' },
        { label: 'Propietario', fieldName: 'owner', type: 'text' },
        {
            type: 'action',
            typeAttributes: { rowActions: [{ label: 'Abrir Expediente 360', name: 'open_360', iconName: 'standard:omni_channel' }] }
        }
    ];

    // --- ESTADO DEL EXPEDIENTE 360 ---
    @track currentStep = '1';
    @track currentSubStep = '1';

    // Definición de la estructura completa basada en x.txt
    @track stages = [
        {
            value: '1',
            label: 'Definición',
            subStages: [
                { value: '1', label: 'Levantamiento' },
                { value: '2', label: 'Memoria' }
            ]
        },
        {
            value: '2',
            label: 'Costeo',
            subStages: [
                { value: '1', label: 'Def. solución' },
                { value: '2', label: 'Presupuesto' }
            ]
        },
        {
            value: '3',
            label: 'Negociación',
            subStages: [
                { value: '1', label: 'Envío cotización' },
                { value: '2', label: 'Seguimiento' }
            ]
        },
        {
            value: '4',
            label: 'Cierre',
            subStages: [
                { value: '1', label: 'Autorización' }
            ]
        },
        {
            value: '5',
            label: 'Altas',
            subStages: [
                { value: '1', label: 'Alta cliente (Clientes nuevos)' },
                { value: '2', label: 'Alta pyatz (Clientes nuevos)' }
            ]
        },
        {
            value: '6',
            label: 'Organización',
            subStages: [
                { value: '1', label: 'Calendario' },
                { value: '2', label: 'Contrato' },
                { value: '3', label: "Creación ODT's" },
                { value: '4', label: 'Enhorabuena' }
            ]
        }
    ];

    connectedCallback() {
        if (!this.recordId) {
            this.loadOpportunities();
        }
    }

    // --- LÓGICA DEL DASHBOARD ---
    get showDashboard() {
        return !this.recordId;
    }

    loadOpportunities() {
        this.isLoading = true;
        getOpportunitiesList()
            .then(data => {
                this.opportunities = data;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error cargando oportunidades:', error);
                this.isLoading = false;
            });
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'open_360') {
            this.recordId = event.detail.row.id;
            // Reset state del 360 al abrir una oportunidad
            this.currentStep = '1';
            this.currentSubStep = '1';
        }
    }

    handleNewOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Opportunity',
                actionName: 'new'
            }
        });
    }

    handleBackToDashboard() {
        this.recordId = null;
        this.loadOpportunities();
    }

    // --- LÓGICA DEL EXPEDIENTE 360 ---
    get currentStage() {
        return this.stages.find(s => s.value === this.currentStep);
    }

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

    // Getters para renderizado condicional de Etapas Principales
    get isDefinicion() { return this.currentStep === '1'; }
    get isCosteo() { return this.currentStep === '2'; }
    get isNegociacion() { return this.currentStep === '3'; }
    get isCierre() { return this.currentStep === '4'; }
    get isAltas() { return this.currentStep === '5'; }
    get isOrganizacion() { return this.currentStep === '6'; }

    // Getters para renderizado de Sub-Etapas (Ejemplo de uso dinámico)
    get subPhase() {
        const sub = this.currentSubStages.find(ss => ss.value === this.currentSubStep);
        return sub ? sub.label : '';
    }

    get isFirstStep() { return this.currentStep === '1' && this.currentSubStep === '1'; }
    get isLastStep() { 
        const lastStage = this.stages[this.stages.length - 1];
        return this.currentStep === lastStage.value && this.currentSubStep === lastStage.subStages.length.toString();
    }

    handleStepClick(event) {
        this.currentStep = event.target.value;
        this.currentSubStep = '1'; // Reset a la primera sub-etapa al cambiar de etapa
    }

    handleSubStepClick(event) {
        this.currentSubStep = event.target.dataset.id;
    }

    handleNext() {
        const maxSubSteps = this.currentSubStages.length;
        let nextSub = parseInt(this.currentSubStep) + 1;

        if (nextSub <= maxSubSteps) {
            this.currentSubStep = nextSub.toString();
        } else {
            let nextStep = parseInt(this.currentStep) + 1;
            if (nextStep <= 6) {
                this.currentStep = nextStep.toString();
                this.currentSubStep = '1';
            }
        }
    }

    handlePrev() {
        let prevSub = parseInt(this.currentSubStep) - 1;

        if (prevSub >= 1) {
            this.currentSubStep = prevSub.toString();
        } else {
            let prevStep = parseInt(this.currentStep) - 1;
            if (prevStep >= 1) {
                this.currentStep = prevStep.toString();
                const prevStage = this.stages.find(s => s.value === this.currentStep);
                this.currentSubStep = prevStage.subStages.length.toString();
            }
        }
    }
}
