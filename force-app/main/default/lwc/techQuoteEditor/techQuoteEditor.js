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
import getSedeContacts from '@salesforce/apex/QuoteTechnicalController.getSedeContacts';
import validatePLPassword from '@salesforce/apex/QuoteTechnicalController.validatePLPassword';
import getProductPrices from '@salesforce/apex/QuoteTechnicalController.getProductPrices';
import getFilteredSedes from '@salesforce/apex/QuoteTechnicalController.getFilteredSedes';
import searchParentAccounts from '@salesforce/apex/QuoteTechnicalController.searchParentAccounts';
import cloneQuote from '@salesforce/apex/QuoteTechnicalController.cloneQuote';

export default class TechQuoteEditor extends NavigationMixin(LightningElement) {
    @api recordId;
    
    _opportunityId;
    @api 
    get opportunityId() { return this._opportunityId; }
    set opportunityId(value) {
        this._opportunityId = value;
        if (value) {
            this.parentOpportunityId = value;
        }
    }

    @track parentOpportunityId;
    @track currentStep = '1';
    @track isLoading = false;

    // --- DATOS PRESUPUESTO ---
    @track folio = 'POR GENERAR';
    @track asunto = '';
    @track opportunityName = ''; 
    @track introduccion = '';
    @track warranty = '';
    @track observacionesPago = '';
    @track agenteNombre = '';
    @track clienteNombre = 'SIN CLIENTE';
    @track accountId;

    // --- CONTACTOS ---
    @track contactOptions = [];
    @track selectedContactIds = []; 
    @track selectedContactNames = ''; 

    // --- VARIABLES DE PAGO ---
    @track pagoTransferencia = false;
    @track pagoTarjeta = false;
    @track trabajoPuntual = false;
    @track ventaProducto = false;
    @track trabajoMantenimiento = false;

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
    @track selectedSedesObjects = [];
    @track sedeSearchTerm = '';
    @track isGlobalSedeSearch = false;

    // --- SERVICIOS Y ARTÍCULOS ---
    @track serviciosData = [];
    @track totalesData = [];
    @track selectedLines = [];
    @track lineaNegocioOptions = [];
    @track allowOtherLines = false;
    
    // --- MODALES ---
    @track showModal = false;
    @track itemToEdit = null;
    @track showSeparatorModal = false;
    @track showPLModal = false;
    @track showPdfModal = false;
    @track pdfUrl = '';
    @track separatorText = '';

    sedesColumns = [
        { label: 'Sede', fieldName: 'Name', type: 'text' },
        { label: 'Cuenta Padre', fieldName: 'ParentName', type: 'text' },
        { label: 'Dirección', fieldName: 'BillingStreet', type: 'text' },
        { label: 'Ciudad', fieldName: 'BillingCity', type: 'text' }
    ];

    totalesColumns = [
        { label: 'Impuestos', fieldName: 'impuestosNom', type: 'text' },
        { label: 'Base gravable', fieldName: 'base', type: 'currency' },
        { label: 'Impuesto', fieldName: 'valorImpuesto', type: 'currency' },
        { label: 'Total', fieldName: 'total', type: 'currency', cellAttributes: { class: 'slds-text-title_bold' } }
    ];

    connectedCallback() {
        if (this.opportunityId) this.parentOpportunityId = this.opportunityId;
        this.loadInitialData();
        this.loadBusinessLines();
        this.loadTemplates();
    }

    loadInitialData() {
        this.isLoading = true;
        const searchId = this.recordId ? this.recordId : this.opportunityId;
        getInitialData({ recordId: searchId })
            .then(result => {
                if (result.agenteNombre) this.agenteNombre = result.agenteNombre;
                if (result.opportunityName) this.opportunityName = result.opportunityName;
                if (result.quote) {
                    const q = result.quote;
                    this.folio = q.QuoteNumber;
                    this.asunto = q.Name;
                    this.introduccion = q.Introduction_Text__c;
                    this.warranty = q.Warranty_Text__c;
                    this.accountId = q.AccountId;
                    this.parentOpportunityId = q.OpportunityId;
                    if (q.Account) this.clienteNombre = q.Account.Name;
                    if (q.Markers_Data__c) {
                        try {
                            const decoded = JSON.parse(decodeURIComponent(escape(window.atob(q.Markers_Data__c))));
                            if (decoded.serviciosData) this.serviciosData = decoded.serviciosData;
                            if (decoded.selectedSedesIds) this.selectedSedesIds = decoded.selectedSedesIds;
                            if (decoded.selectedSedesObjects) this.selectedSedesObjects = decoded.selectedSedesObjects;
                            if (decoded.estrategiaVenta) this.estrategiaVenta = decoded.estrategiaVenta;
                            if (decoded.selectedContactIds) this.selectedContactIds = decoded.selectedContactIds;
                            if (decoded.selectedContactNames) this.selectedContactNames = decoded.selectedContactNames;
                            if (decoded.selectedLines) {
                                this.selectedLines = decoded.selectedLines;
                                this.loadBusinessLines();
                            }
                            if (decoded.pagoTransferencia !== undefined) this.pagoTransferencia = decoded.pagoTransferencia;
                            if (decoded.pagoTarjeta !== undefined) this.pagoTarjeta = decoded.pagoTarjeta;
                            if (decoded.trabajoPuntual !== undefined) this.trabajoPuntual = decoded.trabajoPuntual;
                            if (decoded.ventaProducto !== undefined) this.ventaProducto = decoded.ventaProducto;
                            if (decoded.trabajoMantenimiento !== undefined) this.trabajoMantenimiento = decoded.trabajoMantenimiento;
                            if (decoded.necesidadId) {
                                this.necesidadId = decoded.necesidadId;
                                this.necesidadNombre = decoded.necesidadNombre;
                                this.necesidadSeleccionada = decoded.necesidadNombre;
                            }
                            this.calculateTotals();
                            if (this.selectedSedesIds.length > 0) this.fetchContacts(this.selectedSedesIds[0]);
                        } catch (e) { console.error('Error parse markers:', e); }
                    }
                } else if (result.opportunity) {
                    this.accountId = result.opportunity.AccountId;
                    this.parentOpportunityId = result.opportunity.Id;
                    this.autoFillAsunto();
                }
                if (this.accountId) this.fetchSedes();
                this.isLoading = false;
            })
            .catch(error => { console.error(error); this.isLoading = false; });
    }

    loadBusinessLines() { getBusinessLineOptions().then(res => { this.lineaNegocioOptions = res; }); }
    loadTemplates() {
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Introducciones' }).then(res => this.introTemplates = res);
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Clausulas y Anexos' }).then(res => this.warrantyTemplates = res);
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Observaciones de Pago' }).then(res => this.pagoTemplates = res);
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Servicios' }).then(res => this.serviceTemplates = res);
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    handleNext() { 
        if (this.currentStep === '1' && !this.estrategiaVenta) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Atención', message: 'Seleccione una Estrategia.', variant: 'warning' }));
            return;
        }
        if (this.currentStep !== '4') {
            this.handleSave('Borrador');
            const nextStepInt = parseInt(this.currentStep) + 1;
            if (nextStepInt === 4) this.pdfUrl = `/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`;
            this.currentStep = nextStepInt.toString();
        }
    }
    handleBack() { this.currentStep = (parseInt(this.currentStep) - 1).toString(); }

    get estrategiaOptions() {
        return [
            { label: 'E1 - Póliza Anual', value: 'E1' }, { label: 'E2 - Extraordinario', value: 'E2' },
            { label: 'E3 - Cliente Nuevo', value: 'E3' }, { label: 'E4 - Retardantes', value: 'E4' }, { label: 'E5 - Cedis', value: 'E5' }
        ];
    }

    get sedeScopeLabel() { return this.isGlobalSedeSearch ? 'Búsqueda Global' : 'Solo este Cliente'; }
    get sedeSearchPlaceholder() { return this.isGlobalSedeSearch ? 'Buscar en todo Salesforce...' : 'Filtrar sedes de este cliente...'; }
    get maxRowSelection() { return this.estrategiaVenta === 'E5' ? 200 : 1; }
    get technicalSedesString() { return this.selectedSedesObjects.map(s => s.Name).join(', '); }

    handleEstrategiaChange(event) { this.estrategiaVenta = event.target.value; this.autoFillAsunto(); }
    autoFillAsunto() {
        const folioDisplay = this.folio || 'POR GENERAR';
        const oppName = this.opportunityName || 'Sin Oportunidad';
        this.asunto = `PYATZ - Ptto ${folioDisplay} - ${oppName}`;
    }

    handleSedeScopeChange(event) { this.isGlobalSedeSearch = event.target.checked; this.fetchSedes(); }
    handleSedeSearch(event) { this.sedeSearchTerm = event.target.value; this.fetchSedes(); }
    fetchSedes() {
        getFilteredSedes({ searchTerm: this.sedeSearchTerm, parentAccountId: this.accountId, isGlobal: this.isGlobalSedeSearch })
        .then(res => { this.sedesData = res.map(s => ({ ...s, ParentName: s.Parent ? s.Parent.Name : this.clienteNombre })); })
        .catch(err => console.error(err));
    }

    handleSedeSelection(event) {
        const newSelectedRows = event.detail.selectedRows;
        let currentObjects = [...this.selectedSedesObjects];
        newSelectedRows.forEach(row => { if (!currentObjects.some(obj => obj.Id === row.Id)) currentObjects.push(row); });
        if (this.estrategiaVenta !== 'E5' && currentObjects.length > 1) currentObjects = [currentObjects[currentObjects.length - 1]];
        this.selectedSedesObjects = currentObjects;
        this.selectedSedesIds = currentObjects.map(s => s.Id);
        if (currentObjects.length > 0) this.fetchContacts(currentObjects[0].Id);
        else { this.contactOptions = []; this.selectedContactIds = []; this.selectedContactNames = ''; }
    }

    handleContactChange(event) {
        this.selectedContactIds = event.detail.value;
        const selected = this.contactOptions.filter(opt => this.selectedContactIds.includes(opt.value));
        if (selected.length > 0) {
            const names = selected.map(s => s.name);
            if (names.length === 1) this.selectedContactNames = names[0];
            else if (names.length === 2) this.selectedContactNames = `${names[0]} y ${names[1]}`;
            else { const last = names.pop(); this.selectedContactNames = `${names.join(', ')} y ${last}`; }
            this.updateIntroWithContacts();
        } else this.selectedContactNames = '';
    }

    updateIntroWithContacts() {
        if (!this.introduccion) return;
        const patterns = [/\[\[ATENCION\]\]/g, /Estimad@\s*,/g, /Estimado\/a\s*,/g, /Estimado\(a\)\s*,/g];
        let newIntro = this.introduccion;
        const displayNames = this.selectedContactNames || 'a quien corresponda';
        let replaced = false;
        patterns.forEach(pattern => {
            if (newIntro.match(pattern)) { newIntro = newIntro.replace(pattern, `${this.selectedContactNames ? displayNames : 'a quien corresponda'}`); replaced = true; }
        });
        if (replaced) this.introduccion = newIntro;
    }

    fetchContacts(sedeId) {
        getSedeContacts({ sedeId: sedeId })
            .then(res => { this.contactOptions = res; if (this.selectedContactIds.length > 0) this.handleContactChange({ detail: { value: this.selectedContactIds } }); })
            .catch(err => console.error('Error contactos:', err));
    }

    handleRemoveSedePill(event) {
        this.selectedSedesObjects = this.selectedSedesObjects.filter(s => s.Id !== event.target.name);
        this.selectedSedesIds = this.selectedSedesObjects.map(s => s.Id);
        if (this.selectedSedesObjects.length === 0) { this.contactOptions = []; this.selectedContactIds = []; this.selectedContactNames = ''; }
    }

    handleLineChange(event) {
        const line = event.target.dataset.value;
        this.lineaNegocioOptions = this.lineaNegocioOptions.map(opt => (opt.value === line ? { ...opt, checked: event.target.checked } : opt));
        this.selectedLines = this.lineaNegocioOptions.filter(opt => opt.checked).map(opt => opt.value);
    }

    handleSave(status) {
        this.isLoading = true;
        const markers = { 
            serviciosData: this.serviciosData, selectedSedesIds: this.selectedSedesIds, selectedSedesObjects: this.selectedSedesObjects, 
            estrategiaVenta: this.estrategiaVenta, necesidadId: this.necesidadId, necesidadNombre: this.necesidadNombre, 
            pagoTransferencia: this.pagoTransferencia, pagoTarjeta: this.pagoTarjeta, trabajoPuntual: this.trabajoPuntual, 
            ventaProducto: this.ventaProducto, trabajoMantenimiento: this.trabajoMantenimiento, observacionesPago: this.observacionesPago,
            selectedContactIds: this.selectedContactIds, selectedContactNames: this.selectedContactNames
        };
        const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
        const payload = {
            quoteId: this.recordId, opportunityId: this.parentOpportunityId, contactId: this.selectedContactIds.length > 0 ? this.selectedContactIds[0] : null,
            name: this.asunto, status: status, intro: this.introduccion, warranty: this.warranty, observacionesPago: this.observacionesPago,
            markersData: encoded, technicalSedes: this.selectedSedesObjects.map(s => s.Name).join(', '),
            lineItems: JSON.stringify(this.serviciosData), showIntro: true, showWarranty: true
        };
        saveTechnicalData({ data: payload })
            .then(newId => { if (newId) this.recordId = newId; this.loadInitialData(); this.isLoading = false; if (status === 'Approved') this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Presupuesto finalizado', variant: 'success' })); })
            .catch(error => { this.isLoading = false; console.error(error); });
    }

    handleAddServiceItems(event) {
        const newItems = event.detail;
        if (this.itemToEdit) {
            // Reemplazar el item editado manteniendo su posición
            this.serviciosData = this.serviciosData.map(item => item.id === this.itemToEdit.id ? newItems[0] : item);
        } else {
            // Añadir nuevos items
            this.serviciosData = [...this.serviciosData, ...newItems];
        }
        this.calculateTotals();
        this.showModal = false;
        this.itemToEdit = null;
    }

    calculateTotals() {
        let subtotal = 0;
        this.serviciosData.forEach(item => { if (!item.isSeparator) subtotal += (item.totalSinImpuestos || 0); });
        const iva = subtotal * 0.16;
        this.totalesData = [{ id: 'total-1', impuestosNom: 'IVA (16%)', base: subtotal, valorImpuesto: iva, total: subtotal + iva }];
    }

    handleRowAction(event) {
        const action = event.target.dataset.action;
        const id = event.target.dataset.id;
        if (action === 'delete') {
            this.serviciosData = this.serviciosData.filter(item => item.id !== id);
            this.calculateTotals();
        } else if (action === 'edit') {
            this.itemToEdit = this.serviciosData.find(item => item.id === id);
            this.showModal = true;
        }
    }

    handleOpenModal() { this.itemToEdit = null; this.showModal = true; }
    handleCloseModal() { this.showModal = false; this.itemToEdit = null; }

    handleApplyTemplate(event) {
        const templateId = event.detail.value;
        const targetField = event.target.dataset.field || event.currentTarget.dataset.field;
        if (!this.recordId) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Atención', message: 'Guarde el presupuesto antes para poder procesar la plantilla.', variant: 'warning' }));
            return;
        }
        this.isLoading = true;
        renderTemplate({ templateId: templateId, quoteId: this.recordId })
            .then(result => {
                if (targetField === 'introduccion') this.introduccion = result;
                else if (targetField === 'warranty') this.warranty = result;
                else if (targetField === 'observacionesPago') this.observacionesPago = result;
                this.isLoading = false;
            })
            .catch(error => { this.isLoading = false; console.error('Error render:', error); });
    }

    handleFinalize() { this.handleSave('Approved'); }
    handleGoToContract() { this.dispatchEvent(new CustomEvent('viewcontract', { detail: this.recordId })); }
    handleCancel() { this.dispatchEvent(new CustomEvent('cancel')); }
    handlePreviewPdf() { this.handleSave('Borrador'); this.pdfUrl = `/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`; this.showPdfModal = true; }
    handleClosePdfModal() { this.showPdfModal = false; this.pdfUrl = ''; }
    
    handleAsuntoChange(event) { this.asunto = event.target.value; }
    handleIntroChange(event) { this.introduccion = event.target.value; }
    handleWarrantyChange(event) { this.warranty = event.target.value; }
    handleObservacionesPagoChange(event) { this.observacionesPago = event.target.value; }
    handlePagoTransferenciaChange(event) { this.pagoTransferencia = event.target.checked; }
    handlePagoTarjetaChange(event) { this.pagoTarjeta = event.target.checked; }
    handleVentaProductoChange(event) { this.ventaProducto = event.target.checked; }
    handleTrabajoMantenimientoChange(event) { this.trabajoMantenimiento = event.target.checked; }

    handleOpenSeparatorModal() { this.showSeparatorModal = true; }
    handleCloseSeparatorModal() { this.showSeparatorModal = false; }
    handleSeparatorTextChange(event) { this.separatorText = event.target.value; }
    handleAddSeparator() {
        this.serviciosData = [...this.serviciosData, { id: Date.now().toString(), isSeparator: true, descripcion: this.separatorText || 'SECCIÓN', rowClass: 'row-separator' }];
        this.showSeparatorModal = false;
        this.separatorText = '';
    }
    handleOpenPLModal() { this.showPLModal = true; }
    handleClosePLModal() { this.showPLModal = false; }
}