import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitialData from '@salesforce/apex/QuoteTechnicalController.getInitialData';
import saveTechnicalData from '@salesforce/apex/QuoteTechnicalController.saveTechnicalData';
import searchProducts from '@salesforce/apex/QuoteTechnicalController.searchProducts';
import getBusinessLineOptions from '@salesforce/apex/QuoteTechnicalController.getBusinessLineOptions';
import searchNecesidades from '@salesforce/apex/QuoteTechnicalController.searchNecesidades';
import getEmailTemplatesByFolder from '@salesforce/apex/QuoteTechnicalController.getEmailTemplatesByFolder';
import renderTemplate from '@salesforce/apex/QuoteTechnicalController.renderTemplate';
import validatePLPassword from '@salesforce/apex/QuoteTechnicalController.validatePLPassword';
import getProductPrices from '@salesforce/apex/QuoteTechnicalController.getProductPrices';
import getFilteredSedes from '@salesforce/apex/QuoteTechnicalController.getFilteredSedes';
import searchParentAccounts from '@salesforce/apex/QuoteTechnicalController.searchParentAccounts';
import cloneQuote from '@salesforce/apex/QuoteTechnicalController.cloneQuote';

export default class TechQuoteEditor extends NavigationMixin(LightningElement) {
    @api recordId;
    @track currentStep = '1';
    @track isLoading = false;

    // --- DATOS PRESUPUESTO ---
    @track folio = 'POR GENERAR';
    @track asunto = '';
    @track introduccion = '';
    @track warranty = '';
    @track observacionesPago = '';
    @track agenteNombre = '';
    @track clienteNombre = 'SIN CLIENTE';
    @track accountId;

    // --- TEMPLATES ---
    @track introTemplates = [];
    @track warrantyTemplates = [];
    @track pagoTemplates = [];
    @track serviceTemplates = [];

    // --- ESTRATEGIA Y NECESIDAD ---
    @track estrategiaVenta = '';
    @track necesidadId = '';
    @track necesidadNombre = '';
    @track necesidadSeleccionada = '';
    @track necesidadesResults = [];

    // --- SEDES ---
    @track sedesData = [];
    @track selectedSedesIds = [];
    @track sedeSearchTerm = '';
    @track isGlobalSedeSearch = false;
    @track parentSearchTerm = '';
    @track parentSearchResults = [];
    @track selectedParentId = '';
    @track selectedParentName = '';

    // --- SERVICIOS Y ARTÍCULOS ---
    @track serviciosData = [];
    @track selectedLines = [];
    @track lineaNegocioOptions = [];
    @track allowOtherLines = false;

    // --- MODALES ---
    @track showModal = false;
    @track showSeparatorModal = false;
    @track showPLModal = false;
    @track showPasswordModal = false;
    @track isPLAuthenticated = false;
    @track passwordInput = '';

    // --- CONFIGURACIÓN PDF ---
    @track showTotal = true;
    @track showTaxes = true;
    @track showLineItems = true;
    @track showDescription = true;

    // --- P&L ---
    @track pl1 = { costo: 0, margen: 25, indirecto: 15, comision1: 2, comision2: 0, regalia: 5, dias: 7 };
    @track pl2 = { costo: 0, margen: 41, indirecto: 15, comision1: 2, comision2: 0, regalia: 5, dias: 7 };

    sedesColumns = [
        { label: 'Sede', fieldName: 'Name', type: 'text' },
        { label: 'Dirección', fieldName: 'BillingStreet', type: 'text' },
        { label: 'Ciudad', fieldName: 'BillingCity', type: 'text' }
    ];

    connectedCallback() {
        this.loadInitialData();
        this.loadBusinessLines();
        this.loadTemplates();
    }

    loadInitialData() {
        this.isLoading = true;
        getInitialData({ recordId: this.recordId })
            .then(result => {
                if (result.agenteNombre) this.agenteNombre = result.agenteNombre;
                if (result.quote) {
                    const q = result.quote;
                    this.folio = q.QuoteNumber;
                    this.asunto = q.Name;
                    this.introduccion = q.Introduction_Text__c;
                    this.warranty = q.Warranty_Text__c;
                    this.accountId = q.AccountId;
                    if (q.Account) this.clienteNombre = q.Account.Name;

                    if (q.Markers_Data__c) {
                        try {
                            const decoded = JSON.parse(decodeURIComponent(escape(window.atob(q.Markers_Data__c))));
                            if (decoded.serviciosData) this.serviciosData = decoded.serviciosData;
                            if (decoded.selectedSedesIds) this.selectedSedesIds = decoded.selectedSedesIds;
                            if (decoded.estrategiaVenta) this.estrategiaVenta = decoded.estrategiaVenta;
                            if (decoded.necesidadId) {
                                this.necesidadId = decoded.necesidadId;
                                this.necesidadNombre = decoded.necesidadNombre;
                                this.necesidadSeleccionada = decoded.necesidadNombre;
                            }
                        } catch (e) { console.error('Error parse markers:', e); }
                    }
                }
                this.isLoading = false;
            })
            .catch(error => { console.error(error); this.isLoading = false; });
    }

    loadBusinessLines() {
        getBusinessLineOptions().then(res => { this.lineaNegocioOptions = res; });
    }

    loadTemplates() {
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Introducciones' }).then(res => this.introTemplates = res);
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Clausulas y Anexos' }).then(res => this.warrantyTemplates = res);
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Observaciones de Pago' }).then(res => this.pagoTemplates = res);
    }

    // --- NAVEGACIÓN ---
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    handleNext() { 
        // VALIDACIÓN: No permitir avanzar si no hay estrategia elegida en el paso 1
        if (this.currentStep === '1' && !this.estrategiaVenta) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Atención',
                message: 'Por favor, seleccione una Estrategia de Venta antes de continuar.',
                variant: 'warning'
            }));
            return;
        }

        if (this.currentStep !== '4') {
            this.isLoading = true;
            // AUTO-GUARDADO: Esperar a que el guardado sea exitoso para tener el ID real
            const markers = {
                serviciosData: this.serviciosData,
                selectedSedesIds: this.selectedSedesIds,
                estrategiaVenta: this.estrategiaVenta,
                necesidadId: this.necesidadId,
                necesidadNombre: this.necesidadNombre
            };
            const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
            
            const data = {
                quoteId: this.recordId, name: this.asunto, status: 'Borrador',
                intro: this.introduccion, warranty: this.warranty, markersData: encoded
            };

            saveTechnicalData({ data: data })
                .then(newId => {
                    if (newId) this.recordId = newId;
                    this.loadInitialData(); // Refrescar para tener QuoteNumber
                    this.currentStep = (parseInt(this.currentStep) + 1).toString();
                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo guardar el avance', variant: 'error' }));
                });
        }
    }
    handleBack() { this.currentStep = (parseInt(this.currentStep) - 1).toString(); }

    // --- LÓGICA ESTRATEGIA Y NECESIDAD ---
    get estrategiaOptions() {
        return [
            { label: 'E1 - Póliza Anual', value: 'E1' },
            { label: 'E2 - Extraordinario', value: 'E2' },
            { label: 'E3 - Cliente Nuevo', value: 'E3' },
            { label: 'E4 - Retardantes', value: 'E4' },
            { label: 'E5 - Cedis', value: 'E5' }
        ];
    }

    handleEstrategiaChange(event) {
        this.estrategiaVenta = event.target.value;
        this.autoFillAsunto();
    }

    handleNecesidadChange(event) {
        const term = event.target.value;
        this.necesidadSeleccionada = term;
        if (term.length >= 3) {
            searchNecesidades({ searchTerm: term }).then(res => this.necesidadesResults = res);
        } else this.necesidadesResults = [];
    }

    handleNecesidadSelect(event) {
        const nid = event.currentTarget.dataset.id;
        const n = this.necesidadesResults.find(x => x.id === nid);
        if (n) {
            this.necesidadId = nid;
            this.necesidadNombre = n.name;
            this.necesidadSeleccionada = n.name;
            this.necesidadesResults = [];
            this.autoFillAsunto();
        }
    }

    autoFillAsunto() {
        const est = this.estrategiaOptions.find(o => o.value === this.estrategiaVenta)?.label || '';
        this.asunto = `${est} @ ${this.necesidadNombre || 'Servicio Técnico'}`;
    }

    // --- MÉTODOS REQUERIDOS (STUBS PARA FUNCIONALIDAD) ---
    handleAsuntoChange(event) { this.asunto = event.target.value; }
    handleIntroChange(event) { this.introduccion = event.target.value; }
    handleApplyTemplate(event) {
        const tid = event.detail.value;
        const field = event.currentTarget.dataset.field;
        renderTemplate({ templateId: tid, quoteId: this.recordId }).then(res => {
            if (field === 'introduccion') this.introduccion = res;
            if (field === 'warranty') this.warranty = res;
        });
    }

    handleSaveDraft() { this.handleSave('Borrador'); }
    handleFinalize() { this.handleSave('Approved'); }

    get maxRowSelection() {
        // REGLA DE NEGOCIO: Solo Cedis (E5) permite selección múltiple de sedes
        return this.estrategiaVenta === 'E5' ? 200 : 1;
    }

    handleSave(status) {
        this.isLoading = true;
        const markers = {
            serviciosData: this.serviciosData,
            selectedSedesIds: this.selectedSedesIds,
            estrategiaVenta: this.estrategiaVenta,
            necesidadId: this.necesidadId,
            necesidadNombre: this.necesidadNombre
        };
        const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
        
        const data = {
            quoteId: this.recordId, name: this.asunto, status: status,
            intro: this.introduccion, warranty: this.warranty, markersData: encoded
        };

        saveTechnicalData({ data: data })
            .then(newId => {
                this.isLoading = false;
                if (newId) {
                    this.recordId = newId; 
                    // REFRESCAR: Volver a consultar Salesforce para traer el QuoteNumber real
                    this.loadInitialData();
                }
                this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Avance guardado correctamente', variant: 'success' }));
            })
            .catch(error => { console.error(error); this.isLoading = false; });
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('cancel')); }

    handleCloneQuote() {
        this.isLoading = true;
        cloneQuote({ quoteId: this.recordId })
            .then(newId => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Cotización clonada', variant: 'success' }));
                this.dispatchEvent(new CustomEvent('editquote', { detail: newId }));
            })
            .catch(error => { console.error(error); this.isLoading = false; });
    }

    // --- EVENTOS PESTAÑA 3 (STUBS) ---
    handleOpenModal() { this.showModal = true; }
    handleCloseModal() { this.showModal = false; }
    handleOpenPLModal() { this.showPLModal = true; }
    handleClosePLModal() { this.showPLModal = false; }
}