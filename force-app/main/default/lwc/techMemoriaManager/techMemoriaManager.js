import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLevantamientoDetails from '@salesforce/apex/SurveyController.getLevantamientoDetails';
import getSoluciones from '@salesforce/apex/SurveyController.getSoluciones';
import saveSolucion from '@salesforce/apex/SurveyController.saveSolucion';
import deleteSolucion from '@salesforce/apex/SurveyController.deleteSolucion';

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
    @track isFullScreen = false;

    connectedCallback() {
        this.loadDetails();
    }

    toggleFullScreen() {
        this.isFullScreen = !this.isFullScreen;
    }

    get editorContainerClass() {
        return this.isFullScreen ? 'editor-card full-screen-active' : 'editor-card';
    }

    get fullScreenIcon() {
        return this.isFullScreen ? 'utility:contract' : 'utility:expand';
    }

    get hideSidebarsClass() {
        return this.isFullScreen ? 'slds-hide' : '';
    }

    get editorColumnSize() {
        return this.isFullScreen ? '12' : '6';
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
            
            // Construir Nombre Descriptivo Único
            const identifier = [rec.Nivel__c, rec.Area_Cocina_Banos__c, rec.Zona_Genero__c]
                .filter(item => item)
                .join(' - ');
            
            const displayName = identifier ? identifier : rec.Name;

            let detailItems = [];
            if (rec.Nivel__c) detailItems.push({ label: 'Nivel', value: rec.Nivel__c });
            if (rec.Area_Cocina_Banos__c) detailItems.push({ label: 'Área', value: rec.Area_Cocina_Banos__c });
            if (rec.Zona_Genero__c) detailItems.push({ label: 'Zona', value: rec.Zona_Genero__c });
            
            // --- DETALLE TÉCNICO PROFUNDO (ESPECIFICACIONES) ---
            let specs = [];
            const typeUpper = type.toUpperCase();

            if (typeUpper === 'BIOENZIMÁTICO') {
                if (rec.VE__c) specs.push(`VE: ${rec.VE__c}`);
                if (rec.VP__c) specs.push(`VP: ${rec.VP__c}`);
                if (rec.Bidon_10L__c) specs.push(`10L: ${rec.Bidon_10L__c}`);
                if (rec.Bidon_20L__c) specs.push(`20L: ${rec.Bidon_20L__c}`);
                if (rec.Bidon_25L__c) specs.push(`25L: ${rec.Bidon_25L__c}`);
                if (rec.Piso__c || rec.Mueble__c || rec.Pared__c) specs.push(`Ubic: P:${rec.Piso__c}/M:${rec.Mueble__c}/W:${rec.Pared__c}`);
                if (rec.Escamoche__c) specs.push(`Escamoche: ${rec.Escamoche__c}`);
            } else if (typeUpper === 'GRASAS') {
                if (rec.Modelo_Grasas__c) specs.push(`Mod: ${rec.Modelo_Grasas__c}`);
                if (rec.Estado_Trampa__c) specs.push(`Estado: ${rec.Estado_Trampa__c}`);
                if (rec.SP__c || rec.ENT__c) specs.push(`SP:${rec.SP__c} / ENT:${rec.ENT__c}`);
            } else if (typeUpper === 'VACTOR') {
                if (rec.Vactor_Largo__c) specs.push(`L:${rec.Vactor_Largo__c}m`);
                if (rec.Vactor_Ancho__c) specs.push(`A:${rec.Vactor_Ancho__c}m`);
                if (rec.Vactor_Profundidad__c) specs.push(`P:${rec.Vactor_Profundidad__c}m`);
                if (rec.Metros_Lineales__c) specs.push(`Total: ${rec.Metros_Lineales__c}m lineales`);
                if (rec.Vactor_Dificultad__c) specs.push(`Dificultad: ${rec.Vactor_Dificultad__c}`);
            } else if (typeUpper === 'INTIMA') {
                if (rec.WC__c) specs.push(`WC: ${rec.WC__c}`);
                if (rec.Frecuencia__c) specs.push(`Freq: ${rec.Frecuencia__c}`);
            } else if (typeUpper === 'DESAZOLVE MECANICO') {
                if (rec.Metros_Lineales__c) specs.push(`Mts: ${rec.Metros_Lineales__c}`);
                if (rec.WC__c || rec.Ovalines_Lavabo__c || rec.Mingitorios__c) specs.push(`Puntos: WC:${rec.WC__c}/Ov:${rec.Ovalines_Lavabo__c}/Min:${rec.Mingitorios__c}`);
            }

            // Estado Class
            let estadoClass = 'status-badge';
            if (rec.Estado_Instalacion__c) {
                const est = rec.Estado_Instalacion__c.toUpperCase();
                if (est.includes('MAL') || est.includes('PÉSIMO')) estadoClass += ' status-red';
                else if (est.includes('BIEN') || est.includes('CORRECTO')) estadoClass += ' status-green';
            }

            groups[type].records.push({
                id: rec.Id,
                name: displayName,
                fields: detailItems,
                metrics: specs, // Cambiado de join a array
                estado: rec.Estado_Instalacion__c,
                estadoClass: estadoClass,
                observaciones: rec.Observaciones_Tecnicas__c,
                hasSolutions: rec.Soluciones_Tecnicas__r && rec.Soluciones_Tecnicas__r.length > 0,
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
        .then((newId) => {
            this.selectedSolucionId = newId;
            this.selectedSolucionName = this.newSolName;
            this.memoriaText = '';
            this.showSolModal = false;
            this.loadSoluciones();
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Nueva solución creada y seleccionada.',
                variant: 'success'
            }));
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body.message,
                variant: 'error'
            }));
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