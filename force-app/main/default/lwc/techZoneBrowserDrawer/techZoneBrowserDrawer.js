import { LightningElement, api, track, wire } from 'lwc';
import getAccountZonesData from '@salesforce/apex/TechWorkOrderController.getAccountZonesData';

const COLUMNS = [
    { label: 'Zona', fieldName: 'Name', type: 'text', sortable: true, cellAttributes: { class: 'slds-text-title_bold' } },
    { label: 'Tipo (Protocolo)', fieldName: 'TemplateName', type: 'text', sortable: true, cellAttributes: { class: 'slds-text-color_success slds-text-title_bold' } },
    { label: 'Línea de Negocio (Actual)', fieldName: 'DisplayLOB', type: 'text', cellAttributes: { class: { fieldName: 'lobStatusClass' } } },
    { label: 'Código Único', fieldName: 'Id_Unico_Zona__c', type: 'text', cellAttributes: { class: 'mono-text' } },
    { label: 'ID de Sistema', fieldName: 'Id', type: 'text', cellAttributes: { class: 'slds-text-color_weak slds-text-body_small' } }
];

export default class TechZoneBrowserDrawer extends LightningElement {
    @api accountId;
    @api currentBusinessLines = ''; 
    @api plannedTreatments = ''; // Recibe la lista de tratamientos (ej: "BIOENZIMÁTICO, FUMIGACIÓN")
    
    @track isOpen = false;
    @track isLoading = false;
    @track zones = [];
    @track searchTerm = '';
    @track selectedZone = null;
    
    // Filtros por columna
    @track filterZona = '';
    @track filterTipo = '';
    @track filterLob = '';
    @track filterCodigo = '';

    // Filtro de Contexto (iGeo Intelligence)
    @track onlyContextZones = false;

    // Paginación
    @track currentPage = 1;
    recordsPerPage = 10;
    
    columns = COLUMNS;
    searchDelay;

    @api
    open() {
        this.isOpen = true;
        this.resetFilters();
        this.loadZones();
    }

    @api
    closeDrawer() {
        this.isOpen = false;
    }

    resetFilters() {
        this.searchTerm = '';
        this.filterZona = '';
        this.filterTipo = '';
        this.filterLob = '';
        this.filterCodigo = '';
        this.onlyContextZones = false;
        this.currentPage = 1;
        this.selectedZone = null;
    }

    handleToggleContextFilter(event) {
        this.onlyContextZones = event.target.checked;
        this.loadZones();
    }

    get drawerClass() {
        return this.isOpen 
            ? 'slds-panel slds-size_large slds-panel_docked slds-panel_docked-right slds-is-open drawer-premium' 
            : 'slds-panel slds-size_large slds-panel_docked slds-panel_docked-right drawer-premium';
    }

    loadZones() {
        if (!this.accountId) return;
        
        this.isLoading = true;
        getAccountZonesData({ 
            accountId: this.accountId, 
            searchTerm: this.searchTerm,
            nameFilter: this.filterZona,
            templateFilter: this.filterTipo,
            lobFilter: this.filterLob,
            codeFilter: this.filterCodigo
        })
        .then(result => {
            const budgetLine = this.currentBusinessLines || 'Línea de Negocio';
            const contextLines = budgetLine.toLowerCase().split(';').map(l => l.trim());

            // MAPEO INTELIGENTE: Detección Universal de Línea y Protocolo
            let processedData = result.map(z => {
                const rawLOB = (z.Linea_de_Negocio__c || z.Tipo_de_Servicio__c || '').toLowerCase();
                const isMatch = contextLines.some(cl => rawLOB.includes(cl));

                return {
                    ...z,
                    TemplateName: (z.Plantilla_de_Formulario__r && z.Plantilla_de_Formulario__r.Name) ? z.Plantilla_de_Formulario__r.Name : '',
                    DisplayLOB: budgetLine, 
                    isContextMatch: isMatch,
                    lobStatusClass: isMatch ? 'slds-text-color_success slds-text-title_bold' : 'slds-text-color_info slds-text-body_small'
                };
            });

            if (this.onlyContextZones) {
                processedData = processedData.filter(z => z.isContextMatch);
            }

            // --- MOTOR DE RELEVANCIA 6.0 ---
            const filterTerm = (this.searchTerm || this.filterTipo || this.filterZona || '').toLowerCase();
            
            processedData = processedData.map(z => {
                let score = 0;
                const name = (z.Name || '').toLowerCase();
                const type = (z.TemplateName || '').toLowerCase();
                
                if (z.isContextMatch) score += 10000;

                if (filterTerm) {
                    if (type === filterTerm) score += 5000;
                    else if (type.startsWith(filterTerm)) score += 4000;
                    if (name === filterTerm) score += 2000;
                }
                
                return { ...z, _searchScore: score };
            }).sort((a, b) => b._searchScore - a._searchScore || (a.Name || '').localeCompare(b.Name || ''));

            this.zones = processedData;
            this.currentPage = 1;
            this.isLoading = false;
            if (this.zones.length > 0) this.selectedZone = this.zones[0];
            else this.selectedZone = null;
        })
        .catch(error => {
            console.error('Error cargando zonas:', error);
            this.isLoading = false;
        });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            this.selectedZone = selectedRows[0];
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.debounceLoad();
    }

    handleColumnFilterChange(event) {
        const field = event.target.dataset.field;
        const val = event.target.value;
        if (field === 'zona') this.filterZona = val;
        else if (field === 'tipo') this.filterTipo = val;
        else if (field === 'lob') this.filterLob = val;
        else if (field === 'codigo') this.filterCodigo = val;
        this.debounceLoad();
    }

    debounceLoad() {
        window.clearTimeout(this.searchDelay);
        this.searchDelay = setTimeout(() => {
            this.loadZones();
        }, 400);
    }

    get pagedZones() {
        const start = (this.currentPage - 1) * this.recordsPerPage;
        return this.zones.slice(start, start + this.recordsPerPage);
    }

    get totalPages() {
        return Math.ceil(this.zones.length / this.recordsPerPage) || 1;
    }

    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage >= this.totalPages; }

    handlePrevPage() {
        if (this.currentPage > 1) this.currentPage--;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) this.currentPage++;
    }

    // GETTERS PARA SECCIÓN DE ALCANCE (REEMPLAZANDO DETALLES)
    get treatmentList() {
        if (!this.plannedTreatments) return [];
        return this.plannedTreatments.split(',').map(t => {
            const name = t.trim();
            let icon = 'standard:product';
            if (name.toLowerCase().includes('bio')) icon = 'standard:article';
            if (name.toLowerCase().includes('fumi')) icon = 'standard:service_appointment';
            
            return {
                id: name,
                name: name.toUpperCase(),
                icon: icon
            };
        });
    }

    get hasTreatments() { return this.treatmentList.length > 0; }
}