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
    
    // --- MODAL BUSCADOR PRO (LÓGICA V1) ---
    @track searchResults = [];
    @track selectedProductId = '';
    @track selectedPbeId = ''; // Nuevo: Almacena el ID de la lista de precios
    @track selectedProductName = '';
    @track selectedProductPrice = 0;
    @track productPriceOptions = [];
    @track modalTableData = []; 
    @track modalDescription = '';
    @track isUnitario = true;
    @track isTotal = false;
    @track showDiscountColumn = false;
    @track zonaInput = '';
    @track zonasAfectadas = [];
    @track showIndicaciones = false;
    @track modalSedeSearchTerm = '';
    
    // --- CONFIGURACIÓN PDF ---
    @track showTotal = true;
    @track showTaxes = true;
    @track showDescription = true;

    // --- MODALES ---
    @track showModal = false;
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
                            if (decoded.selectedSedesObjects) this.selectedSedesObjects = decoded.selectedSedesObjects;
                            if (decoded.estrategiaVenta) this.estrategiaVenta = decoded.estrategiaVenta;
                            if (decoded.necesidadId) {
                                this.necesidadId = decoded.necesidadId;
                                this.necesidadNombre = decoded.necesidadNombre;
                                this.necesidadSeleccionada = decoded.necesidadNombre;
                            }
                            this.calculateTotals();
                        } catch (e) { console.error('Error parse markers:', e); }
                    }
                } else if (result.opportunity) {
                    this.accountId = result.opportunity.AccountId;
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

    // --- NAVEGACIÓN ---
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
            this.isLoading = true;
            
            // 1. Preparar Payload Maestro
            const markers = { 
                serviciosData: this.serviciosData, 
                selectedSedesIds: this.selectedSedesIds, 
                selectedSedesObjects: this.selectedSedesObjects, 
                estrategiaVenta: this.estrategiaVenta, 
                necesidadId: this.necesidadId, 
                necesidadNombre: this.necesidadNombre, 
                pagoTransferencia: this.pagoTransferencia, 
                pagoTarjeta: this.pagoTarjeta, 
                trabajoPuntual: this.trabajoPuntual, 
                ventaProducto: this.ventaProducto, 
                trabajoMantenimiento: this.trabajoMantenimiento, 
                observacionesPago: this.observacionesPago 
            };
            const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
            
            const payload = {
                quoteId: this.recordId,
                name: this.asunto,
                status: 'Borrador',
                intro: this.introduccion,
                warranty: this.warranty,
                observacionesPago: this.observacionesPago,
                markersData: encoded,
                technicalSedes: this.technicalSedesString,
                lineItems: JSON.stringify(this.serviciosData),
                showIntro: true,
                showWarranty: true
            };

            // 2. Guardar y esperar respuesta antes de avanzar
            saveTechnicalData({ data: payload })
                .then(newId => {
                    if (newId) this.recordId = newId;
                    this.loadInitialData(); // Refrescar para tener el Folio real
                    
                    // Si el siguiente paso es el 4, generamos la URL del PDF profesional
                    const nextStepInt = parseInt(this.currentStep) + 1;
                    if (nextStepInt === 4) {
                        this.pdfUrl = `/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`;
                    }
                    
                    this.currentStep = nextStepInt.toString();
                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                    console.error('Error al avanzar:', error);
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo guardar el registro. Verifique su conexión.', variant: 'error' }));
                });
        }
    }
    handleBack() { this.currentStep = (parseInt(this.currentStep) - 1).toString(); }

    // --- LÓGICA PASO 1 ---
    get estrategiaOptions() {
        return [
            { label: 'E1 - Póliza Anual', value: 'E1' }, { label: 'E2 - Extraordinario', value: 'E2' },
            { label: 'E3 - Cliente Nuevo', value: 'E3' }, { label: 'E4 - Retardantes', value: 'E4' }, { label: 'E5 - Cedis', value: 'E5' }
        ];
    }
    handleEstrategiaChange(event) { this.estrategiaVenta = event.target.value; this.autoFillAsunto(); }
    
    autoFillAsunto() {
        const est = this.estrategiaOptions.find(o => o.value === this.estrategiaVenta)?.label || '';
        this.asunto = `${est} @ Servicio Técnico`;
    }

    // --- LÓGICA PASO 2 ---
    get sedeScopeLabel() { return this.isGlobalSedeSearch ? 'Búsqueda Global' : 'Solo este Cliente'; }
    get sedeSearchPlaceholder() { return this.isGlobalSedeSearch ? 'Buscar en todo Salesforce...' : 'Filtrar sedes de este cliente...'; }
    get maxRowSelection() { return this.estrategiaVenta === 'E5' ? 200 : 1; }
    get technicalSedesString() { return this.selectedSedesObjects.map(s => s.Name).join(', '); }

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
    }
    handleRemoveSedePill(event) {
        this.selectedSedesObjects = this.selectedSedesObjects.filter(s => s.Id !== event.target.name);
        this.selectedSedesIds = this.selectedSedesObjects.map(s => s.Id);
    }
    handleLineChange(event) {
        const line = event.target.dataset.value;
        this.lineaNegocioOptions = this.lineaNegocioOptions.map(opt => (opt.value === line ? { ...opt, checked: event.target.checked } : opt));
        this.selectedLines = this.lineaNegocioOptions.filter(opt => opt.checked).map(opt => opt.value);
    }

    // --- LÓGICA PAGO ---
    handlePagoTransferenciaChange(event) { this.pagoTransferencia = event.target.checked; }
    handlePagoTarjetaChange(event) { this.pagoTarjeta = event.target.checked; }
    handleTrabajoPuntualChange(event) { this.trabajoPuntual = event.target.checked; }
    handleVentaProductoChange(event) { this.ventaProducto = event.target.checked; }
    handleTrabajoMantenimientoChange(event) { this.trabajoMantenimiento = event.target.checked; }

    // --- LÓGICA PASO 3 (MODAL V1) ---
    get isUnitarioVariant() { return this.isUnitario ? 'brand' : 'neutral'; }
    get isTotalVariant() { return this.isTotal ? 'brand' : 'neutral'; }
    get dropdownIcon() { return this.showIndicaciones ? 'utility:chevrondown' : 'utility:chevronright'; }

    handleAllowOtherLinesChange(event) { this.allowOtherLines = event.target.checked; }
    
    handleProductSearch(event) {
        const term = event.target.value;
        this.selectedProductName = term;
        if (term.length >= 3) {
            searchProducts({ searchTerm: term, quoteId: this.recordId, businessLines: this.selectedLines, allowOtherLines: this.allowOtherLines })
                .then(res => { this.searchResults = res; })
                .catch(err => console.error(err));
        } else this.searchResults = [];
    }

    handleProductSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const res = this.searchResults.find(x => x.id === selectedId);
        if (res) {
            this.selectedPbeId = selectedId; // Capturar el ID de Salesforce (PricebookEntry)
            this.selectedProductId = res.productId;
            this.selectedProductName = res.name;
            this.selectedProductPrice = res.unitPrice;
            this.modalDescription = res.description;
            this.searchResults = [];
            this.loadProductPrices();
            this.initModalTable();
        }
    }

    loadProductPrices() {
        getProductPrices({ product2Id: this.selectedProductId }).then(res => { 
            this.productPriceOptions = res.map(opt => ({
                ...opt,
                className: opt.pbeId === this.selectedPbeId ? 'price-option-card selected' : 'price-option-card'
            })); 
        });
    }

    initModalTable() {
        this.modalTableData = this.selectedSedesObjects.map(s => ({
            id: s.Id, sede: s.Name, isSelected: true, cantidad: 1, importeTotal: this.selectedProductPrice, descuento: 0, tipoDescuento: 'monto', totalSinImpuestos: this.selectedProductPrice, impuestos: 16
        }));
    }

    handlePriceOptionSelect(event) {
        const pbeId = event.currentTarget.dataset.id;
        const opt = this.productPriceOptions.find(o => o.pbeId === pbeId);
        if (opt) {
            this.selectedPbeId = pbeId; // Actualizar con el nuevo ID de precio seleccionado
            this.selectedProductPrice = opt.unitPrice;
            this.productPriceOptions = this.productPriceOptions.map(o => ({ ...o, className: o.pbeId === pbeId ? 'price-option-card selected' : 'price-option-card' }));
            this.recalculateModalData();
        }
    }

    handlePriceType(event) {
        const type = event.target.value;
        this.isUnitario = (type === 'UNITARIO');
        this.isTotal = !this.isUnitario;
        this.recalculateModalData();
    }

    handleToggleDiscountColumn() { this.showDiscountColumn = !this.showDiscountColumn; }

    handleSedeRowToggle(event) {
        const id = event.target.dataset.id;
        this.modalTableData = this.modalTableData.map(row => (row.id === id ? { ...row, isSelected: event.target.checked, isDisabled: !event.target.checked } : row));
    }

    handleModalInputChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const val = field === 'tipoDescuento' ? event.target.value : (parseFloat(event.target.value) || 0);
        this.modalTableData = this.modalTableData.map(row => {
            if (row.id === id) {
                let newRow = { ...row, [field]: val };
                return newRow;
            }
            return row;
        });
        this.recalculateModalData();
    }

    recalculateModalData() {
        this.modalTableData = this.modalTableData.map(row => {
            let newRow = { ...row, importeTotal: this.selectedProductPrice };
            let base = this.isUnitario ? (newRow.importeTotal * newRow.cantidad) : newRow.importeTotal;
            newRow.totalSinImpuestos = base - (newRow.descuento || 0);
            return newRow;
        });
    }

    toggleIndicaciones() { this.showIndicaciones = !this.showIndicaciones; }
    handleZonaInput(event) {
        const value = event.target.value;
        if (value.endsWith(',')) {
            const newZona = value.slice(0, -1).trim();
            if (newZona && !this.zonasAfectadas.includes(newZona)) this.zonasAfectadas = [...this.zonasAfectadas, newZona];
            this.zonaInput = '';
        } else this.zonaInput = value;
    }
    removeZona(event) { this.zonasAfectadas = this.zonasAfectadas.filter(z => z !== event.target.dataset.name); }

    handleModalDescriptionChange(event) { this.modalDescription = event.target.value; }

    handleSaveServiceLine() {
        const selectedRows = this.modalTableData.filter(r => r.isSelected);
        if (selectedRows.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Atención', message: 'Seleccione al menos una sede.', variant: 'warning' }));
            return;
        }

        const zonasStr = this.zonasAfectadas.join(', ');

        selectedRows.forEach(row => {
            const newItem = {
                id: Date.now().toString() + Math.random(), // ID visual para la tabla
                pbeId: this.selectedPbeId, // ID real para Salesforce
                descripcion: this.selectedProductName,
                cantidad: row.cantidad,
                totalSinImpuestos: row.totalSinImpuestos,
                sedes: row.sede,
                areas: zonasStr,
                detalleTecnico: this.modalDescription,
                rowClass: 'row-service'
            };
            this.serviciosData = [...this.serviciosData, newItem];
        });

        this.calculateTotals();
        this.showModal = false;
        this.resetModal();
    }

    resetModal() {
        this.selectedProductId = ''; this.selectedProductName = ''; this.modalTableData = []; 
        this.modalDescription = ''; this.zonasAfectadas = []; this.productPriceOptions = []; this.showDiscountColumn = false;
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
        }
    }

    handleDragStart(event) { event.dataTransfer.setData('index', event.currentTarget.dataset.index); }
    handleDragOver(event) { event.preventDefault(); }
    handleDrop(event) {
        const fromIndex = event.dataTransfer.getData('index');
        const toIndex = event.target.closest('tr').dataset.index;
        if (fromIndex === toIndex) return;
        const data = [...this.serviciosData];
        const item = data.splice(fromIndex, 1)[0];
        data.splice(toIndex, 0, item);
        this.serviciosData = data;
    }

    handleOpenModal() { this.showModal = true; }
    handleCloseModal() { this.showModal = false; this.resetModal(); }
    handleOpenSeparatorModal() { this.showSeparatorModal = true; }
    handleCloseSeparatorModal() { this.showSeparatorModal = false; }
    handleSeparatorTextChange(event) { this.separatorText = event.target.value; }
    handleAddSeparator() {
        const newSep = { id: Date.now().toString(), isSeparator: true, descripcion: this.separatorText || 'SECCIÓN', rowClass: 'row-separator' };
        this.serviciosData = [...this.serviciosData, newSep];
        this.showSeparatorModal = false;
        this.separatorText = '';
    }

    handleShowTotalChange(event) { this.showTotal = event.target.checked; }
    handleShowTaxesChange(event) { this.showTaxes = event.target.checked; }
    handleShowDescriptionChange(event) { this.showDescription = event.target.checked; }
    handleWarrantyChange(event) { this.warranty = event.target.value; }
    handleObservacionesPagoChange(event) { this.observacionesPago = event.target.value; }
    handleAsuntoChange(event) { this.asunto = event.target.value; }
    handleIntroChange(event) { this.introduccion = event.target.value; }

    handleApplyTemplate(event) {
        const templateId = event.detail.value;
        // Lógica robusta para detectar el campo de destino en cualquier menú del componente
        const targetField = event.currentTarget.getAttribute('data-field') || event.target.dataset.field;

        if (!this.recordId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Atención',
                message: 'Guarde el presupuesto antes de aplicar plantillas.',
                variant: 'warning'
            }));
            return;
        }

        this.isLoading = true;
        renderTemplate({ templateId: templateId, quoteId: this.recordId })
            .then(result => {
                if (targetField === 'introduccion') this.introduccion = result;
                else if (targetField === 'warranty') this.warranty = result;
                else if (targetField === 'observacionesPago') this.observacionesPago = result;
                else if (targetField === 'modalDescription') this.modalDescription = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error aplicando plantilla:', error);
            });
    }

    handleSave(status) {
        this.isLoading = true;
        
        // 1. Preparar la memoria técnica (Markers)
        const markers = { 
            serviciosData: this.serviciosData, 
            selectedSedesIds: this.selectedSedesIds, 
            selectedSedesObjects: this.selectedSedesObjects, 
            estrategiaVenta: this.estrategiaVenta, 
            necesidadId: this.necesidadId, 
            necesidadNombre: this.necesidadNombre, 
            pagoTransferencia: this.pagoTransferencia, 
            pagoTarjeta: this.pagoTarjeta, 
            trabajoPuntual: this.trabajoPuntual, 
            ventaProducto: this.ventaProducto, 
            trabajoMantenimiento: this.trabajoMantenimiento, 
            observacionesPago: this.observacionesPago 
        };
        const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
        
        // 2. Preparar el Payload Maestro alineado a campos reales de Pyatz
        const payload = {
            quoteId: this.recordId,
            name: this.asunto,
            status: status,
            intro: this.introduccion,
            warranty: this.warranty,
            observacionesPago: this.observacionesPago,
            markersData: encoded,
            technicalSedes: this.technicalSedesString,
            lineItems: JSON.stringify(this.serviciosData), // Enviar servicios para crear QuoteLineItems
            showIntro: true,
            showWarranty: true
        };

        saveTechnicalData({ data: payload })
            .then(newId => {
                if (newId) this.recordId = newId;
                this.loadInitialData();
                this.isLoading = false;
                if (status === 'Approved') {
                    this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Presupuesto finalizado y sincronizado', variant: 'success' }));
                }
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error sincronización:', error);
            });
    }

    handleFinalize() { this.handleSave('Approved'); }
    handleGoToContract() { this.dispatchEvent(new CustomEvent('viewcontract', { detail: this.recordId })); }
    handleCancel() { this.dispatchEvent(new CustomEvent('cancel')); }
    handleCloneQuote() { cloneQuote({ quoteId: this.recordId }).then(newId => { this.dispatchEvent(new CustomEvent('editquote', { detail: newId })); }); }
    handleOpenPLModal() { this.showPLModal = true; }
    handleClosePLModal() { this.showPLModal = false; }

    handlePreviewPdf() {
        this.isLoading = true;
        
        const markers = { 
            serviciosData: this.serviciosData, 
            selectedSedesIds: this.selectedSedesIds, 
            selectedSedesObjects: this.selectedSedesObjects, 
            estrategiaVenta: this.estrategiaVenta, 
            necesidadId: this.necesidadId, 
            necesidadNombre: this.necesidadNombre, 
            pagoTransferencia: this.pagoTransferencia, 
            pagoTarjeta: this.pagoTarjeta, 
            trabajoPuntual: this.trabajoPuntual, 
            ventaProducto: this.ventaProducto, 
            trabajoMantenimiento: this.trabajoMantenimiento, 
            observacionesPago: this.observacionesPago 
        };
        const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
        
        const payload = {
            quoteId: this.recordId,
            name: this.asunto,
            status: 'Borrador',
            intro: this.introduccion,
            warranty: this.warranty,
            observacionesPago: this.observacionesPago,
            markersData: encoded,
            technicalSedes: this.technicalSedesString,
            lineItems: JSON.stringify(this.serviciosData),
            showIntro: true,
            showWarranty: true
        };

        saveTechnicalData({ data: payload })
            .then(newId => {
                if (newId) this.recordId = newId;
                this.pdfUrl = `/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`;
                this.showPdfModal = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error vista previa:', error);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo generar la vista previa.', variant: 'error' }));
            });
    }

    handleClosePdfModal() {
        this.showPdfModal = false;
        this.pdfUrl = '';
    }
}