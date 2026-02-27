import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteLineItems from '@salesforce/apex/QuoteContractPDFController.getQuoteLineItems';
import searchUsers from '@salesforce/apex/QuoteTechnicalController.searchUsers';

export default class TechContractManager extends NavigationMixin(LightningElement) {
    @api recordId;

    @track quoteLineItems = [];
    @track totals = { total: 0 };
    @track isLoading = true;
    
    // Configuración de visualización
    @track selections = { show_total: true, show_line_prices: true };

    // Responsables
    @track userSearchTermCreator = '';
    @track userSearchTermManager = '';
    @track userResultsCreator = [];
    @track userResultsManager = [];
    @track selectedCreator = { id: '', name: '' };
    @track selectedManager = { id: '', name: '' };

    // Firmante del Cliente (Temporal)
    @track selectedClientSigner = '';
    get clientSignerOptions() {
        return [
            { label: 'Juan Pérez (Director)', value: 'Juan Pérez' },
            { label: 'María García (Compras)', value: 'María García' },
            { label: 'Representante Legal', value: 'Representante Legal' }
        ];
    }

    // Firma
    @track signatureSource = 'creator'; // 'creator' o 'manager'

    // Datos del Contacto
    @track isManualContract = false;
    @track fechaPrimerServicio = '';
    @track fechaLimiteServicio = '';

    // Vigencia y Observaciones
    @track fechaInicioContrato = '';
    @track fechaFinContrato = '';
    @track observacionesPrivadas = '';
    @track observacionesRenovacion = '';

    // Plantillas
    @track plantillaSeleccionada = '';
    @track contenidoLegal = '';

    get plantillaOptions() {
        return [
            { label: 'Condiciones Estándar Pyatz', value: 'estandar' },
            { label: 'Anexo Técnico Liverpool', value: 'liverpool' },
            { label: 'Cláusula de Confidencialidad', value: 'confidencial' }
        ];
    }

    get selectedClientSignerDisplay() {
        return this.selectedClientSigner || 'No seleccionado';
    }

    // Modales
    @track showEditModal = false;
    @track editingItem = {};
    @track editingIndex = -1;

    get isSignatureCreator() { return this.signatureSource === 'creator'; }
    get isSignatureManager() { return this.signatureSource === 'manager'; }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
            this.fetchLineItems();
        }
    }

    connectedCallback() {
        if (this.recordId) this.fetchLineItems();
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
                console.error(error);
            });
    }

    // BÚSQUEDA DE USUARIOS
    handleUserSearch(event) {
        const type = event.target.dataset.type;
        const term = event.target.value;
        if (type === 'creator') this.userSearchTermCreator = term;
        else this.userSearchTermManager = term;

        if (term.length >= 2) {
            searchUsers({ searchTerm: term })
                .then(result => {
                    if (type === 'creator') this.userResultsCreator = result;
                    else this.userResultsManager = result;
                })
                .catch(error => console.error(error));
        } else {
            this.userResultsCreator = [];
            this.userResultsManager = [];
        }
    }

    handleUserSelect(event) {
        const type = event.currentTarget.dataset.type;
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;

        if (type === 'creator') {
            this.selectedCreator = { id, name };
            this.userResultsCreator = [];
            this.userSearchTermCreator = '';
        } else {
            this.selectedManager = { id, name };
            this.userResultsManager = [];
            this.userSearchTermManager = '';
        }
    }

    handleRemoveCreator() { this.selectedCreator = { id: '', name: '' }; }
    handleRemoveManager() { this.selectedManager = { id: '', name: '' }; }

    handleClientSignerChange(event) {
        this.selectedClientSigner = event.detail.value;
    }

    // GESTIÓN DE FIRMA (Excluyente)
    handleSignatureToggle(event) {
        this.signatureSource = event.target.dataset.id;
    }

    // GESTIÓN DATOS CONTACTO
    handleManualContractToggle(event) {
        this.isManualContract = event.target.checked;
    }

    handleDateChange(event) {
        const id = event.target.dataset.id;
        if (id === 'primerServicio') this.fechaPrimerServicio = event.target.value;
        else this.fechaLimiteServicio = event.target.value;
    }

    handleVigenciaChange(event) {
        const id = event.target.dataset.id;
        if (id === 'inicio') this.fechaInicioContrato = event.target.value;
        else this.fechaFinContrato = event.target.value;
    }

    handleObsChange(event) {
        const id = event.target.dataset.id;
        if (id === 'privadas') this.observacionesPrivadas = event.target.value;
        else this.observacionesRenovacion = event.target.value;
    }

    handlePlantillaChange(event) {
        this.plantillaSeleccionada = event.detail.value;
        // Simulación de carga de contenido basado en selección
        if (this.plantillaSeleccionada === 'estandar') {
            this.contenidoLegal = '<h2>Condiciones Estándar</h2><p>El presente documento establece que los servicios se realizarán conforme a la NOM vigente...</p>';
        } else if (this.plantillaSeleccionada === 'liverpool') {
            this.contenidoLegal = '<h2>Anexo Liverpool</h2><ul><li>Horario de acceso: 22:00 - 06:00</li><li>EPP Obligatorio</li></ul>';
        } else {
            this.contenidoLegal = '<p>Texto legal personalizado...</p>';
        }
    }

    handleContenidoChange(event) {
        this.contenidoLegal = event.target.value;
    }

    // GESTIÓN DE PARTIDAS
    handleItemToggle(event) {
        const itemId = event.target.dataset.id;
        this.quoteLineItems = this.quoteLineItems.map(item => {
            if (item.Id === itemId) return { ...item, isSelected: event.target.checked };
            return item;
        });
        this.calculateTotals();
    }

    handleRemoveItem(event) {
        const index = event.target.dataset.index;
        const data = [...this.quoteLineItems];
        data.splice(index, 1);
        this.quoteLineItems = data;
        this.calculateTotals();
    }

    handleEditItem(event) {
        this.editingIndex = event.target.dataset.index;
        this.editingItem = { ...this.quoteLineItems[this.editingIndex] };
        this.showEditModal = true;
    }

    handleEditInputChange(event) {
        const field = event.target.dataset.field;
        const value = field === 'Description' ? event.target.value : (parseFloat(event.target.value) || 0);
        this.editingItem[field] = value;
    }

    handleSaveItemChanges() {
        const data = [...this.quoteLineItems];
        const updated = { ...this.editingItem };
        updated.TotalPrice = updated.Quantity * updated.UnitPrice;
        data[this.editingIndex] = updated;
        this.quoteLineItems = data;
        this.calculateTotals();
        this.showEditModal = false;
    }

    handleCloseEditModal() { this.showEditModal = false; }

    calculateTotals() {
        let total = 0;
        this.quoteLineItems.forEach(item => {
            if (item.isSelected) {
                const base = (item.Quantity || 0) * (item.UnitPrice || 0);
                const desc = item.Discount ? (base * (item.Discount / 100)) : 0;
                total += (base - desc) * 1.16;
            }
        });
        this.totals = { total };
    }

    handleToggle(event) {
        this.selections[event.target.dataset.id] = event.target.checked;
    }

    handleReset() {
        this.fetchLineItems();
        this.selectedCreator = { id: '', name: '' };
        this.selectedManager = { id: '', name: '' };
        this.signatureSource = 'creator';
    }

    handleGenerateContract() {
        if (!this.selectedCreator.id) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'El campo "Creado por" es obligatorio.', variant: 'error' }));
            return;
        }

        // PENDIENTE DEFINIR: ¿Quieres que estas fechas o el check manual tengan algún comportamiento especial al generar el PDF?
        const selectedIds = this.quoteLineItems.filter(item => item.isSelected).map(item => item.Id);
        let url = `/apex/QuoteContractPDF?id=${this.recordId}&selectedItems=${selectedIds.join(',')}`;
        url += `&show_total=${this.selections.show_total}&show_line_prices=${this.selections.show_line_prices}`;
        url += `&createdBy=${this.selectedCreator.id}&managedBy=${this.selectedManager.id}&sigSource=${this.signatureSource}`;
        url += `&clientSigner=${encodeURIComponent(this.selectedClientSigner)}`;

        window.open(url, '_blank');
    }
}