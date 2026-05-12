import { LightningElement, api, track, wire } from 'lwc';
import getAccountZonesData from '@salesforce/apex/TechWorkOrderController.getAccountZonesData';

const COLUMNS = [
    { label: 'Zona', fieldName: 'Name', type: 'text', sortable: true, cellAttributes: { class: 'slds-text-title_bold' } },
    { label: 'Tipo', fieldName: 'TemplateName', type: 'text', sortable: true, cellAttributes: { class: 'slds-text-color_success slds-text-title_bold' } },
    { label: 'Línea de Negocio', fieldName: 'DisplayLOB', type: 'text', cellAttributes: { class: { fieldName: 'lobStatusClass' } } }
];

export default class TechZoneBrowserDrawer extends LightningElement {
    @api accountId;
    @api currentBusinessLines = ''; 
    @api plannedTreatments = []; // Recibe sedesList[0].tratamientos
    
    @track isOpen = false;
    @track isLoading = false;
    @track zones = [];
    @track searchTerm = '';
    @track selectedZones = []; 
    @track targetTraId = ''; 
    @track initialNamesToMatch = []; 
    @track selectedTreatmentIds = new Set(); 
    
    @track filterZona = '';
    @track filterTipo = '';
    @track filterLob = '';
    @track filterCodigo = '';

    @track onlyContextZones = false;

    @track currentPage = 1;
    recordsPerPage = 10;
    
    columns = COLUMNS;
    searchDelay;

    @api
    open(traId, currentZonesText) {
        this.isOpen = true;
        this.targetTraId = traId || '';
        this.selectedZones = []; 
        this.selectedTreatmentIds = new Set([this.targetTraId]); 

        if (currentZonesText && currentZonesText !== 'Sin descripción técnica') {
            this.initialNamesToMatch = currentZonesText.split(',').map(n => n.trim());
        } else {
            this.initialNamesToMatch = [];
        }

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

            if (this.initialNamesToMatch.length > 0) {
                const matchingZones = this.zones.filter(z => this.initialNamesToMatch.includes(z.Name));
                if (matchingZones.length > 0) {
                    this.selectedZones = [...matchingZones];
                }
                this.initialNamesToMatch = []; 
            }

            this.currentPage = 1;
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error cargando zonas:', error);
            this.isLoading = false;
        });
    }

    handleRowSelection(event) {
        this.selectedZones = event.detail.selectedRows;
    }

    handleConfirmSelection() {
        if (this.selectedZones.length > 0) {
            const selectedEvent = new CustomEvent('zoneselected', {
                detail: {
                    traIds: Array.from(this.selectedTreatmentIds),
                    zones: this.selectedZones
                }
            });
            this.dispatchEvent(selectedEvent);
            this.closeDrawer();
        }
    }

    handleTreatmentToggle(event) {
        const traId = event.target.dataset.id;
        const checked = event.target.checked;
        this.updateTreatmentSelection(traId, checked);
    }

    handleTreatmentClick(event) {
        const traId = event.currentTarget.dataset.id;
        // Solo alternar si no es el checkbox el que disparó el evento (para evitar doble disparo)
        if (event.target.tagName !== 'LIGHTNING-INPUT') {
            const isSelected = this.selectedTreatmentIds.has(traId);
            this.updateTreatmentSelection(traId, !isSelected);
        }
    }

    updateTreatmentSelection(traId, isSelected) {
        const newSet = new Set(this.selectedTreatmentIds);
        if (isSelected) newSet.add(traId);
        else {
            // Evitar deseleccionar el origen por error si el usuario quiere que esté ahí
            newSet.delete(traId);
        }
        this.selectedTreatmentIds = newSet;
    }

    handleToggleAllTreatments(event) {
        const checked = event.target.checked;
        if (checked) {
            this.selectedTreatmentIds = new Set(this.treatmentList.map(t => t.id));
        } else {
            this.selectedTreatmentIds = new Set([this.targetTraId]);
        }
    }

    get isAllTreatmentsSelected() {
        return this.selectedTreatmentIds.size === this.treatmentList.length;
    }

    get selectedTreatmentsCount() {
        return this.selectedTreatmentIds.size;
    }

    get isSelectionEmpty() {
        return this.selectedZones.length === 0;
    }

    get selectedRowsIds() {
        return this.selectedZones.map(z => z.Id);
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

    get treatmentList() {
        if (!this.plannedTreatments || !Array.isArray(this.plannedTreatments)) return [];
        return this.plannedTreatments.map(t => {
            const hasPoints = t.zonas && t.zonas !== 'Sin descripción técnica' && t.zonas.length > 0;
            const firstDate = (t.schedulingRows && t.schedulingRows[0]) ? t.schedulingRows[0].date : 'N/A';
            const firstTime = (t.schedulingRows && t.schedulingRows[0] && t.schedulingRows[0].startTime) ? t.schedulingRows[0].startTime.substring(0, 5) : '--:--';
            const dateTime = firstDate !== 'N/A' ? `${firstDate} ${firstTime}` : 'N/A';
            
            const isSelected = this.selectedTreatmentIds.has(t.id);
            const isMain = t.id === this.targetTraId;

            return {
                id: t.id,
                name: (t.name || '').toUpperCase(),
                code: t.code || 'N/A',
                fecha: dateTime,
                hasPoints: hasPoints ? 'SÍ' : 'NO',
                statusClass: hasPoints ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_error',
                rowClass: isSelected ? 'table-row-selected' : '',
                selected: isSelected,
                isMain: isMain
            };
        });
    }

    get hasTreatments() { return this.treatmentList.length > 0; }
}
