import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import getQuoteLineItems from '@salesforce/apex/QuoteContractPDFController.getQuoteLineItems';
import searchUsers from '@salesforce/apex/QuoteController.searchUsers';
import getContractInitialData from '@salesforce/apex/QuoteController.getContractInitialData';
import saveContractData from '@salesforce/apex/QuoteController.saveContractData';
import getEmailTemplatesByFolder from '@salesforce/apex/QuoteController.getEmailTemplatesByFolder';
import renderTemplate from '@salesforce/apex/QuoteController.renderTemplate';

export default class TechContractManager extends NavigationMixin(LightningElement) {
    @api recordId; // ID de la Oportunidad

    // Datos de Selección
    @track availableQuotes = [];
    @track selectedQuoteId = '';
    @track selectedQuoteName = '';
    @track syncedQuoteId = '';
    
    // Partidas y Totales
    @track quoteLineItems = [];
    @track totals = { total: 0 };
    @track isLoading = true;
    
    // Configuración
    @track selections = { show_total: true, show_line_prices: true };
    @track contactOptions = [];

    // Responsables
    @track userSearchTermCreator = '';
    @track userSearchTermManager = '';
    @track userResultsCreator = [];
    @track userResultsManager = [];
    @track selectedCreator = { id: '', name: '' };
    @track selectedManager = { id: '', name: '' };

    // --- MEJORA: AUTOCOMPLETAR USUARIO ACTUAL ---
    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            const userName = data.fields.Name.value;
            if (!this.selectedCreator.id) {
                this.selectedCreator = { id: USER_ID, name: userName };
            }
        } else if (error) {
            console.error('Error obteniendo usuario actual:', error);
        }
    }

    // Firmante del Cliente
    @track selectedClientSigner = '';
    @track signatureSource = 'creator';

    // Datos del Contrato
    @track isManualContract = false;
    @track fechaPrimerServicio = '';
    @track fechaLimiteServicio = '';
    @track fechaInicioContrato = '';
    @track fechaFinContrato = '';
    @track observacionesPrivadas = '';
    @track observacionesRenovacion = '';

    // Plantillas
    @track plantillaSeleccionada = '';
    @track contenidoLegal = '';
    @track introduccionPresupuesto = '';
    @track plantillaOptions = [];

    // Modales
    @track showEditModal = false;
    @track editingItem = {};
    @track editingIndex = -1;

    // --- GESTIÓN DE ZONAS (NUEVAS PROPIEDADES) ---
    @track historicalZones = [];
    @track showZoneModal = false;
    @track activeItemId = null;
    @track tempSelectedZones = [];
    @track newZoneName = '';
    @track newZoneType = '';

    get serviceTypeOptions() {
        return [
            { label: 'Bioenzimático', value: 'BIOENZIMÁTICO' },
            { label: 'Fumigación', value: 'PÓLIZA FUMIGACIÓN' },
            { label: 'Gestión Menstrual', value: 'GESTIÓN MENSTRUAL (ÍNTIMA)' },
            { label: 'Aromatización', value: 'AROMATIZACIÓN' },
            { label: 'Limpieza de Trampas', value: 'TRAMPAS DE GRASA' }
        ];
    }

    get activeItemName() {
        const item = this.quoteLineItems.find(i => i.Id === this.activeItemId);
        return item ? item.ProductName : '';
    }

    get selectedClientSignerDisplay() {
        if (!this.selectedClientSigner) return 'No seleccionado';
        const contact = this.contactOptions.find(c => c.value === this.selectedClientSigner);
        return contact ? contact.label : this.selectedClientSigner;
    }

    get isSignatureCreator() { return this.signatureSource === 'creator'; }
    get isSignatureManager() { return this.signatureSource === 'manager'; }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }

    connectedCallback() {
        setTimeout(() => {
            if (this.recordId) this.loadInitialData();
        }, 300);
    }

    loadInitialData() {
        this.isLoading = true;
        getContractInitialData({ oppId: this.recordId })
            .then(result => {
                this.availableQuotes = result.quotes.map(q => ({
                    ...q,
                    isSynced: q.Id === result.syncedQuoteId,
                    containerClass: q.Id === result.syncedQuoteId ? 'quote-item synced' : 'quote-item'
                }));
                this.syncedQuoteId = result.syncedQuoteId;
                
                if (result.historicalZones) {
                    this.historicalZones = result.historicalZones;
                }

                if (result.contacts) {
                    this.contactOptions = result.contacts.map(c => ({
                        label: `${c.Name} (${c.Title || 'Sin Cargo'})`,
                        value: c.Id
                    }));
                }

                if (this.syncedQuoteId) {
                    this.selectQuote(this.syncedQuoteId);
                } else if (this.availableQuotes.length > 0) {
                    this.selectQuote(this.availableQuotes[0].Id);
                } else {
                    this.isLoading = false;
                }
                
                this.fetchTemplates();
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error cargando datos de contrato:', error);
            });
    }

    selectQuote(quoteId) {
        this.isLoading = true;
        this.selectedQuoteId = quoteId;
        const quote = this.availableQuotes.find(q => q.Id === quoteId);
        this.selectedQuoteName = quote ? `${quote.QuoteNumber} - ${quote.Name}` : 'Presupuesto seleccionado';
        
        this.fetchLineItems(quoteId);
        
        if (quote && quote.Introduction_Text__c) {
            this.introduccionPresupuesto = quote.Introduction_Text__c;
        } else {
            this.introduccionPresupuesto = '';
        }

        this.isLoading = false;
    }

    handleBackToSelection() {
        this.selectedQuoteId = '';
        this.quoteLineItems = [];
    }

    fetchTemplates() {
        getEmailTemplatesByFolder({ folderName: 'Pyatz - Condiciones de Contrato' })
            .then(result => {
                if (result && result.length > 0) {
                    this.plantillaOptions = result.map(t => ({ label: t.name, value: t.id }));
                }
            })
            .catch(error => console.error('Error cargando plantillas de contrato:', error));
    }

    fetchLineItems(quoteId) {
        getQuoteLineItems({ quoteId: quoteId })
            .then(result => {
                this.quoteLineItems = result.map(item => {
                    let displayZones = item.Zonas_a_Tratar__c || '';
                    
                    if (this.historicalZones && this.historicalZones.length > 0) {
                        const relatedZones = this.historicalZones
                            .filter(z => z.Tipo_de_Servicio__c && z.Tipo_de_Servicio__c.includes(item.Product2.Name))
                            .map(z => z.Name);
                        
                        if (relatedZones.length > 0) {
                            displayZones = relatedZones.join(', ');
                        }
                    }

                    const selectedZones = displayZones ? displayZones.split(',').map(z => z.trim()).filter(z => z !== '') : [];

                    return {
                        ...item,
                        ProductCode: item.Product2 ? item.Product2.ProductCode : '---',
                        ProductName: item.Product2 ? item.Product2.Name : 'Producto',
                        Sede: (item.Quote && item.Quote.Technical_Sedes__c) ? item.Quote.Technical_Sedes__c : '---',
                        Zonas_a_Tratar__c: displayZones,
                        selectedZonesPills: selectedZones.map(z => ({ label: z, name: z })),
                        isSelected: true
                    };
                });
                this.calculateTotals();
            })
            .catch(error => console.error('Error recuperando partidas:', error));
    }

    // --- GESTIÓN AVANZADA DE ZONAS (IGEO REPLICA) ---
    handleOpenZoneModal(event) {
        this.activeItemId = event.currentTarget.dataset.id;
        const item = this.quoteLineItems.find(i => i.Id === this.activeItemId);
        this.tempSelectedZones = [...item.selectedZonesPills.map(p => p.name)];
        this.showZoneModal = true;
    }

    handleCloseZoneModal() {
        this.showZoneModal = false;
        this.newZoneName = '';
        this.newZoneType = '';
    }

    handleToggleZoneSelection(event) {
        const zoneName = event.target.dataset.name;
        const isChecked = event.target.checked;

        if (isChecked && !this.tempSelectedZones.includes(zoneName)) {
            this.tempSelectedZones.push(zoneName);
        } else if (!isChecked) {
            this.tempSelectedZones = this.tempSelectedZones.filter(z => z !== zoneName);
        }
    }

    handleNewZoneInputChange(event) {
        const field = event.target.dataset.field;
        if (field === 'name') this.newZoneName = event.target.value;
        else if (field === 'type') this.newZoneType = event.target.value;
    }

    handleAddNewZone() {
        if (!this.newZoneName) return;
        
        const zoneNameWithPrefix = `CDT ${this.newZoneName}`;
        
        if (!this.tempSelectedZones.includes(zoneNameWithPrefix)) {
            this.tempSelectedZones.push(zoneNameWithPrefix);
        }

        if (!this.historicalZones.some(z => z.Name === zoneNameWithPrefix)) {
            this.historicalZones = [...this.historicalZones, {
                Name: zoneNameWithPrefix,
                Tipo_de_Servicio__c: this.newZoneType || 'GENERAL'
            }];
        }

        this.newZoneName = '';
        this.newZoneType = '';
    }

    handleApplyZones() {
        this.quoteLineItems = this.quoteLineItems.map(item => {
            if (item.Id === this.activeItemId) {
                return {
                    ...item,
                    selectedZonesPills: this.tempSelectedZones.map(z => ({ label: z, name: z })),
                    Zonas_a_Tratar__c: this.tempSelectedZones.join(', ')
                };
            }
            return item;
        });
        this.handleCloseZoneModal();
    }

    handleRemoveZonePill(event) {
        const itemId = event.currentTarget.dataset.itemId;
        const zoneName = event.detail.name;
        
        this.quoteLineItems = this.quoteLineItems.map(item => {
            if (item.Id === itemId) {
                const zones = item.selectedZonesPills.map(p => p.name).filter(z => z !== zoneName);
                return {
                    ...item,
                    selectedZonesPills: zones.map(z => ({ label: z, name: z })),
                    Zonas_a_Tratar__c: zones.join(', ')
                };
            }
            return item;
        });
    }

    get historicalZonesCategorized() {
        if (!this.historicalZones) return [];
        const groups = {};
        this.historicalZones.forEach(z => {
            const type = z.Tipo_de_Servicio__c || 'Otras Zonas';
            if (!groups[type]) groups[type] = [];
            groups[type].push({
                name: z.Name,
                isSelected: this.tempSelectedZones.includes(z.Name)
            });
        });
        return Object.keys(groups).map(type => ({ label: type, zones: groups[type] }));
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

    handleSignatureToggle(event) {
        this.signatureSource = event.target.dataset.id;
    }

    handleManualContractToggle(event) {
        this.isManualContract = event.target.checked;
    }

    handleDateChange(event) {
        const id = event.target.dataset.id;
        const val = event.target.value;
        if (id === 'primerServicio') {
            this.fechaPrimerServicio = val;
            if (!this.fechaInicioContrato && val) {
                this.fechaInicioContrato = val;
                this.autoCalculateEndDate(val);
            }
        } else {
            this.fechaLimiteServicio = val;
        }
    }

    handleVigenciaChange(event) {
        const id = event.target.dataset.id;
        const val = event.target.value;
        if (id === 'inicio') {
            this.fechaInicioContrato = val;
            this.autoCalculateEndDate(val);
        } else {
            this.fechaFinContrato = val;
        }
    }

    autoCalculateEndDate(startDateStr) {
        if (!startDateStr) return;
        try {
            const parts = startDateStr.split('-');
            const d = new Date(parts[0], parts[1] - 1, parts[2]);
            d.setFullYear(d.getFullYear() + 1);
            d.setDate(d.getDate() - 1);
            const year = d.getFullYear();
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            this.fechaFinContrato = `${year}-${month}-${day}`;
        } catch (e) {
            console.error('Error calculando fecha fin:', e);
        }
    }

    handleObsChange(event) {
        const id = event.target.dataset.id;
        if (id === 'privadas') this.observacionesPrivadas = event.target.value;
        else this.observacionesRenovacion = event.target.value;
    }

    handlePlantillaChange(event) {
        this.plantillaSeleccionada = event.detail.value;
        if (this.plantillaSeleccionada) {
            renderTemplate({ templateId: this.plantillaSeleccionada, quoteId: this.selectedQuoteId })
                .then(result => {
                    this.contenidoLegal = result;
                })
                .catch(error => {
                    console.error('Error renderizando plantilla:', error);
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo cargar la plantilla.', variant: 'error' }));
                });
        }
    }

    handleContenidoChange(event) { this.contenidoLegal = event.target.value; }
    handleIntroChange(event) { this.introduccionPresupuesto = event.target.value; }

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
                total += (item.TotalPrice || 0) * 1.16;
            }
        });
        this.totals = { total };
    }

    handleToggle(event) {
        this.selections[event.target.dataset.id] = event.target.checked;
    }

    handleSaveDraft() {
        if (!this.selectedQuoteId) return Promise.reject('No quote selected');

        const data = {
            fechaInicioContrato: this.fechaInicioContrato,
            fechaVencimiento: this.fechaFinContrato,
            fechaPrimerServicio: this.fechaPrimerServicio,
            fechaLimiteServicio: this.fechaLimiteServicio,
            introduccion: this.introduccionPresupuesto,
            observaciones: this.observacionesRenovacion, 
            observacionesPrivadas: this.observacionesPrivadas,
            contenidoLegal: this.contenidoLegal,
            status: 'In Review',
            creatorId: this.selectedCreator.id,
            managerId: this.selectedManager.id,
            clientSignerId: this.selectedClientSigner,
            lineItemsJson: JSON.stringify(this.quoteLineItems)
        };

        this.isLoading = true;
        return saveContractData({ quoteId: this.selectedQuoteId, contractData: data })
            .then(scId => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({ 
                    title: 'Éxito', 
                    message: 'Contrato de Servicio generado y guardado en Salesforce.', 
                    variant: 'success' 
                }));
                this.dispatchEvent(new CustomEvent('contractgenerated', { detail: scId }));
                return scId;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error guardando contrato:', error);
                this.dispatchEvent(new ShowToastEvent({ 
                    title: 'Error', 
                    message: error.body ? error.body.message : error, 
                    variant: 'error' 
                }));
                throw error;
            });
    }

    handleGenerateContract() {
        if (!this.selectedCreator.id) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'El campo "Creado por" es obligatorio.', variant: 'error' }));
            return;
        }

        this.handleSaveDraft()
            .then(scId => {
                const selectedIds = this.quoteLineItems.filter(item => item.isSelected).map(item => item.Id);
                let url = `/apex/QuoteContractPDF?id=${this.selectedQuoteId}&selectedItems=${selectedIds.join(',')}`;
                url += `&show_total=${this.selections.show_total}&show_line_prices=${this.selections.show_line_prices}`;
                url += `&createdBy=${this.selectedCreator.id}&managedBy=${this.selectedManager.id}&sigSource=${this.signatureSource}`;
                url += `&clientSigner=${encodeURIComponent(this.selectedClientSigner)}`;

                window.open(url, '_blank');
                this.dispatchEvent(new CustomEvent('contractfinalized', { detail: scId }));
            })
            .catch(error => {
                console.error('Error al finalizar contrato:', error);
            });
    }

    handleGoToQuotes() {
        this.dispatchEvent(new CustomEvent('navquotes'));
    }

    handleGoToWorkOrders() {
        this.dispatchEvent(new CustomEvent('workorders', { detail: this.recordId }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleReset() {
        this.loadInitialData();
        this.selectedQuoteId = '';
    }
}