import { LightningElement, api, track, wire } from 'lwc';
import searchProducts from '@salesforce/apex/QuoteController.searchProducts';
import getProductPrices from '@salesforce/apex/QuoteController.getProductPrices';
import getProductInfoByPBE from '@salesforce/apex/QuoteController.getProductInfoByPBE';
import getOpportunityLevantamientos from '@salesforce/apex/QuoteController.getOpportunityLevantamientos';
import getHistoricalZones from '@salesforce/apex/QuoteController.getHistoricalZones';

export default class TechQuoteItemConfigurator extends LightningElement {
    @api recordId;
    @api opportunityId;
    @api accountId; 
    @api selectedSedesObjects = [];
    @api selectedLines = [];
    @api allowOtherLines = false;
    
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
    @track allHistoricalZones = [];
    @track zonasAfectadas = [];

    @track selectedProductId = '';
    @track selectedPbeId = '';
    @track selectedProductName = '';
    @track selectedProductPrice = 0;
    @track productPriceOptions = [];
    @track modalTableData = []; 
    @track modalDescription = '';
    @track isUnitario = true;
    @track isTotal = false;

    get mappedHistoricalZones() {
        const allPossibleZones = new Set([...this.allHistoricalZones]);
        this.zonasAfectadas.forEach(z => allPossibleZones.add(z));
        const selectedSet = new Set(this.zonasAfectadas.map(z => z.trim().toLowerCase()));
        
        return Array.from(allPossibleZones).sort().map(zoneName => {
            return {
                name: zoneName,
                isSelected: selectedSet.has(zoneName.trim().toLowerCase())
            };
        });
    }

    @wire(getHistoricalZones, { accountId: '$accountId' })
    wiredZones({ error, data }) {
        if (data) {
            this.allHistoricalZones = data;
            this.normalizeExistingZones();
        } else if (error) {
            console.error('Error cargando zonas históricas:', error);
        }
    }

    normalizeExistingZones() {
        if (!this.allHistoricalZones || this.allHistoricalZones.length === 0 || this.zonasAfectadas.length === 0) return;
        const catalogMap = new Map();
        this.allHistoricalZones.forEach(z => catalogMap.set(z.toLowerCase().trim(), z));
        const normalized = this.zonasAfectadas.map(z => {
            const lower = z.toLowerCase().trim();
            return catalogMap.has(lower) ? catalogMap.get(lower) : z;
        });
        this.zonasAfectadas = [...new Set(normalized)];
    }

    @wire(getOpportunityLevantamientos, { oppId: '$opportunityId' })
    wiredLevantamientos({ error, data }) {
        if (data) {
            this.levantamientoOptions = data;
        } else if (error) {
            console.error('Error cargando levantamientos:', error);
        }
    }

    handleLevantamientoChange(event) { this.selectedLevantamientoId = event.detail.value; }

    get priceTypeOptions() { return [ { label: 'Unitario', value: 'UNITARIO' }, { label: 'Total', value: 'TOTAL' } ]; }
    get selectedPriceType() { return this.isUnitario ? 'UNITARIO' : 'TOTAL'; }
    get isAddDisabled() { return !this.selectedProductId && !this.selectedPbeId; }
    get modalTitle() { return this._editItem ? 'Editar Partida Técnica' : 'Configurador de Partida Técnica'; }
    get saveButtonLabel() { return this._editItem ? 'Actualizar Partida' : 'Confirmar Partida'; }
    get discountOptions() { return [ { label: '$', value: 'monto' }, { label: '%', value: 'porcentaje' } ]; }

    formatDescription(text) {
        if (!text) return '';
        let cleanText = text.replace(/<br\s*\/?>/gi, '\n');
        cleanText = cleanText.replace(/<[^>]*>?/gm, '');
        return cleanText;
    }

    loadEditData(item) {
        this.selectedPbeId = item.pbeId;
        this.selectedProductName = item.descripcion;
        this.modalDescription = this.formatDescription(item.detalleTecnico);
        const rawAreas = item.areas ? item.areas.split(',').map(a => a.trim()).filter(a => a !== '') : [];
        this.zonasAfectadas = [...new Set(rawAreas)];
        if (this.allHistoricalZones && this.allHistoricalZones.length > 0) this.normalizeExistingZones();
        
        if (item.productId) {
            this.selectedProductId = item.productId;
            this.loadProductPrices();
        } else {
            getProductInfoByPBE({ pbeId: this.selectedPbeId }).then(res => { this.selectedProductId = res.productId; this.loadProductPrices(); }).catch(err => console.error(err));
        }

        const sedesVinculadas = item.sedes ? item.sedes.split(',').map(s => s.trim()) : [];
        this.modalTableData = this.selectedSedesObjects.map(s => {
            const isMatch = sedesVinculadas.includes(s.Name);
            return { id: s.Id, sede: s.Name, isSelected: isMatch, cantidad: item.cantidad, importeTotal: item.totalSinImpuestos / (item.cantidad || 1), descuento: 0, tipoDescuento: 'monto', totalSinImpuestos: item.totalSinImpuestos, impuestos: 16 };
        });
        this.selectedProductPrice = item.totalSinImpuestos / (item.cantidad || 1);
        this.selectedLevantamientoId = item.levantamientoId || '';
    }

    handleToggleGlobalSearch(event) {
        this.allowOtherLines = event.target.checked;
        if (this.selectedProductName && this.selectedProductName.length >= 2) this.handleProductSearch({ target: { value: this.selectedProductName } });
    }

    handleProductSearch(event) {
        const term = event.target.value;
        this.selectedProductName = term;
        if (term.length >= 2) {
            searchProducts({ searchTerm: term, quoteId: this.recordId, businessLines: this.selectedLines, allowOtherLines: this.allowOtherLines }).then(res => { this.searchResults = res; }).catch(err => console.error(err));
        } else this.searchResults = [];
    }

    handleProductSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const res = this.searchResults.find(x => x.id === selectedId);
        if (res) {
            this.selectedPbeId = selectedId; this.selectedProductId = res.productId; this.selectedProductName = res.name; this.selectedProductPrice = res.unitPrice;
            this.modalDescription = this.formatDescription(res.description); this.searchResults = []; this.loadProductPrices(); this.initModalTable();
        }
    }

    handleDescriptionChange(event) { this.modalDescription = event.target.value; }

    loadProductPrices() {
        if (!this.selectedProductId) return;
        getProductPrices({ product2Id: this.selectedProductId }).then(res => { this.productPriceOptions = res.map(opt => ({ ...opt, className: opt.pbeId === this.selectedPbeId ? 'price-option-card selected' : 'price-option-card' })); });
    }

    initModalTable() {
        this.modalTableData = this.selectedSedesObjects.map(s => ({ id: s.Id, sede: s.Name, isSelected: true, cantidad: 1, importeTotal: this.selectedProductPrice, descuento: 0, tipoDescuento: 'monto', totalSinImpuestos: this.selectedProductPrice, impuestos: 16 }));
    }

    handlePriceOptionSelect(event) {
        const pbeId = event.currentTarget.dataset.id;
        const opt = this.productPriceOptions.find(o => o.pbeId === pbeId);
        if (opt) {
            this.selectedPbeId = pbeId; this.selectedProductPrice = opt.unitPrice;
            this.productPriceOptions = this.productPriceOptions.map(o => ({ ...o, className: o.pbeId === pbeId ? 'price-option-card selected' : 'price-option-card' }));
            this.modalTableData = this.modalTableData.map(row => ({ ...row, importeTotal: opt.unitPrice }));
            this.recalculateModalData();
        }
    }

    handlePriceType(event) {
        const type = event.target.value;
        this.isUnitario = (type === 'UNITARIO'); this.isTotal = !this.isUnitario;
        this.recalculateModalData();
    }

    handleToggleZone(event) {
        const zoneName = event.target.dataset.name;
        const isChecked = event.target.checked;
        if (isChecked) {
            const exists = this.zonasAfectadas.some(z => z.toLowerCase().trim() === zoneName.toLowerCase().trim());
            if (!exists) this.zonasAfectadas = [...this.zonasAfectadas, zoneName];
        } else {
            this.zonasAfectadas = this.zonasAfectadas.filter(z => z.toLowerCase().trim() !== zoneName.toLowerCase().trim());
        }
    }

    removeZona(event) {
        const zona = event.target.name;
        this.zonasAfectadas = this.zonasAfectadas.filter(z => z.toLowerCase().trim() !== zona.toLowerCase().trim());
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
            let base = this.isUnitario ? (row.importeTotal * row.cantidad) : (row.cantidad !== 0 ? (row.importeTotal / row.cantidad) : 0);
            let finalTotal = base;
            if (row.tipoDescuento === 'monto') finalTotal = base - (row.descuento || 0);
            else if (row.tipoDescuento === 'porcentaje') finalTotal = base * (1 - ((row.descuento || 0) / 100));
            return { ...row, totalSinImpuestos: finalTotal };
        });
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('close')); }

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