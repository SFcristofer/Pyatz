import { LightningElement, api, track, wire } from 'lwc';
import searchProducts from '@salesforce/apex/QuoteController.searchProducts';
import getProductPrices from '@salesforce/apex/QuoteController.getProductPrices';
import getProductInfoByPBE from '@salesforce/apex/QuoteController.getProductInfoByPBE';
import getOpportunityLevantamientos from '@salesforce/apex/QuoteController.getOpportunityLevantamientos';
import getHistoricalZones from '@salesforce/apex/QuoteController.getHistoricalZones';

export default class TechQuoteItemConfigurator extends LightningElement {
    @api recordId;
    @api opportunityId;
    @api accountId; // Recibido desde el editor padre
    @api selectedSedesObjects = [];
    @api selectedLines = [];
    @api allowOtherLines = false;
    
    // Nueva propiedad para modo edición
    @api 
    get editItem() { return this._editItem; }
    set editItem(value) {
        this._editItem = value;
        if (value) {
            this.loadEditData(value);
        }
    }
    _editItem;

    @track levantamientoOptions = [];
    @track selectedLevantamientoId = '';
    @track searchResults = [];

    // Sugerencias de Zonas
    @track allHistoricalZones = [];
    @track filteredZoneSuggestions = [];

    @wire(getHistoricalZones, { accountId: '$accountId' })
    wiredZones({ error, data }) {
        if (data) {
            this.allHistoricalZones = data;
        } else if (error) {
            console.error('Error cargando zonas históricas:', error);
        }
    }

    @wire(getOpportunityLevantamientos, { oppId: '$opportunityId' })
    wiredLevantamientos({ error, data }) {
        if (data) {
            this.levantamientoOptions = data;
        } else if (error) {
            console.error('Error cargando levantamientos:', error);
        }
    }

    handleLevantamientoChange(event) {
        this.selectedLevantamientoId = event.detail.value;
    }
    @track selectedProductId = '';
    @track selectedPbeId = '';
    @track selectedProductName = '';
    @track selectedProductPrice = 0;
    @track productPriceOptions = [];
    @track modalTableData = []; 
    @track modalDescription = '';
    @track isUnitario = true;
    @track isTotal = false;
    @track zonaInput = '';
    @track zonasAfectadas = [];

    get priceTypeOptions() {
        return [
            { label: 'Unitario', value: 'UNITARIO' },
            { label: 'Total', value: 'TOTAL' }
        ];
    }

    get selectedPriceType() {
        return this.isUnitario ? 'UNITARIO' : 'TOTAL';
    }

    get isAddDisabled() {
        return !this.selectedProductId && !this.selectedPbeId;
    }

    get modalTitle() {
        return this._editItem ? 'Editar Partida Técnica' : 'Configurador de Partida Técnica';
    }

    get saveButtonLabel() {
        return this._editItem ? 'Actualizar Partida' : 'Confirmar Partida';
    }

    get discountOptions() {
        return [
            { label: '$', value: 'monto' },
            { label: '%', value: 'porcentaje' }
        ];
    }

    // Función auxiliar para limpiar HTML y preservar saltos de línea reales
    formatDescription(text) {
        if (!text) return '';
        // Convertimos etiquetas <br> en saltos de línea reales (\n) y eliminamos etiquetas HTML
        let cleanText = text.replace(/<br\s*\/?>/gi, '\n');
        cleanText = cleanText.replace(/<[^>]*>?/gm, '');
        return cleanText;
    }

    loadEditData(item) {
        console.log('--- Cargando datos de edición:', JSON.stringify(item));
        this.selectedPbeId = item.pbeId;
        this.selectedProductName = item.descripcion;
        // Limpiamos formato al cargar para editar
        this.modalDescription = this.formatDescription(item.detalleTecnico);
        this.zonasAfectadas = item.areas ? item.areas.split(',').map(a => a.trim()) : [];
        
        if (item.productId) {
            this.selectedProductId = item.productId;
            this.loadProductPrices();
        } else {
            getProductInfoByPBE({ pbeId: this.selectedPbeId })
                .then(res => {
                    this.selectedProductId = res.productId;
                    this.loadProductPrices();
                })
                .catch(err => console.error('Error recuperando producto:', err));
        }

        const sedesVinculadas = item.sedes ? item.sedes.split(',').map(s => s.trim()) : [];
        this.modalTableData = this.selectedSedesObjects.map(s => {
            const isMatch = sedesVinculadas.includes(s.Name);
            return {
                id: s.Id, sede: s.Name, isSelected: isMatch, cantidad: item.cantidad, 
                importeTotal: item.totalSinImpuestos / (item.cantidad || 1), 
                descuento: 0, tipoDescuento: 'monto', totalSinImpuestos: item.totalSinImpuestos, impuestos: 16
            };
        });
        this.selectedProductPrice = item.totalSinImpuestos / (item.cantidad || 1);
        this.selectedLevantamientoId = item.levantamientoId || '';
    }

    handleToggleGlobalSearch(event) {
        this.allowOtherLines = event.target.checked;
        if (this.selectedProductName && this.selectedProductName.length >= 2) {
            this.handleProductSearch({ target: { value: this.selectedProductName } });
        }
    }

    handleProductSearch(event) {
        const term = event.target.value;
        this.selectedProductName = term;
        if (term.length >= 2) {
            searchProducts({ 
                searchTerm: term, 
                quoteId: this.recordId, 
                businessLines: this.selectedLines, 
                allowOtherLines: this.allowOtherLines 
            })
            .then(res => { this.searchResults = res; })
            .catch(err => console.error(err));
        } else {
            this.searchResults = [];
        }
    }

    handleProductSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const res = this.searchResults.find(x => x.id === selectedId);
        if (res) {
            this.selectedPbeId = selectedId;
            this.selectedProductId = res.productId;
            this.selectedProductName = res.name;
            this.selectedProductPrice = res.unitPrice;
            // Limpiamos formato al seleccionar producto nuevo
            this.modalDescription = this.formatDescription(res.description);
            this.searchResults = [];
            this.loadProductPrices();
            this.initModalTable();
        }
    }

    handleDescriptionChange(event) {
        this.modalDescription = event.target.value;
    }

    loadProductPrices() {
        if (!this.selectedProductId) return;
        getProductPrices({ product2Id: this.selectedProductId }).then(res => { 
            this.productPriceOptions = res.map(opt => ({
                ...opt,
                className: opt.pbeId === this.selectedPbeId ? 'price-option-card selected' : 'price-option-card'
            })); 
        });
    }

    initModalTable() {
        this.modalTableData = this.selectedSedesObjects.map(s => ({
            id: s.Id, 
            sede: s.Name, 
            isSelected: true, 
            cantidad: 1, 
            importeTotal: this.selectedProductPrice, 
            descuento: 0, 
            tipoDescuento: 'monto', 
            totalSinImpuestos: this.selectedProductPrice, 
            impuestos: 16
        }));
    }

    handlePriceOptionSelect(event) {
        const pbeId = event.currentTarget.dataset.id;
        const opt = this.productPriceOptions.find(o => o.pbeId === pbeId);
        if (opt) {
            this.selectedPbeId = pbeId;
            this.selectedProductPrice = opt.unitPrice;
            this.productPriceOptions = this.productPriceOptions.map(o => ({ 
                ...o, 
                className: o.pbeId === pbeId ? 'price-option-card selected' : 'price-option-card' 
            }));
            
            // Sincronizar el nuevo precio con todas las filas de la tabla
            this.modalTableData = this.modalTableData.map(row => ({
                ...row,
                importeTotal: opt.unitPrice
            }));

            this.recalculateModalData();
        }
    }

    handlePriceType(event) {
        const type = event.target.value;
        this.isUnitario = (type === 'UNITARIO');
        this.isTotal = !this.isUnitario;
        this.recalculateModalData();
    }

    handleToggleZone(event) {
        const zoneName = event.target.dataset.name;
        const isChecked = event.target.checked;

        if (isChecked) {
            if (!this.zonasAfectadas.includes(zoneName)) {
                this.zonasAfectadas = [...this.zonasAfectadas, zoneName];
            }
        } else {
            this.zonasAfectadas = this.zonasAfectadas.filter(z => z !== zoneName);
        }
    }

    removeZona(event) {
        const zona = event.target.name;
        this.zonasAfectadas = this.zonasAfectadas.filter(z => z !== zona);
        // Desmarcar también en la lista visual si existe
    }

    handleModalInputChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const checked = event.target.checked;
        const val = field === 'isSelected' ? checked : (field === 'tipoDescuento' ? event.target.value : (parseFloat(event.target.value) || 0));
        
        this.modalTableData = this.modalTableData.map(row => (row.id === id ? { ...row, [field]: val } : row));
        this.recalculateModalData();
    }

    recalculateModalData() {
        this.modalTableData = this.modalTableData.map(row => {
            // Modo Unitario: Multiplica | Modo Total: Divide Importe / Cantidad
            let base = this.isUnitario ? 
                (row.importeTotal * row.cantidad) : 
                (row.cantidad !== 0 ? (row.importeTotal / row.cantidad) : 0);
            
            let finalTotal = base;
            if (row.tipoDescuento === 'monto') {
                finalTotal = base - (row.descuento || 0);
            } else if (row.tipoDescuento === 'porcentaje') {
                finalTotal = base * (1 - ((row.descuento || 0) / 100));
            }
            return { ...row, totalSinImpuestos: finalTotal };
        });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        const selectedRows = this.modalTableData.filter(r => r.isSelected);
        const newItems = selectedRows.map(row => ({
            id: this._editItem ? this._editItem.id : (Date.now().toString() + Math.random()),
            pbeId: this.selectedPbeId,
            productId: this.selectedProductId,
            descripcion: this.selectedProductName,
            cantidad: row.cantidad,
            totalSinImpuestos: row.totalSinImpuestos,
            sedes: row.sede,
            areas: this.zonasAfectadas.join(', '),
            detalleTecnico: this.modalDescription,
            levantamientoId: this.selectedLevantamientoId,
            rowClass: 'row-service'
        }));

        this.dispatchEvent(new CustomEvent('add', { detail: newItems }));
    }
}