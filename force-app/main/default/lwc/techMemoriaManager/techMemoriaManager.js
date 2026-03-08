import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLevantamientoDetails from '@salesforce/apex/QuoteTechnicalController.getLevantamientoDetails';
import getSoluciones from '@salesforce/apex/QuoteTechnicalController.getSoluciones';
import saveSolucion from '@salesforce/apex/QuoteTechnicalController.saveSolucion';
import deleteSolucion from '@salesforce/apex/QuoteTechnicalController.deleteSolucion';

export default class TechMemoriaManager extends LightningElement {
    @api recordId;
    @track memoriaText = '';
    @track groupedDetails = [];
    @track solutions = [];
    
    @track selectedRecordId = null;
    @track selectedRecordName = '';
    @track selectedSolucionId = null;
    @track selectedSolucionName = '';
    
    @track isSaving = false;
    @track showSolModal = false;
    @track newSolName = '';

    connectedCallback() {
        this.loadDetails();
    }

    loadDetails() {
        getLevantamientoDetails({ recordId: this.recordId })
            .then(result => this.formatGroupedDetails(result))
            .catch(error => console.error('Error details:', error));
    }

    formatGroupedDetails(records) {
        const groups = {};
        records.forEach(rec => {
            const type = rec.Tipo_Servicio__c || 'GENERAL';
            if (!groups[type]) groups[type] = { label: type, records: [] };
            
            let detailItems = [];
            if (rec.Nivel__c) detailItems.push({ label: 'Nivel', value: rec.Nivel__c });
            if (rec.Area_Cocina_Banos__c) detailItems.push({ label: 'Área', value: rec.Area_Cocina_Banos__c });
            if (rec.Estado_Instalacion__c) detailItems.push({ label: 'Estado', value: rec.Estado_Instalacion__c });

            groups[type].records.push({
                id: rec.Id,
                name: rec.Name,
                fields: detailItems,
                className: this.selectedRecordId === rec.Id ? 'record-detail-card active-card' : 'record-detail-card'
            });
        });
        this.groupedDetails = Object.values(groups);
    }

    handleRecordSelect(event) {
        const recordId = event.currentTarget.dataset.id;
        this.selectedRecordId = recordId;
        this.selectedSolucionId = null;
        this.memoriaText = '';
        
        // UI Feedback
        this.groupedDetails.forEach(g => g.records.forEach(r => {
            r.className = (r.id === recordId) ? 'record-detail-card active-card' : 'record-detail-card';
            if(r.id === recordId) this.selectedRecordName = r.name;
        }));
        this.groupedDetails = [...this.groupedDetails];
        this.loadSoluciones();
    }

    loadSoluciones() {
        getSoluciones({ levantamientoId: this.selectedRecordId })
            .then(result => {
                this.solutions = result.map(s => ({
                    ...s,
                    className: s.Id === this.selectedSolucionId ? 'sol-item active-sol' : 'sol-item'
                }));
            });
    }

    handleSolSelect(event) {
        const solId = event.currentTarget.dataset.id;
        this.selectedSolucionId = solId;
        const sol = this.solutions.find(s => s.Id === solId);
        if (sol) {
            this.memoriaText = sol.Descripcion_Detallada__c || '';
            this.selectedSolucionName = sol.Name;
        }
        this.solutions = this.solutions.map(s => ({
            ...s,
            className: s.Id === solId ? 'sol-item active-sol' : 'sol-item'
        }));
    }

    handleTextChange(event) {
        this.memoriaText = event.target.value;
    }

    handleAddSol() {
        this.newSolName = '';
        this.showSolModal = true;
    }

    handleCloseModal() {
        this.showSolModal = false;
    }

    handleNewSolNameChange(event) {
        this.newSolName = event.target.value;
    }

    handleConfirmAddSol() {
        if (!this.newSolName) return;
        this.isSaving = true;
        saveSolucion({ 
            levantamientoId: this.selectedRecordId, 
            solucionId: null, 
            nombre: this.newSolName, 
            descripcion: '' 
        })
        .then(() => {
            this.showSolModal = false;
            this.loadSoluciones();
        })
        .finally(() => this.isSaving = false);
    }

    handleSaveDescription() {
        if (!this.selectedSolucionId) return;
        this.isSaving = true;
        saveSolucion({
            levantamientoId: this.selectedRecordId,
            solucionId: this.selectedSolucionId,
            nombre: this.selectedSolucionName,
            descripcion: this.memoriaText
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Descripción guardada', variant: 'success' }));
            this.loadSoluciones();
        })
        .finally(() => this.isSaving = false);
    }

    handleDeleteSol(event) {
        const id = event.target.dataset.id;
        deleteSolucion({ solucionId: id }).then(() => this.loadSoluciones());
    }

    get isAddButtonDisabled() { 
        return !this.selectedRecordId; 
    }

    get isEditorDisabled() { 
        return !this.selectedSolucionId; 
    }

    get editorTitle() { 
        return this.selectedSolucionId ? `Redacción: ${this.selectedSolucionName}` : 'Seleccione una solución para redactar'; 
    }
}