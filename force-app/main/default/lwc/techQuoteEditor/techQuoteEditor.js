import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getInitialData from '@salesforce/apex/QuoteController.getInitialData';
import saveTechnicalData from '@salesforce/apex/QuoteController.saveTechnicalData';
import searchProducts from '@salesforce/apex/QuoteController.searchProducts';
import getBusinessLineOptions from '@salesforce/apex/QuoteController.getBusinessLineOptions';
import searchNecesidades from '@salesforce/apex/QuoteController.searchNecesidades';
import getEmailTemplatesByFolder from '@salesforce/apex/QuoteController.getEmailTemplatesByFolder';
import renderTemplate from '@salesforce/apex/QuoteController.renderTemplate';
import getSedeContacts from '@salesforce/apex/QuoteController.getSedeContacts';
import validatePLPassword from '@salesforce/apex/QuoteController.validatePLPassword';
import getProductPrices from '@salesforce/apex/QuoteController.getProductPrices';
import getFilteredSedes from '@salesforce/apex/QuoteController.getFilteredSedes';
import searchParentAccounts from '@salesforce/apex/QuoteController.searchParentAccounts';
import cloneQuote from '@salesforce/apex/QuoteController.cloneQuote';

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
    @track subestrategiaVenta = '';
    @track subestrategiaOptions = [];
    @track necesidadId = '';
    @track necesidadNombre = '';
    @track necesidadSeleccionada = '';
    @track necesidadesResults = [];

    // --- SEDES ---
    @track sedesData = [];
    @track selectedSedesIds = [];
    @track selectedSedesObjects = [];
    @track sedeSearchTerm = '';
    @track isGlobalSedeSearch = true;

    // --- SERVICIOS Y ARTÍCULOS ---
    @track serviciosData = [];
    @track totalesData = [];
    @track selectedLines = [];
    @track lineaNegocioOptions = [];
    @track allowOtherLines = false;
    @track showSubtotal = true;
    @track showDiscount = true;
    @track showSubtotal2 = true;
    @track showTax = true;
    @track showTotal = true;

    // --- NUEVOS TOTALES PARA LA TABLA ---
    @track calcSubtotal1 = 0;
    @track calcDescuento = 0;
    @track calcSubtotal2 = 0;
    @track calcIva = 0;
    @track calcTotal = 0;

    get hasDescuento() {
        return this.calcDescuento > 0;
    }

    // --- MODALES ---
    @track showModal = false;
    @track itemToEdit = null;
    @track showSeparatorModal = false;
    @track showPLModal = false;
    @track showPdfModal = false;
    @track pdfUrl = '';
    @track separatorText = '';
    @track separatorStyle = 'header';

    sedesColumns = [
        { label: 'Cliente', fieldName: 'Name', type: 'text' },
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

    get storageKey() {
        return `quote_editor_step_${this.recordId || this.opportunityId || 'new'}`;
    }

    connectedCallback() {
        if (this.opportunityId) this.parentOpportunityId = this.opportunityId;
        
        const savedStep = sessionStorage.getItem(this.storageKey);
        if (savedStep) {
            this.currentStep = savedStep === '4' ? '3' : savedStep;
        }

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
                    // Limpieza de ceros a la izquierda para visualización (igual que el PDF)
                    this.folio = (q.QuoteNumber) ? q.QuoteNumber.replace(/^0+/, '') : 'POR GENERAR';
                    this.asunto = q.Name;
                    this.introduccion = q.Introduction_Text__c;
                    this.warranty = q.Warranty_Text__c;
                    this.observacionesPago = q.Description;
                    this.accountId = q.AccountId;
                    this.parentOpportunityId = q.OpportunityId;
                    this.showSubtotal = q.Show_Subtotal__c !== undefined ? q.Show_Subtotal__c : true;
                    this.showDiscount = q.Show_Discount__c !== undefined ? q.Show_Discount__c : true;
                    this.showSubtotal2 = q.Show_Subtotal_2__c !== undefined ? q.Show_Subtotal_2__c : true;
                    this.showTax = q.Show_Tax__c !== undefined ? q.Show_Tax__c : true;
                    this.showTotal = q.Show_Total__c !== undefined ? q.Show_Total__c : true;
                    if (q.Account) this.clienteNombre = q.Account.Name;
                    if (q.Markers_Data__c) {
                        try {
                            const decoded = JSON.parse(decodeURIComponent(escape(window.atob(q.Markers_Data__c))));
                            if (decoded.serviciosData) this.serviciosData = decoded.serviciosData;
                            if (decoded.selectedSedesIds) this.selectedSedesIds = decoded.selectedSedesIds;
                            if (decoded.selectedSedesObjects) this.selectedSedesObjects = decoded.selectedSedesObjects;
                            if (decoded.estrategiaVenta) {
                                this.estrategiaVenta = decoded.estrategiaVenta;
                                this.updateSubestrategiaOptions();
                            }
                            if (decoded.subestrategiaVenta) this.subestrategiaVenta = decoded.subestrategiaVenta;
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
                            if (decoded.observacionesPago) this.observacionesPago = decoded.observacionesPago;
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

    loadBusinessLines() { 
        getBusinessLineOptions().then(res => { 
            this.lineaNegocioOptions = res.map(opt => ({
                ...opt,
                checked: (this.selectedLines || []).includes(opt.value)
            })); 
        }); 
    }
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

    async handleNext() { 
        // PASO 1: Contrato (Estrategia)
        if (this.currentStep === '1') {
            if (!this.estrategiaVenta) {
                this.dispatchEvent(new ShowToastEvent({ title: '¡Alto ahí! 🛑', message: 'Debes seleccionar una Categoría (Estrategia de Venta) para poder avanzar.', variant: 'error' }));
                return;
            }
            if (this.subestrategiaOptions.length > 0 && !this.subestrategiaVenta) {
                this.dispatchEvent(new ShowToastEvent({ title: '¡Alto ahí! 🛑', message: 'Debes seleccionar una opción para la estrategia seleccionada.', variant: 'error' }));
                return;
            }
        }
        
        // PASO 2: Datos Técnicos
        if (this.currentStep === '2') {
            if (!this.asunto || this.asunto.trim() === '') {
                this.dispatchEvent(new ShowToastEvent({ title: 'Falta el Asunto 🛑', message: 'Por favor, escribe un Asunto para identificar este presupuesto.', variant: 'error' }));
                return;
            }
            if (!this.selectedSedesObjects || this.selectedSedesObjects.length === 0) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Falta el Cliente 🛑', message: 'Debes seleccionar al menos un cliente de la tabla antes de continuar.', variant: 'error' }));
                return;
            }
            if (!this.selectedContactIds || this.selectedContactIds.length === 0) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Falta el Contacto 🛑', message: 'Por favor, selecciona a quién va dirigido (Atención a) marcando un contacto de la lista.', variant: 'error' }));
                return;
            }
            if (!this.selectedLines || this.selectedLines.length === 0) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Falta Línea de Negocio 🛑', message: 'Debes marcar al menos una Línea de Negocio (ej. Control de Plagas, Desinfección).', variant: 'error' }));
                return;
            }
        }

        // PASO 3: Detalles
        if (this.currentStep === '3') {
            if (!this.serviciosData || this.serviciosData.filter(s => !s.isSeparator).length === 0) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Presupuesto Vacío 🛑', message: 'No puedes avanzar sin agregar al menos un servicio o producto al presupuesto.', variant: 'error' }));
                return;
            }
            if (!this.pagoTransferencia && !this.pagoTarjeta) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Falta Opción de Pago 🛑', message: 'Selecciona al menos una Opción de Pago (Transferencia o Tarjeta).', variant: 'error' }));
                return;
            }
            if (!this.trabajoPuntual && !this.ventaProducto && !this.trabajoMantenimiento) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Falta Tipo de Trabajo 🛑', message: 'Debes marcar al menos un Tipo de Trabajo (Puntual, Producto o Mantenimiento).', variant: 'error' }));
                return;
            }
            
            let rawWarranty = this.warranty ? this.warranty.replace(/<[^>]*>?/gm, '').trim() : '';
            if (rawWarranty === '') {
                this.dispatchEvent(new ShowToastEvent({ title: 'Faltan Condiciones / Anexos 🛑', message: 'Es obligatorio agregar las Condiciones Comerciales o usar una plantilla para protegerte legalmente.', variant: 'error' }));
                return;
            }
        }

        if (this.currentStep !== '4') {
            this.isLoading = true;
            try {
                // Forzamos el guardado y esperamos que termine
                const savedId = await this.handleSave('Borrador');
                
                if (savedId) {
                    const nextStepInt = parseInt(this.currentStep) + 1;
                    if (nextStepInt === 4) {
                        this.pdfUrl = `/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`;
                    }
                    this.currentStep = nextStepInt.toString();
                    if (this.currentStep !== '4') {
                        sessionStorage.setItem(this.storageKey, this.currentStep);
                    }
                }
            } catch (error) {
                console.error('Error al avanzar de paso:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error al guardar',
                    message: 'No se pudo guardar la información del paso actual. Intente de nuevo.',
                    variant: 'error'
                }));
            } finally {
                this.isLoading = false;
            }
        }
    }

    handleBack() { 
        this.currentStep = (parseInt(this.currentStep) - 1).toString(); 
        sessionStorage.setItem(this.storageKey, this.currentStep);
    }

    get estrategiaOptions() {
        return [
            { label: 'Estrategia 1', value: 'E1' }, { label: 'Estrategia 2', value: 'E2' },
            { label: 'Estrategia 3', value: 'E3' }, { label: 'Estrategia 4', value: 'E4' }, { label: 'Estrategia 5', value: 'E5' }
        ];
    }

    updateSubestrategiaOptions() {
        const SUBESTRATEGIA_MAP = {
            'E1': [{ label: 'Póliza fija', value: 'Póliza fija' }, { label: 'Programado', value: 'Programado' }],
            'E2': [{ label: 'Extraordinario', value: 'Extraordinario' }, { label: 'Bomberazo', value: 'Bomberazo' }, { label: 'Venta de producto', value: 'Venta de producto' }],
            'E3': [{ label: 'Proyecto especial (o a la medida)', value: 'Proyecto especial (o a la medida)' }],
            'E4': [{ label: 'Venta de producto', value: 'Venta de producto' }],
            'E5': [{ label: 'Venta de producto', value: 'Venta de producto' }]
        };
        this.subestrategiaOptions = SUBESTRATEGIA_MAP[this.estrategiaVenta] || [];
    }

    handleSubestrategiaChange(event) {
        this.subestrategiaVenta = event.target.value;
    }

    get sedeScopeLabel() { return this.isGlobalSedeSearch ? 'Búsqueda Global' : 'Solo este Cliente'; }
    get sedeSearchPlaceholder() { return this.isGlobalSedeSearch ? 'Buscar en todo Salesforce...' : 'Filtrar registros de este cliente...'; }
    get maxRowSelection() { return this.estrategiaVenta === 'E5' ? 200 : 1; }
    get technicalSedesString() { return this.selectedSedesObjects.map(s => s.Name).join(', '); }

    get costoTotalServicios() {
        let total = 0;
        if (this.serviciosData) {
            this.serviciosData.forEach(item => {
                if (!item.isSeparator) {
                    total += parseFloat(item.totalSinImpuestos || 0);
                }
            });
        }
        return total;
    }

    handleEstrategiaChange(event) { 
        this.estrategiaVenta = event.target.value; 
        this.subestrategiaVenta = '';
        this.updateSubestrategiaOptions();
        this.autoFillAsunto(); 
    }
    autoFillAsunto() {
        const folioDisplay = (this.folio && this.folio !== 'POR GENERAR') ? this.folio : 'POR GENERAR';
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

    async handleSave(status) {
        this.isLoading = true;
        const markers = { 
            serviciosData: this.serviciosData, selectedSedesIds: this.selectedSedesIds, selectedSedesObjects: this.selectedSedesObjects, 
            estrategiaVenta: this.estrategiaVenta, subestrategiaVenta: this.subestrategiaVenta, necesidadId: this.necesidadId, necesidadNombre: this.necesidadNombre, 
            pagoTransferencia: this.pagoTransferencia, pagoTarjeta: this.pagoTarjeta, trabajoPuntual: this.trabajoPuntual, 
            ventaProducto: this.ventaProducto, trabajoMantenimiento: this.trabajoMantenimiento, observacionesPago: this.observacionesPago,
            selectedContactIds: this.selectedContactIds, selectedContactNames: this.selectedContactNames,
            selectedLines: this.selectedLines
        };
        const encoded = btoa(encodeURIComponent(JSON.stringify(markers)).replace(/%([0-9A-F]{2})/g, (match, p1) => String.fromCharCode('0x' + p1)));
        const payload = {
            quoteId: this.recordId, opportunityId: this.parentOpportunityId, contactId: this.selectedContactIds.length > 0 ? this.selectedContactIds[0] : null,
            name: this.asunto, status: status, intro: this.introduccion, warranty: this.warranty, observacionesPago: this.observacionesPago,
            markersData: encoded, technicalSedes: this.selectedSedesObjects.map(s => s.Name).join(', '),
            lineItems: JSON.stringify(this.serviciosData), showIntro: true, showWarranty: true,
            estrategiaVenta: this.estrategiaVenta,
            subestrategiaVenta: this.subestrategiaVenta,
            businessLines: this.selectedLines.join(', '),
            showSubtotal: this.showSubtotal,
            showDiscount: this.showDiscount,
            showSubtotal2: this.showSubtotal2,
            showTax: this.showTax,
            showTotal: this.showTotal
        };

        try {
            const newId = await saveTechnicalData({ data: payload });
            if (newId) {
                const isNew = !this.recordId;
                this.recordId = newId;
                
                // NOTIFICAR CAMBIO PARA REFRESCAR LA OPORTUNIDAD EN LA UI (360)
                if (this.parentOpportunityId) {
                    getRecordNotifyChange([{ recordId: this.parentOpportunityId }]);
                }

                if (isNew) {
                    // Solo recargamos si es nuevo para obtener el Folio real
                    await this.loadInitialData();
                }
            }
            if (status === 'Approved') {
                this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Presupuesto finalizado', variant: 'success' }));
            }
            return this.recordId;
        } catch (error) {
            console.error('Error en handleSave:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo guardar: ' + (error.body ? error.body.message : error.message), variant: 'error' }));
            throw error;
        } finally {
            this.isLoading = false;
        }
    }

    handleAddServiceItems(event) {
        const newItems = event.detail;
        if (this.itemToEdit) {
            this.serviciosData = this.serviciosData.map(item => item.id === this.itemToEdit.id ? newItems[0] : item);
        } else {
            this.serviciosData = [...this.serviciosData, ...newItems];
        }
        this.calculateTotals();
        this.showModal = false;
        this.itemToEdit = null;
    }

    calculateTotals() {
        this.calcSubtotal1 = 0;
        this.calcDescuento = 0;

        this.serviciosData.forEach(item => { 
            if (!item.isSeparator) {
                // lista = Precio de Lista (Unitario sin descuento) * Cantidad
                // Usamos subtotalBruto si viene, si no, calculamos con precioVenta, si no, asumimos que no hay descuento y usamos totalSinImpuestos
                let lista = item.subtotalBruto !== undefined ? item.subtotalBruto : (item.precioVenta !== undefined ? (item.precioVenta * (item.cantidad || 0)) : (item.totalSinImpuestos || 0));
                this.calcSubtotal1 += lista;
                
                // totalSinImpuestos es el valor ya con descuento aplicado, la diferencia es el descuento en dinero
                let totalConDesc = item.totalSinImpuestos || 0;
                let descLinea = lista - totalConDesc;
                if (descLinea > 0) {
                    this.calcDescuento += descLinea;
                }
            } 
        });

        this.calcSubtotal2 = this.calcSubtotal1 - this.calcDescuento;
        this.calcIva = this.calcSubtotal2 * 0.16;
        this.calcTotal = this.calcSubtotal2 + this.calcIva;

        // Mantenemos la variable vieja por si acaso
        this.totalesData = [{ id: 'total-1', impuestosNom: 'IVA (16%)', base: this.calcSubtotal2, valorImpuesto: this.calcIva, total: this.calcTotal }];
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
            })
            .catch(error => { console.error('Error render:', error); })
            .finally(() => { this.isLoading = false; });
    }

    handleFinalize() { this.handleSave('Approved'); }
    handleCancel() { this.dispatchEvent(new CustomEvent('cancel')); }
    async handlePreviewPdf() { 
        try {
            await this.handleSave('Borrador'); 
            this.pdfUrl = `/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`; 
            this.showPdfModal = true; 
        } catch (e) { console.error(e); }
    }
    handleClosePdfModal() { this.showPdfModal = false; this.pdfUrl = ''; }
    
    handleOpenPdfNewWindow() {
        if (this.pdfUrl) {
            window.open(this.pdfUrl, '_blank');
        } else if (this.recordId) {
            window.open(`/apex/QuoteTechnicalPDF?id=${this.recordId}&t=${Date.now()}`, '_blank');
        }
    }
    
    handleAsuntoChange(event) { this.asunto = event.target.value; }
    handleIntroChange(event) { this.introduccion = event.target.value; }
    handleWarrantyChange(event) { this.warranty = event.target.value; }
    handleObservacionesPagoChange(event) { this.observacionesPago = event.target.value; }
    handlePagoTransferenciaChange(event) { this.pagoTransferencia = event.target.checked; }
    handlePagoTarjetaChange(event) { this.pagoTarjeta = event.target.checked; }
    handleTrabajoPuntualChange(event) { this.trabajoPuntual = event.target.checked; }
    handleVentaProductoChange(event) { this.ventaProducto = event.target.checked; }
    handleTrabajoMantenimientoChange(event) { this.trabajoMantenimiento = event.target.checked; }
    handleShowSubtotalChange(event) { this.showSubtotal = event.target.checked; }
    handleShowDiscountChange(event) { this.showDiscount = event.target.checked; }
    handleShowSubtotal2Change(event) { this.showSubtotal2 = event.target.checked; }
    handleShowTaxChange(event) { this.showTax = event.target.checked; }
    handleShowTotalChange(event) { this.showTotal = event.target.checked; }

    handleOpenSeparatorModal() { this.showSeparatorModal = true; }
    handleCloseSeparatorModal() { this.showSeparatorModal = false; }
    handleSeparatorTextChange(event) { this.separatorText = event.target.value; }
    handleSeparatorStyleChange(event) { this.separatorStyle = event.target.value; }
    
    get separatorStyleOptions() {
        return [
            { label: 'Barra Sólida', value: 'header' },
            { label: 'Línea con Texto', value: 'line' }
        ];
    }

    handleAddSeparator() {
        const styleClass = this.separatorStyle === 'header' ? 'row-separator-header' : 'row-separator-line';
        this.serviciosData = [...this.serviciosData, { 
            id: Date.now().toString(), 
            isSeparator: true, 
            descripcion: this.separatorText || '', 
            style: this.separatorStyle,
            rowClass: styleClass 
        }];
        this.showSeparatorModal = false;
        this.separatorText = '';
        this.separatorStyle = 'header';
    }
    handleOpenPLModal() { this.showPLModal = true; }
    handleClosePLModal() { this.showPLModal = false; }

    draggedIndex;
    handleDragStart(event) { this.draggedIndex = event.currentTarget.dataset.index; event.dataTransfer.effectAllowed = 'move'; event.currentTarget.classList.add('dragging'); }
    handleDragOver(event) { event.preventDefault(); event.dataTransfer.dropEffect = 'move'; }
    handleDrop(event) {
        event.preventDefault();
        const dropIndex = event.currentTarget.dataset.index;
        if (this.draggedIndex === dropIndex) return;
        let data = [...this.serviciosData];
        const draggedItem = data.splice(this.draggedIndex, 1)[0];
        data.splice(dropIndex, 0, draggedItem);
        this.serviciosData = data;
        this.draggedIndex = null;
        this.template.querySelectorAll('tr').forEach(row => row.classList.remove('dragging'));
    }
}