import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitialData from '@salesforce/apex/QuoteTechnicalController.getInitialData';
import saveTechnicalData from '@salesforce/apex/QuoteTechnicalController.saveTechnicalData';
import searchProducts from '@salesforce/apex/QuoteTechnicalController.searchProducts';
import getBusinessLineOptions from '@salesforce/apex/QuoteTechnicalController.getBusinessLineOptions';
import searchNecesidades from '@salesforce/apex/QuoteTechnicalController.searchNecesidades';
import getEmailTemplatesByFolder from '@salesforce/apex/QuoteTechnicalController.getEmailTemplatesByFolder';
import renderTemplate from '@salesforce/apex/QuoteTechnicalController.renderTemplate';
import validatePLPassword from '@salesforce/apex/QuoteTechnicalController.validatePLPassword';

export default class TechQuoteEditor extends LightningElement {
    @api recordId; 
    
    @track currentStep = '1';
    @track isLoading = false;
    
    @track asunto = '';
    @track introduccion = '';
    @track introTemplates = [];
    @track warrantyTemplates = [];
    @track pagoTemplates = [];
    @track serviceTemplates = [];
    @track clienteNombre = 'Seleccione una sede...'; // Nueva variable dinámica
    @track folio = 'Cargando...';
    @track agenteNombre = '';
    @track jsonMarkers = '';
    @track warranty = '';
    @track planUrl = '';

    @track fechaCreacion = new Date().toISOString().split('T')[0]; // Hoy por defecto
    @track fechaAprobacion = '';

    @track estrategiaVenta = '';
    @track necesidadId = '';
    @track necesidadNombre = '';
    @track necesidadesResults = [];
    @track necesidadSeleccionada = '';

    @track numeroContrato = '';
    @track contratoManual = false;

    @track searchResults = [];
    @track selectedProductId = '';
    @track selectedProductName = '';

    // LÍNEAS DE NEGOCIO - Ahora se cargan dinámicamente desde Salesforce
    @track lineaNegocioOptions = [];

    @track sedesData = [];
    @track selectedSedesIds = [];

    // Columnas restauradas
    sedesColumns = [
        { label: 'Código', fieldName: 'CodigoInterno', type: 'text', initialWidth: 100 },
        { label: 'Nombre Sede', fieldName: 'AccountName', type: 'text' },
        { label: 'Contacto', fieldName: 'Name', type: 'text' },
        { label: 'Teléfono', fieldName: 'Phone', type: 'phone' },
        { label: 'Dirección', fieldName: 'MailingStreet', type: 'text' },
        { label: 'Municipio', fieldName: 'MailingCity', type: 'text' },
        { label: 'Estado', fieldName: 'MailingState', type: 'text' }
    ];

    serviciosColumns = [
        { label: 'Descripción', fieldName: 'descripcion', type: 'text', initialWidth: 300 },
        { label: 'Sedes', fieldName: 'sedes', type: 'text', initialWidth: 200 },
        { label: 'Cant.', fieldName: 'cantidad', type: 'number', initialWidth: 80 },
        { label: 'Importe U.', fieldName: 'importeUnitario', type: 'currency' },
        { label: 'Desc.', fieldName: 'descuentoDisplay', type: 'text', initialWidth: 90 },
        { label: 'Total (Sin IVA)', fieldName: 'totalSinImpuestos', type: 'currency' },
        { label: 'Acciones', type: 'action', typeAttributes: { rowActions: [{ label: 'Eliminar', name: 'delete' }] } }
    ];

    totalesColumns = [
        { label: 'Impuestos', fieldName: 'impuestosNom', type: 'text' },
        { label: 'Base gravable', fieldName: 'base', type: 'currency' },
        { label: 'Impuesto', fieldName: 'valorImpuesto', type: 'currency' },
        { label: 'Retenciones', fieldName: 'retenciones', type: 'currency' },
        { label: 'Total', fieldName: 'total', type: 'currency' }
    ];

    @track serviciosData = [];
    @track totalesData = [];
    @track selectedLines = []; 
    @track allowOtherLines = false;

    @track showModal = false;
    @track isUnitario = true;
    @track isTotal = false;
    @track zonaInput = '';
    @track zonasAfectadas = [];
    @track showIndicaciones = false;

    @track modalTableData = [];
    @track modalDescription = '';
    @track convertZonas = false; 

    @track showSeparatorModal = false;
    @track separatorText = '';

    @track showPLModal = false;
    @track showPasswordModal = false;
    @track passwordInput = '';
    @track showDiscountColumn = false; 
    
    // ESTRUCTURA P&L COMPARATIVA (Año 1 y Año 2)
    @track pl1 = { costo: 0, margen: 25, indirecto: 15, comision1: 2, comision2: 0, regalia: 5, dias: 7 };
    @track pl2 = { costo: 0, margen: 41, indirecto: 15, comision1: 2, comision2: 0, regalia: 5, dias: 7 };

    // Fórmulas de cálculo genéricas para reutilizar
    calculatePL(data) {
        const venta = data.margen >= 100 ? 0 : (data.costo / (1 - (data.margen / 100)));
        const ind = venta * (data.indirecto / 100);
        const com1 = venta * (data.comision1 / 100);
        const com2 = venta * (data.comision2 / 100);
        const reg = venta * (data.regalia / 100);
        const fin = venta * 0.000611 * data.dias; // Tasa diaria estimada del ejemplo
        
        const utilidadBruta = venta - data.costo - ind - com1 - com2 - reg - fin;
        const isr = utilidadBruta > 0 ? (utilidadBruta * 0.06) : 0;
        const ru = utilidadBruta > 0 ? (utilidadBruta * 0.05) : 0;
        
        const costoTotal = parseFloat(data.costo) + ind + com1 + com2 + reg + fin + isr + ru;
        const margenDolares = venta - costoTotal;
        const margenPct = venta > 0 ? (margenDolares / venta) * 100 : 0;

        return {
            venta: venta.toFixed(2),
            ind: ind.toFixed(2),
            com1: com1.toFixed(2),
            com2: com2.toFixed(2),
            reg: reg.toFixed(2),
            fin: fin.toFixed(2),
            isr: isr.toFixed(2),
            ru: ru.toFixed(2),
            costoTotal: costoTotal.toFixed(2),
            resPesos: margenDolares.toFixed(2),
            resPct: margenPct.toFixed(2)
        };
    }

    get res1() { return this.calculatePL(this.pl1); }
    get res2() { return this.calculatePL(this.pl2); }

    // Manejadores de cambios
    handlePL1Change(event) {
        const field = event.target.dataset.field;
        this.pl1 = { ...this.pl1, [field]: parseFloat(event.target.value) || 0 };
    }

    handlePL2Change(event) {
        const field = event.target.dataset.field;
        this.pl2 = { ...this.pl2, [field]: parseFloat(event.target.value) || 0 };
    }

    @track showDiscountColumn = false; 
    @track costoOperativo = 0;
    @track utilidadDeseada = 35; 

    @track showTotal = true;
    @track showTaxes = true;
    @track showLineItems = true;
    @track showDescription = true;

    @track pagoTransferencia = false;
    @track pagoTarjeta = false;
    @track trabajoPuntual = false;
    @track ventaProducto = false;
    @track trabajoMantenimiento = false;
    @track observacionesPago = '';

    connectedCallback() {
        this.loadBusinessLines(); // Se carga siempre para que aparezcan las opciones
        this.loadInitialData();   // Se carga siempre para traer contactos/datos base
        this.loadTemplates();     // Carga de plantillas de correo
    }

    loadTemplates() {
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Introducciones' })
            .then(result => { this.introTemplates = result; })
            .catch(error => console.error('Error cargando intros:', error));
        
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Clausulas y Anexos' })
            .then(result => { this.warrantyTemplates = result; })
            .catch(error => console.error('Error cargando clausulas:', error));

        getEmailTemplatesByFolder({ folderName: 'Pyatz - Observaciones de Pago' })
            .then(result => { this.pagoTemplates = result; })
            .catch(error => console.error('Error cargando observaciones pago:', error));

        getEmailTemplatesByFolder({ folderName: 'Pyatz - Servicios' })
            .then(result => { this.serviceTemplates = result; })
            .catch(error => console.error('Error cargando servicios:', error));
    }

    handleApplyTemplate(event) {
        const templateId = event.detail.value;
        const targetField = event.currentTarget.dataset.field; // Usar currentTarget para mayor precisión en dataset

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
                console.error('Error renderizando:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error al cargar plantilla',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            });
    }

    handleAllowOtherLinesChange(event) {
        this.allowOtherLines = event.target.checked;
        this.searchResults = []; 
    }

    // MODAL LOGIC
    handleOpenModal() {
        // CORRECCIÓN: Usar la variable trackeada selectedSedesIds convertida a String para asegurar coincidencia
        const selectedSedes = this.sedesData.filter(sede => this.selectedSedesIds.includes(String(sede.Id)));
        
        if (selectedSedes.length === 0) {
            this.modalTableData = [{ id: 'temp-1', sede: 'Sede Principal (Default)', cantidad: 1, importeTotal: 0, totalSinImpuestos: 0, impuestos: 16, descuento: 0, tipoDescuento: 'monto', tipoDescuentoSimbolo: '$', tipoDescuentoIcon: 'utility:moneybag' }];
        } else {
            this.modalTableData = selectedSedes.map(sede => ({
                id: sede.Id,
                sede: `${sede.AccountName || 'Sede'} - ${sede.MailingCity || ''}`,
                cantidad: 1,
                importeTotal: 0,
                totalSinImpuestos: 0,
                impuestos: 16,
                descuento: 0,
                tipoDescuento: 'monto',
                tipoDescuentoSimbolo: '$',
                tipoDescuentoIcon: 'utility:moneybag'
            }));
        }
        this.selectedProductId = '';
        this.selectedProductName = '';
        this.modalDescription = ''; 
        this.zonasAfectadas = [];
        this.convertZonas = false;
        this.searchResults = [];
        this.showModal = true;
    }

    handleCloseModal() { this.showModal = false; }

    handleOpenSeparatorModal() {
        this.separatorText = '';
        this.showSeparatorModal = true;
    }

    handleCloseSeparatorModal() {
        this.showSeparatorModal = false;
    }

    // P&L LOGIC CON CONTRASEÑA
    handleOpenPLModal() {
        this.passwordInput = '';
        this.showPasswordModal = true;
    }

    handlePasswordChange(event) {
        this.passwordInput = event.target.value;
    }

    handleClosePasswordModal() {
        this.showPasswordModal = false;
    }

    handleValidatePLPassword() {
        this.isLoading = true;
        validatePLPassword({ passwordAttempt: this.passwordInput })
            .then(isCorrect => {
                this.isLoading = false;
                if (isCorrect) {
                    this.showPasswordModal = false;
                    this.showPLModal = true;
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Acceso Denegado',
                        message: 'La contraseña es incorrecta. Contacte al administrador.',
                        variant: 'error'
                    }));
                }
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error validando pass:', error);
            });
    }

    handleClosePLModal() {
        this.showPLModal = false;
    }

    handleCostoChange(event) {
        this.costoOperativo = parseFloat(event.target.value) || 0;
    }

    handleUtilidadDeseadaChange(event) {
        this.utilidadDeseada = parseFloat(event.target.value) || 0;
    }

    handleShowTotalChange(event) { this.showTotal = event.target.checked; }
    handleShowTaxesChange(event) { this.showTaxes = event.target.checked; }
    handleShowLineItemsChange(event) { this.showLineItems = event.target.checked; }
    handleShowDescriptionChange(event) { this.showDescription = event.target.checked; }

    handlePagoTransferenciaChange(event) { this.pagoTransferencia = event.target.checked; }
    handlePagoTarjetaChange(event) { this.pagoTarjeta = event.target.checked; }
    handleTrabajoPuntualChange(event) { this.trabajoPuntual = event.target.checked; }
    handleVentaProductoChange(event) { this.ventaProducto = event.target.checked; }
    handleTrabajoMantenimientoChange(event) { this.trabajoMantenimiento = event.target.checked; }
    handleObservacionesPagoChange(event) { this.observacionesPago = event.target.value; }

    handleWarrantyChange(event) {
        this.warranty = event.target.value;
    }

    get hasAnyDiscount() {
        return this.serviciosData.some(item => !item.isSeparator && item.descuento > 0);
    }

    get totalVentaNeto() {
        return this.serviciosData.reduce((sum, item) => sum + (item.totalSinImpuestos || 0), 0);
    }

    get totalDescuento() {
        return this.serviciosData.reduce((sum, item) => {
            if (item.isSeparator) return sum;
            const subtotalBase = item.cantidad * item.importeUnitario;
            const desc = subtotalBase - (item.totalSinImpuestos || 0);
            return sum + (desc > 0 ? desc : 0);
        }, 0);
    }

    get fechaFormateada() {
        if (!this.fechaCreacion) return '';
        const parts = this.fechaCreacion.split('-');
        if (parts.length === 3) {
            return `${parts[2]}/${parts[1]}/${parts[0]}`;
        }
        return this.fechaCreacion;
    }

    get margenActual() {
        if (this.totalVentaNeto === 0) return 0;
        const utilidad = this.totalVentaNeto - this.costoOperativo;
        return ((utilidad / this.totalVentaNeto) * 100).toFixed(2);
    }

    get precioSugerido() {
        if (this.utilidadDeseada >= 100) return 0;
        const factor = 1 - (this.utilidadDeseada / 100);
        return (this.costoOperativo / factor).toFixed(2);
    }

    get marginStyle() {
        const margin = parseFloat(this.margenActual);
        if (margin <= 0) return 'background-color: #ffdada; border-color: #ffbaba; color: #d8000c;';
        if (margin < 20) return 'background-color: #fff4d1; border-color: #ffe08c; color: #856404;';
        return 'background-color: #d4edda; border-color: #c3e6cb; color: #155724;';
    }

    get dropdownIcon() {
        return this.showIndicaciones ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get separatorColspan() {
        return this.showLineItems ? 4 : 2;
    }

    handleSeparatorTextChange(event) {
        this.separatorText = event.target.value;
    }

    handleAddSeparator() {
        if (!this.separatorText) return;

        const separatorLine = {
            id: `sep-${Date.now()}`,
            descripcion: this.separatorText,
            isSeparator: true,
            cantidad: 0,
            sedes: '---',
            importeUnitario: 0,
            totalSinImpuestos: 0,
            impuesto: '0%'
        };

        this.serviciosData = [...this.serviciosData, separatorLine];
        this.showSeparatorModal = false;
    }

    handleModalDescriptionChange(event) {
        this.modalDescription = event.target.value;
    }

    handleConvertZonasChange(event) {
        this.convertZonas = event.target.checked;
    }

    handleSaveServiceLine() {
        if (!this.selectedProductId) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Aviso', message: 'Seleccione un producto', variant: 'warning' }));
            return;
        }

        const newItems = this.modalTableData
            .filter(row => row.cantidad > 0 && row.importeTotal > 0)
            .map(row => {
                const subtotal = parseFloat(row.totalSinImpuestos);
                const taxAmount = subtotal * (row.impuestos / 100);
                return {
                    id: `${this.selectedProductId}-${row.id}-${Date.now()}`,
                    productId: this.selectedProductId,
                    descripcion: `${this.selectedProductName} - ${row.sede}`,
                    detalleTecnico: this.modalDescription ? this.modalDescription.replace(/(<([^>]+)>)/gi, "") : '', 
                    detalleTecnicoHtml: this.modalDescription,
                    indicacionesEjecucion: this.zonasAfectadas.join(', '),
                    crearNuevasZonas: this.convertZonas,
                    cantidad: row.cantidad,
                    sedes: row.sede,
                    importeUnitario: this.isUnitario ? row.importeTotal : (row.importeTotal / row.cantidad),
                    descuento: row.descuento,
                    tipoDescuento: row.tipoDescuento,
                    descuentoDisplay: row.descuento > 0 ? (row.tipoDescuento === 'porcentaje' ? `${row.descuento}%` : `$${row.descuento.toFixed(2)}`) : '-',
                    impuesto: `${row.impuestos}%`,
                    taxValue: taxAmount,
                    totalSinImpuestos: subtotal,
                    totalConImpuestos: subtotal + taxAmount
                };
            });

        this.serviciosData = [...this.serviciosData, ...newItems];
        this.calculateTotals();
        this.showModal = false;
        
        // Resetear campos operativos
        this.modalDescription = '';
        this.zonasAfectadas = [];
        this.convertZonas = false;
    }

    calculateTotals() {
        let subtotal = 0;
        let totalImpuestos = 0;

        this.serviciosData.forEach(item => {
            subtotal += item.totalSinImpuestos;
            totalImpuestos += item.taxValue;
        });

        this.totalesData = [
            { id: '1', impuestosNom: 'I.V.A. (16%)', base: subtotal, valorImpuesto: totalImpuestos, retenciones: 0, total: subtotal + totalImpuestos }
        ];
    }

    loadBusinessLines() {
        getBusinessLineOptions()
            .then(result => {
                if(result && result.length > 0) {
                    this.lineaNegocioOptions = result.map(opt => ({
                        ...opt,
                        checked: false
                    }));
                }
            })
            .catch(error => console.error('Error cargando líneas:', error));
    }

    handleLineChange(event) {
        const value = event.target.dataset.value;
        const checked = event.target.checked;
        
        // Sincronizar el estado visual en el array trackeado
        this.lineaNegocioOptions = this.lineaNegocioOptions.map(opt => {
            if (opt.value === value) {
                return { ...opt, checked: checked };
            }
            return opt;
        });

        // Actualizar la lista de strings para el filtro SOQL en Apex
        if (checked) {
            if (!this.selectedLines.includes(value)) {
                this.selectedLines = [...this.selectedLines, value];
            }
        } else {
            this.selectedLines = this.selectedLines.filter(line => line !== value);
        }
        console.log('Líneas seleccionadas para filtro:', JSON.stringify(this.selectedLines));
    }

    loadInitialData() {
        this.isLoading = true;
        getInitialData({ recordId: this.recordId })
            .then(result => {
                if (result.agenteNombre) {
                    this.agenteNombre = result.agenteNombre;
                }
                
                if (result.quote) {
                    const q = result.quote;
                    this.asunto = q.Name || '';
                    this.introduccion = q.Introduction_Text__c || '';
                    this.clienteNombre = q.Account ? q.Account.Name : (result.clienteNombre || 'Cliente no identificado');
                    this.folio = q.QuoteNumber || '';
                    this.warranty = q.Warranty_Text__c || '';
                    this.observacionesPago = q.Description || '';
                    this.showDescription = q.Show_Warranty__c;
                    
                    this.fechaCreacion = q.CreatedDate ? q.CreatedDate.split('T')[0] : new Date().toISOString().split('T')[0];
                    this.fechaAprobacion = q.Approval_Date__c || '';
                    
                    if (q.Business_Lines_Selected__c) {
                        this.selectedLines = q.Business_Lines_Selected__c.split(', ');
                        this.updateBusinessLineCheckboxes();
                    }

                    // CARGAR PARTIDAS EXISTENTES
                    if (q.QuoteLineItems) {
                        this.serviciosData = q.QuoteLineItems.map(item => {
                            let descDisp = '-';
                            if (item.Discount && item.Discount > 0) {
                                descDisp = `${item.Discount}%`;
                            } else if (item.ListPrice > item.UnitPrice) {
                                descDisp = `$${(item.ListPrice - item.UnitPrice).toFixed(2)}`;
                            }

                            return {
                                id: item.Id,
                                productId: item.PricebookEntryId,
                                descripcion: item.Product2.Name,
                                detalleTecnico: item.Description,
                                detalleTecnicoHtml: item.Description,
                                cantidad: item.Quantity,
                                importeUnitario: item.ListPrice || item.UnitPrice,
                                descuentoDisplay: descDisp,
                                totalSinImpuestos: item.TotalPrice,
                                sedes: 'Cargada de DB',
                                isSeparator: false
                            };
                        });
                        this.calculateTotals();
                    }

                    const rawMarkers = q.Markers_Data__c;
                    if (rawMarkers) {
                        // Si es un objeto, lo convertimos a string. Si ya es el error "[object Object]", lo ignoramos.
                        const markerStr = typeof rawMarkers === 'object' ? JSON.stringify(rawMarkers) : String(rawMarkers);
                        if (markerStr.includes('[object Object]')) {
                            this.jsonMarkers = '';
                        } else {
                            this.jsonMarkers = markerStr;
                        }
                    } else {
                        this.jsonMarkers = '';
                    }
                }
                
                // Mapeo seguro de contactos (FILTRADOS)
                if (result.contacts) {
                    this.sedesData = result.contacts.map((con, index) => ({
                        ...con,
                        CodigoInterno: `CON-${index + 101}`,
                        AccountId: con.AccountId,
                        AccountName: con.Account ? con.Account.Name : 'Sin Cuenta',
                        MailingStreet: con.MailingStreet || 'Sin calle',
                        MailingCity: con.MailingCity || 'N/A',
                        MailingState: con.MailingState || 'N/A'
                    }));
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error inicial:', error);
                this.isLoading = false;
            });
    }

    updateBusinessLineCheckboxes() {
        this.lineaNegocioOptions = this.lineaNegocioOptions.map(opt => ({
            ...opt,
            checked: this.selectedLines.includes(opt.value)
        }));
    }

    handleSedeSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedSedesIds = selectedRows.map(row => String(row.Id)); 
        
        // Si no tenemos clienteNombre aún, lo tomamos de la sede seleccionada
        if ((this.clienteNombre === 'Seleccione una sede...' || !this.recordId) && selectedRows.length > 0) {
            this.clienteNombre = selectedRows[0].AccountName;
        }
        console.log('PYATZ LOG: Sedes seleccionadas:', JSON.stringify(this.selectedSedesIds));
    }

    get estrategiaOptions() {
        return [
            { label: 'E1 - Póliza Anual', value: 'E1' },
            { label: 'E2 - Extraordinario', value: 'E2' },
            { label: 'E3 - Cliente Nuevo', value: 'E3' },
            { label: 'E4 - Retardantes', value: 'E4' },
            { label: 'E5 - Cedis', value: 'E5' }
        ];
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    get nextButtonLabel() { return this.currentStep === '4' ? 'Guardar y Finalizar' : 'Siguiente'; }

    get selectedLinesDisplay() {
        return this.selectedLines.length > 0 ? this.selectedLines.join(', ') : 'Ninguna seleccionada';
    }

    get selectedSedesDisplay() {
        // Filtramos los datos completos de la tabla usando los IDs seleccionados
        const selectedRows = this.sedesData.filter(row => this.selectedSedesIds.includes(String(row.Id)));
        return selectedRows.length > 0 
            ? selectedRows.map(row => `${row.AccountName || 'Sede'} - ${row.MailingCity || ''}`).join(', ') 
            : 'Sede Principal';
    }

    handleAsuntoChange(event) { this.asunto = event.target.value; }
    handleIntroChange(event) { this.introduccion = event.target.value; }
    handleFechaAprobacionChange(event) { this.fechaAprobacion = event.target.value; }

    handleEstrategiaChange(event) {
        this.estrategiaVenta = event.target.value;
        this.autoFillAsunto();
    }

    handleNecesidadChange(event) {
        const searchTerm = event.target.value;
        this.necesidadSeleccionada = searchTerm;
        if (searchTerm.length >= 3) {
            searchNecesidades({ searchTerm: searchTerm })
                .then(result => {
                    this.necesidadesResults = result;
                })
                .catch(error => console.error('Error buscando necesidades:', error));
        } else {
            this.necesidadesResults = [];
        }
    }

    handleNecesidadSelect(event) {
        const nid = event.currentTarget.dataset.id;
        const res = this.necesidadesResults.find(n => n.id === nid);
        if (res) {
            this.necesidadId = nid;
            this.necesidadNombre = res.name;
            this.necesidadSeleccionada = res.name;
            this.necesidadesResults = [];
            this.autoFillAsunto();
        }
    }

    autoFillAsunto() {
        const estrategiaLabel = this.estrategiaOptions.find(opt => opt.value === this.estrategiaVenta)?.label || '';
        const baseAsunto = `${estrategiaLabel} @ ${this.necesidadNombre || 'Servicio Técnico'}`;
        if (!this.asunto || this.asunto.includes('@') || this.asunto === 'Cargando...') {
            this.asunto = baseAsunto;
        }
    }

    handleProductSearch(event) {
        const searchTerm = event.target.value;
        if (searchTerm.length >= 3) {
            searchProducts({ 
                searchTerm: searchTerm, 
                quoteId: this.recordId,
                businessLines: this.selectedLines,
                allowOtherLines: this.allowOtherLines
            })
            .then(result => { this.searchResults = result; })
            .catch(error => console.error('Error productos:', error));
        } else { this.searchResults = []; }
    }

    handleProductSelect(event) {
        const productId = event.currentTarget.dataset.id;
        const product = this.searchResults.find(p => p.id === productId);
        if (product) {
            this.selectedProductId = product.id;
            this.selectedProductName = product.name;
            this.modalDescription = product.description || ''; // Inyección automática de la descripción del producto
            this.searchResults = []; 
            this.modalTableData = this.modalTableData.map(row => {
                let newRow = { ...row, importeTotal: product.unitPrice };
                newRow.totalSinImpuestos = this.isUnitario ? (product.unitPrice * row.cantidad) : product.unitPrice;
                return newRow;
            });
        }
    }

    get metodoPagoDisplay() {
        let metodos = [];
        if (this.pagoTransferencia) metodos.push('Transferencia');
        if (this.pagoTarjeta) metodos.push('Tarjeta');
        return metodos.length > 0 ? metodos.join(' / ') : 'No especificado';
    }

    get tipoTrabajoDisplay() {
        let tipos = [];
        if (this.trabajoPuntual) tipos.push('Trabajo único/puntual');
        if (this.ventaProducto) tipos.push('Venta producto');
        if (this.trabajoMantenimiento) tipos.push('Contrato de mantenimiento');
        return tipos.length > 0 ? tipos.join(', ') : 'No especificado';
    }

    // Método para limpiar etiquetas dinámicas en el texto
    mergeDynamicTags(text) {
        if (!text) return '';
        const contacto = this.selectedSedesDisplay !== 'Sede Principal' ? this.selectedSedesDisplay : '________________';
        const cuenta = this.clienteNombre !== 'Seleccione una sede...' ? this.clienteNombre : '________________';
        
        return text
            .replace(/\[\[CONTACTO\]\]/g, contacto)
            .replace(/\[\[CUENTA\]\]/g, cuenta)
            .replace(/\{!Contact\.Name\}/g, contacto) // Soporte para sintaxis vieja
            .replace(/\{!Quote\.Account\}/g, cuenta);  // Soporte para sintaxis vieja
    }

    get mergedIntroduccion() {
        return this.mergeDynamicTags(this.introduccion);
    }

    get mergedWarranty() {
        return this.mergeDynamicTags(this.warranty);
    }

    handleNext() {
        if (this.currentStep === '4') this.handleFinalize();
        else {
            this.currentStep = (parseInt(this.currentStep) + 1).toString();
        }
    }

    handleSaveDraft() {
        this.handleSave('Draft');
    }

    handleFinalize() {
        this.handleSave('Presented'); // O 'Approved' según el flujo de Pyatz
    }

    handleSave(statusValue) {
        this.isLoading = true;
        
        // CORRECCIÓN CRÍTICA: Obtener AccountId y ContactId de la primera sede seleccionada
        let inferredAccountId = null;
        let inferredContactId = null;
        if (this.selectedSedesIds.length > 0) {
            const firstSede = this.sedesData.find(s => String(s.Id) === String(this.selectedSedesIds[0]));
            if (firstSede) {
                inferredAccountId = firstSede.AccountId;
                inferredContactId = firstSede.Id;
            }
        }

        const payload = {
            quoteId: this.recordId,
            accountId: inferredAccountId,
            contactId: inferredContactId,
            name: this.asunto,
            status: statusValue,
            intro: this.mergeDynamicTags(this.introduccion),
            warranty: this.mergeDynamicTags(this.warranty),
            businessLines: this.selectedLinesDisplay,
            technicalSedes: this.selectedSedesDisplay,
            lineItems: JSON.stringify(this.serviciosData),
            showIntro: this.showDescription, 
            showWarranty: this.showDescription,
            observacionesPago: this.observacionesPago,
            pagoTransferencia: this.pagoTransferencia,
            pagoTarjeta: this.pagoTarjeta,
            ventaProducto: this.ventaProducto
        };

        saveTechnicalData({ data: payload })
        .then((newId) => {
            this.isLoading = false;
            const msg = statusValue === 'Draft' ? 'Borrador guardado' : 'Cotización finalizada con éxito';
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: msg, variant: 'success' }));
            
            // Actualizar el recordId y RECARGAR para traer nombres de DB
            if (newId) {
                this.recordId = newId;
                this.loadInitialData(); // Recarga dinámica de nombres y agentes
            }
            
            this.dispatchEvent(new CustomEvent('save', { detail: this.recordId }));
        })
        .catch(error => {
            console.error('Error detallado al guardar:', JSON.stringify(error));
            this.isLoading = false;
            let errorMessage = 'Error desconocido';
            if (error.body && error.body.message) errorMessage = error.body.message;
            else if (error.message) errorMessage = error.message;
            
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Error al persistir', 
                message: 'Detalle: ' + errorMessage, 
                variant: 'error',
                mode: 'sticky'
            }));
        });
    }

    handleCancel() {
        if (this.currentStep === '1') this.dispatchEvent(new CustomEvent('cancel'));
        else this.currentStep = (parseInt(this.currentStep) - 1).toString();
    }

    handleCreateNew() {
        this.selectedRecordId = null;
        this.viewMode = 'edit';
    }

    handleEditQuote(event) {
        this.selectedRecordId = event.detail;
        this.viewMode = 'edit';
    }

    handleShowList() {
        this.viewMode = 'list';
    }

    handleCloseModal() { this.showModal = false; }

    handleToggleDiscountColumn() {
        this.showDiscountColumn = !this.showDiscountColumn;
    }

    handleToggleDiscountType(event) {
        const id = event.target.dataset.id;
        this.modalTableData = this.modalTableData.map(row => {
            if (row.id === id) {
                const nextType = row.tipoDescuento === 'monto' ? 'porcentaje' : 'monto';
                return { ...row, tipoDescuento: nextType };
            }
            return row;
        });
        this.recalculateModalData();
    }

    handleModalInputChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = field === 'tipoDescuento' ? event.target.value : (parseFloat(event.target.value) || 0);

        this.modalTableData = this.modalTableData.map(row => {
            if (row.id === id) {
                let newRow = { ...row, [field]: value };
                let base = this.isUnitario ? (newRow.importeTotal * newRow.cantidad) : newRow.importeTotal;
                
                if (newRow.tipoDescuento === 'porcentaje') {
                    newRow.totalSinImpuestos = base * (1 - (newRow.descuento / 100));
                } else {
                    newRow.totalSinImpuestos = base - newRow.descuento;
                }
                return newRow;
            }
            return row;
        });
    }

    handlePriceType(event) {
        const type = event.target.label;
        this.isUnitario = (type === 'UNITARIO');
        this.isTotal = !this.isUnitario;
        this.recalculateModalData();
    }

    recalculateModalData() {
        this.modalTableData = this.modalTableData.map(row => {
            let newRow = { ...row };
            let base = this.isUnitario ? (newRow.importeTotal * newRow.cantidad) : newRow.importeTotal;
            
            if (newRow.tipoDescuento === 'porcentaje') {
                newRow.totalSinImpuestos = base * (1 - (newRow.descuento / 100));
            } else {
                newRow.totalSinImpuestos = base - newRow.descuento;
            }

            // Atributos visuales para el botón de toggle
            newRow.tipoDescuentoSimbolo = newRow.tipoDescuento === 'porcentaje' ? '%' : '$';
            newRow.tipoDescuentoIcon = newRow.tipoDescuento === 'porcentaje' ? 'utility:percent' : 'utility:moneybag';
            
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

    removeZona(event) {
        const zonaToRemove = event.target.dataset.name;
        this.zonasAfectadas = this.zonasAfectadas.filter(z => z !== zonaToRemove);
    }
}