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

    @track modalSedeSearchTerm = ''; // Nueva para el buscador interno

    @track showSeparatorModal = false;
    @track separatorText = '';

    @track showPLModal = false;
    @track showPasswordModal = false;
    @track passwordInput = '';
    @track showDiscountColumn = false; 
    
    // Getter para filtrar las sedes en la tabla del modal
    get filteredModalTableData() {
        let list = this.modalTableData;
        if (this.modalSedeSearchTerm) {
            const term = this.modalSedeSearchTerm.toLowerCase();
            list = list.filter(row => row.sede.toLowerCase().includes(term));
        }
        return list.map(row => ({
            ...row,
            rowClass: row.isSelected ? 'slds-is-selected' : '',
            isDisabled: !row.isSelected
        }));
    }

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
        // FILTRADO ESTRICTO: Solo mostramos las sedes que el usuario seleccionó en el Paso 2
        const selectedSedes = this.sedesData.filter(sede => this.selectedSedesIds.includes(String(sede.Id)));
        
        if (selectedSedes.length === 0) {
            this.modalTableData = [{ 
                id: 'temp-1', 
                sede: 'Sede Principal (Default)', 
                isSelected: true,
                cantidad: 1, 
                importeTotal: 0, 
                totalSinImpuestos: 0, 
                impuestos: 16, 
                descuento: 0, 
                tipoDescuento: 'monto', 
                tipoDescuentoSimbolo: '$', 
                tipoDescuentoIcon: 'utility:moneybag' 
            }];
        } else {
            this.modalTableData = selectedSedes.map(sede => ({
                id: sede.Id,
                sede: `${sede.AccountName || 'Sede'} - ${sede.MailingCity || ''}`,
                isSelected: true, // Por defecto todas las que pasaron el filtro están seleccionadas
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
        this.modalSedeSearchTerm = '';
        this.showModal = true;
    }

    handleModalSedeSearch(event) {
        this.modalSedeSearchTerm = event.target.value;
    }

    handleSedeRowToggle(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;
        this.modalTableData = this.modalTableData.map(row => {
            if (row.id === id) return { ...row, isSelected: checked };
            return row;
        });
        this.recalculateModalData();
    }

    handleSelectAllSedes(event) {
        const action = event.target.dataset.action;
        const isSelected = (action === 'all');
        this.modalTableData = this.modalTableData.map(row => ({ ...row, isSelected: isSelected }));
        this.recalculateModalData();
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

    handleSaveAndNext() {
        this.processServiceLine(false);
    }

    handleSaveServiceLine() {
        this.processServiceLine(true);
    }

    processServiceLine(shouldClose) {
        if (!this.selectedProductId) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Aviso', message: 'Seleccione un producto', variant: 'warning' }));
            return;
        }

        const selectedRows = this.modalTableData.filter(row => row.isSelected && row.cantidad > 0 && row.importeTotal > 0);
        
        if (selectedRows.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Aviso', 
                message: 'Debe seleccionar al menos una sede con cantidad e importe mayores a cero.', 
                variant: 'warning' 
            }));
            return;
        }

        const newItems = selectedRows.map(row => {
            const rawDetalleTecnico = this.modalDescription ? this.modalDescription.replace(/(<([^>]+)>)/gi, "") : '';
            let truncatedDetalleTecnico = rawDetalleTecnico;
            if (rawDetalleTecnico.length > 255) {
                truncatedDetalleTecnico = rawDetalleTecnico.substring(0, 255);
            }

            const subtotal = row.totalSinImpuestos;
            const taxAmount = subtotal * (row.impuestos / 100);

            return {
                id: `${this.selectedProductId}-${row.id}-${Date.now()}`,
                productId: this.selectedProductId,
                descripcion: `${this.selectedProductName} - ${row.sede}`,
                detalleTecnico: truncatedDetalleTecnico,
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
        
        if (shouldClose) {
            this.showModal = false;
        } else {
            // "Limpieza suave": Resetear producto pero mantener sedes/configuración
            this.selectedProductId = '';
            this.selectedProductName = '';
            this.modalDescription = '';
            this.zonasAfectadas = [];
            this.convertZonas = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'Añadido', message: 'Líneas añadidas correctamente. Puede continuar con otro producto.', variant: 'success' }));
        }
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
                        checked: this.selectedLines.includes(opt.value)
                    }));
                }
            })
            .catch(error => console.error('Error líneas:', error));
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
                if (result.agenteNombre) this.agenteNombre = result.agenteNombre;
                
                if (result.quote) {
                    const q = result.quote;
                    this.asunto = q.Name || '';
                    this.introduccion = q.Introduction_Text__c || '';
                    this.folio = q.QuoteNumber || '';
                    this.warranty = q.Warranty_Text__c || '';
                    this.observacionesPago = q.Description || '';
                    this.showDescription = q.Show_Warranty__c;
                    
                    if (q.Account && q.Account.Name) this.clienteNombre = q.Account.Name;
                    
                    this.fechaCreacion = q.CreatedDate ? q.CreatedDate.split('T')[0] : new Date().toISOString().split('T')[0];
                    
                    if (q.Business_Lines_Selected__c) {
                        this.selectedLines = q.Business_Lines_Selected__c.split(', ');
                    }

                    // RESTAURACIÓN DE ESTADO COMPLETO (UTF-8 SEGURO)
                    if (q.Markers_Data__c) {
                        try {
                            const decodedString = decodeURIComponent(escape(window.atob(q.Markers_Data__c)));
                            const decodedData = JSON.parse(decodedString);

                            if (decodedData.pl1) this.pl1 = decodedData.pl1;
                            if (decodedData.pl2) this.pl2 = decodedData.pl2;
                            if (decodedData.selectedSedesIds) this.selectedSedesIds = [...decodedData.selectedSedesIds];
                            if (decodedData.serviciosData) this.serviciosData = decodedData.serviciosData;
                            
                            // RESTAURAR ESTRATEGIA Y NECESIDAD (Vital para límites de selección)
                            if (decodedData.estrategiaVenta) this.estrategiaVenta = decodedData.estrategiaVenta;
                            if (decodedData.necesidadId) this.necesidadId = decodedData.necesidadId;
                            if (decodedData.necesidadNombre) {
                                this.necesidadNombre = decodedData.necesidadNombre;
                                this.necesidadSeleccionada = decodedData.necesidadNombre;
                            }
                            
                            this.calculateTotals();
                        } catch (e) {
                            console.warn('Fallback a QuoteLineItems:', e);
                            if (q.QuoteLineItems) this.reconstructFromLineItems(q.QuoteLineItems, q.Technical_Sedes__c);
                        }
                    } else if (q.QuoteLineItems) {
                        this.reconstructFromLineItems(q.QuoteLineItems, q.Technical_Sedes__c);
                    }
                }
                
                this.loadBusinessLines();
                
                if (result.contacts) {
                    this.sedesData = result.contacts.map((con, index) => ({
                        ...con,
                        CodigoInterno: `CON-${index + 101}`,
                        AccountName: con.Account ? con.Account.Name : 'Sin Cuenta',
                        MailingStreet: con.MailingStreet || 'Sin calle',
                        MailingCity: con.MailingCity || 'N/A',
                        MailingState: con.MailingState || 'N/A'
                    }));
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error carga:', error);
                this.isLoading = false;
            });
    }

    // Método auxiliar para no ensuciar loadInitialData
    reconstructFromLineItems(lineItems, technicalSedes) {
        this.serviciosData = lineItems.map(item => {
            const nombreProducto = item.Product2 ? item.Product2.Name : 'Producto';
            let sedeExtraida = 'Sede Principal';
            if (technicalSedes) {
                const sedesArray = technicalSedes.split(', ');
                for (let s of sedesArray) {
                    if (item.Description && item.Description.includes(s)) {
                        sedeExtraida = s;
                        break;
                    }
                }
            }

            return {
                id: item.Id,
                productId: item.PricebookEntryId,
                descripcion: nombreProducto,
                detalleTecnico: item.Description,
                detalleTecnicoHtml: item.Description,
                cantidad: item.Quantity,
                sedes: sedeExtraida,
                importeUnitario: item.UnitPrice,
                descuento: item.Discount || 0,
                tipoDescuento: item.Discount > 0 ? 'porcentaje' : 'monto',
                descuentoDisplay: item.Discount > 0 ? `${item.Discount}%` : '-',
                impuesto: '16%',
                taxValue: (item.TotalPrice || (item.Quantity * item.UnitPrice)) * 0.16,
                totalSinImpuestos: item.TotalPrice || (item.Quantity * item.UnitPrice),
                totalConImpuestos: (item.TotalPrice || (item.Quantity * item.UnitPrice)) * 1.16
            };
        });
        this.calculateTotals();
    }

    updateBusinessLineCheckboxes() {
        this.lineaNegocioOptions = this.lineaNegocioOptions.map(opt => ({
            ...opt,
            checked: this.selectedLines.includes(opt.value)
        }));
    }

    handleSedeSelection(event) {
        const selectedRows = event.detail.selectedRows;
        // Forzamos la creación de un nuevo array con strings limpios para asegurar que el Datatable lo reconozca al volver
        this.selectedSedesIds = [...selectedRows.map(row => String(row.Id))]; 
        
        if ((this.clienteNombre === 'Seleccione una sede...' || !this.recordId) && selectedRows.length > 0) {
            this.clienteNombre = selectedRows[0].AccountName;
        }
        console.log('PYATZ LOG: Sedes seleccionadas actualizadas:', JSON.stringify(this.selectedSedesIds));
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

    get maxRowSelection() {
        return this.estrategiaVenta === 'E5' ? 200 : 1; // 200 para múltiples selecciones, 1 para selección única
    }

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

    // LÓGICA DE PAGINACIÓN VISUAL INTELIGENTE PARA EL PASO 4
    get serviciosPaginados() {
        const paginas = [];
        let currentItems = [];
        let currentTitulo = null;
        let pageCounter = 1;
        
        // Sistema de puntos para estimar el espacio:
        // Una hoja carta tiene aprox 25 puntos de capacidad.
        let currentSpaceUsed = 0; 
        const MAX_SPACE_PER_PAGE = 22;
        const SPACE_INTRO = 10; // La introducción y cabecera ocupan mucho espacio
        const SPACE_ITEM = 2;  // Cada fila de producto ocupa 2 puntos
        const SPACE_SEPARATOR = 4; // Un separador ocupa 4 puntos

        this.serviciosData.forEach((item) => {
            const isFirstPage = pageCounter === 1;
            const limit = isFirstPage ? (MAX_SPACE_PER_PAGE - SPACE_INTRO) : MAX_SPACE_PER_PAGE;
            
            let itemCost = item.isSeparator ? SPACE_SEPARATOR : SPACE_ITEM;
            // Si tiene descripción técnica larga, ocupa más espacio
            if (item.detalleTecnicoHtml && item.detalleTecnicoHtml.length > 150) itemCost += 2;

            // ¿Debemos saltar de página? 
            // Saltamos si: es un separador manual O si el nuevo ítem ya no cabe en esta hoja
            if (item.isSeparator || (currentSpaceUsed + itemCost > limit)) {
                
                // Solo guardamos la página si tiene algo (evitar hojas en blanco al inicio)
                if (currentItems.length > 0 || currentTitulo) {
                    paginas.push({
                        id: `page-${pageCounter}`,
                        num: pageCounter,
                        items: [...currentItems],
                        titulo: currentTitulo,
                        isFirst: isFirstPage,
                        isLast: false
                    });
                    pageCounter++;
                    currentItems = [];
                    currentSpaceUsed = 0;
                }

                if (item.isSeparator) {
                    currentTitulo = item.descripcion;
                    currentSpaceUsed = 0; // El título del separador cuenta para la nueva hoja
                } else {
                    currentTitulo = null; // Reiniciar título si fue salto automático
                    currentItems.push(item);
                    currentSpaceUsed = itemCost;
                }
            } else {
                currentItems.push(item);
                currentSpaceUsed += itemCost;
            }
        });

        // Añadir la última página con los ítems restantes
        if (currentItems.length > 0 || paginas.length === 0) {
            paginas.push({
                id: `page-${pageCounter}`,
                num: pageCounter,
                items: currentItems,
                titulo: currentTitulo,
                isFirst: pageCounter === 1,
                isLast: true
            });
        } else if (paginas.length > 0) {
            // Marcar la última página generada como la final (para totales y firmas)
            paginas[paginas.length - 1].isLast = true;
        }

        return paginas;
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
        if (this.currentStep === '4') {
            this.handleFinalize();
        } else {
            // AUTOGUARDADO SILENCIOSO AL CAMBIAR DE PASO
            if (this.currentStep === '1' || this.currentStep === '2') {
                this.autoSaveDraft();
            }
            this.currentStep = (parseInt(this.currentStep) + 1).toString();
        }
    }

    autoSaveDraft() {
        // Ejecutamos un guardado sin mostrar notificaciones de éxito invasivas
        const payload = this.preparePayload('Draft');
        saveTechnicalData({ data: payload })
            .then(newId => {
                if (newId) {
                    this.recordId = newId;
                    // RECARGAR DATOS PARA TRAER EL FOLIO (QuoteNumber)
                    this.loadInitialData();
                    console.log('Autoguardado exitoso. RecordId:', this.recordId);
                }
            })
            .catch(error => {
                console.error('Error en autoguardado:', error);
            });
    }

    handleSaveDraft() {
        this.handleSave('Draft');
    }

    handleFinalize() {
        this.handleSave('Presented'); 
    }

    preparePayload(statusValue) {
        let inferredAccountId = null;
        let inferredContactId = null;
        if (this.selectedSedesIds.length > 0) {
            const firstSede = this.sedesData.find(s => String(s.Id) === String(this.selectedSedesIds[0]));
            if (firstSede) {
                inferredAccountId = firstSede.AccountId;
                inferredContactId = firstSede.Id;
            }
        }

        const cleanLines = this.selectedLines.length > 0 ? this.selectedLines.join(', ') : '';

        const fullState = {
            pl1: this.pl1,
            pl2: this.pl2,
            selectedSedesIds: this.selectedSedesIds,
            serviciosData: this.serviciosData,
            estrategiaVenta: this.estrategiaVenta,
            necesidadId: this.necesidadId,
            necesidadNombre: this.necesidadNombre
        };

        // CODIFICACIÓN SEGURA PARA UTF-8 (Soporta acentos y caracteres especiales)
        const stateJson = JSON.stringify(fullState);
        const encodedState = window.btoa(unescape(encodeURIComponent(stateJson)));

        return {
            quoteId: this.recordId,
            accountId: inferredAccountId,
            contactId: inferredContactId,
            name: this.asunto,
            status: statusValue,
            intro: this.mergeDynamicTags(this.introduccion),
            warranty: this.mergeDynamicTags(this.warranty),
            businessLines: cleanLines,
            technicalSedes: this.selectedSedesDisplay,
            lineItems: JSON.stringify(this.serviciosData),
            showIntro: this.showDescription, 
            showWarranty: this.showDescription,
            observacionesPago: this.observacionesPago,
            pagoTransferencia: this.pagoTransferencia,
            pagoTarjeta: this.pagoTarjeta,
            ventaProducto: this.ventaProducto,
            markersData: encodedState
        };
    }

    handleSave(statusValue) {
        this.isLoading = true;
        try {
            const payload = this.preparePayload(statusValue);
            saveTechnicalData({ data: payload })
            .then((newId) => {
                this.isLoading = false;
                const msg = statusValue === 'Draft' ? 'Borrador guardado' : 'Cotización finalizada con éxito';
                this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: msg, variant: 'success' }));
                
                if (newId) {
                    this.recordId = newId;
                    this.loadInitialData();
                }
                this.dispatchEvent(new CustomEvent('save', { detail: this.recordId }));
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error Apex:', error);
                let errorMessage = error.body ? error.body.message : error.message;
                this.dispatchEvent(new ShowToastEvent({ title: 'Error Salesforce', message: errorMessage, variant: 'error', mode: 'sticky' }));
            });
        } catch (error) {
            this.isLoading = false;
            console.error('Error JS:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error de Datos', message: 'Hay caracteres no permitidos en las descripciones.', variant: 'error' }));
        }
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

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Archivo adjuntado',
            message: 'Se han cargado ' + uploadedFiles.length + ' archivos correctamente.',
            variant: 'success'
        }));
    }
}