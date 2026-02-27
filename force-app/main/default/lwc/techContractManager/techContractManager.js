import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteLineItems from '@salesforce/apex/QuoteContractPDFController.getQuoteLineItems';

export default class TechContractManager extends NavigationMixin(LightningElement) {
    @api recordId;

    @track quoteLineItems = [];
    @track totals = { subtotal: 0, descuento: 0, iva: 0, total: 0 };
    @track isLoading = true;
    
    // Estados para modales
    @track showEditModal = false;
    @track editingItem = {};
    @track editingIndex = -1;

    @track selections = {
        legal_clauses: true,
        confidentiality: false,
        technical_summary: true,
        photo_gallery: false,
        annual_calendar: false,
        tax_retentions: false,
        company_seal: true
    };

    @track frecuencia = 'mensual';

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
            this.fetchLineItems();
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this.fetchLineItems();
        }
    }

    fetchLineItems() {
        this.isLoading = true;
        getQuoteLineItems({ quoteId: this.recordId })
            .then(result => {
                this.quoteLineItems = result.map(item => ({
                    ...item,
                    ProductCode: item.Product2 ? item.Product2.ProductCode : '---',
                    ProductName: item.Product2 ? item.Product2.Name : 'Producto',
                    Sede: item.Quote ? item.Quote.Technical_Sedes__c : '---',
                    DescuentoDisplay: item.Discount ? `${item.Discount}%` : '-',
                    isSelected: true
                }));
                this.calculateTotals();
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error cargando partidas:', error);
            });
    }

    // ACCIÓN: Eliminar fila del contrato
    handleRemoveItem(event) {
        const index = event.target.dataset.index;
        const data = [...this.quoteLineItems];
        data.splice(index, 1);
        this.quoteLineItems = data;
        this.calculateTotals();
        
        this.dispatchEvent(new ShowToastEvent({
            title: 'Ítem Removido',
            message: 'El servicio fue eliminado del contrato local.',
            variant: 'info'
        }));
    }

    // ACCIÓN: Editar fila
    handleEditItem(event) {
        const index = event.target.dataset.index;
        this.editingIndex = index;
        this.editingItem = { ...this.quoteLineItems[index] };
        this.showEditModal = true;
    }

    handleEditInputChange(event) {
        const field = event.target.dataset.field;
        const value = field === 'Description' ? event.target.value : (parseFloat(event.target.value) || 0);
        this.editingItem[field] = value;
    }

    handleCloseEditModal() {
        this.showEditModal = false;
    }

    handleSaveItemChanges() {
        // Actualizar la línea y recalcular el total de la fila
        const data = [...this.quoteLineItems];
        const updatedItem = { ...this.editingItem };
        
        // Recalcular TotalPrice si cambió Cantidad o UnitPrice
        updatedItem.TotalPrice = updatedItem.Quantity * updatedItem.UnitPrice;
        
        data[this.editingIndex] = updatedItem;
        this.quoteLineItems = data;
        this.calculateTotals();
        this.showEditModal = false;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Cambios Guardados',
            message: 'Se actualizó el servicio en este contrato.',
            variant: 'success'
        }));
    }

    handleItemToggle(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;
        this.quoteLineItems = this.quoteLineItems.map(item => {
            if (item.Id === itemId) return { ...item, isSelected: checked };
            return item;
        });
        this.calculateTotals();
    }

    calculateTotals() {
        let subtotal = 0;
        let descTotal = 0;
        
        this.quoteLineItems.forEach(item => {
            if (item.isSelected) {
                const rowBase = (item.Quantity || 0) * (item.UnitPrice || 0);
                subtotal += rowBase;
                if (item.Discount) {
                    descTotal += (rowBase * (item.Discount / 100));
                }
            }
        });

        const subtotalNeto = subtotal - descTotal;
        const iva = subtotalNeto * 0.16;
        
        this.totals = {
            subtotal: subtotal,
            descuento: descTotal,
            iva: iva,
            total: subtotalNeto + iva
        };
    }

    // CONFIGURACIÓN VISUAL
    get showCalendarOptions() {
        return this.selections.annual_calendar;
    }

    get frecuenciaOptions() {
        return [
            { label: 'Semanal (52)', value: 'semanal' },
            { label: 'Quincenal (24)', value: 'quincenal' },
            { label: 'Mensual (12)', value: 'mensual' },
            { label: 'Bimestral (6)', value: 'bimestral' },
            { label: 'Único (1)', value: 'unico' }
        ];
    }

    handleToggle(event) {
        const id = event.target.dataset.id;
        this.selections[id] = event.target.checked;
    }

    handleFrecuenciaChange(event) {
        this.frecuencia = event.detail.value;
    }

    handleReset() {
        this.fetchLineItems(); // Recargar todo del servidor
        this.selections = {
            legal_clauses: true,
            confidentiality: false,
            technical_summary: true,
            photo_gallery: false,
            annual_calendar: false,
            tax_retentions: false,
            company_seal: true
        };
    }

    handleGenerateContract() {
        const selectedIds = this.quoteLineItems
            .filter(item => item.isSelected)
            .map(item => item.Id);

        if (selectedIds.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Atención', message: 'Seleccione al menos un servicio.', variant: 'warning' }));
            return;
        }

        let baseUrl = '/apex/QuoteContractPDF?id=' + this.recordId;
        baseUrl += '&selectedItems=' + selectedIds.join(',');
        
        Object.keys(this.selections).forEach(key => {
            if (this.selections[key]) baseUrl += `&${key}=true`;
        });

        if (this.selections.annual_calendar) {
            baseUrl += `&frecuencia=${this.frecuencia}`;
        }

        window.open(baseUrl, '_blank');
        this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Generando contrato...', variant: 'success' }));
    }
}