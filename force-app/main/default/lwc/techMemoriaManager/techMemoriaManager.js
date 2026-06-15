import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLevantamientoDetails from '@salesforce/apex/SurveyController.getLevantamientoDetails';
import getSolucionesOpp from '@salesforce/apex/SurveyController.getSolucionesOpp';
import saveSolucionOpp from '@salesforce/apex/SurveyController.saveSolucionOpp';
import deleteSolucion from '@salesforce/apex/SurveyController.deleteSolucion';
import getEnlacesForSolucion from '@salesforce/apex/SurveyController.getEnlacesForSolucion';
import saveEnlaces from '@salesforce/apex/SurveyController.saveEnlaces';
import getTableConfigs from '@salesforce/apex/AdminController.getTableConfigs';

export default class TechMemoriaManager extends LightningElement {
    @api recordId;
    @track memoriaText = '';
    @track groupedDetails = [];
    @track solutions = [];
    @track tableConfigs = [];
    
    @track selectedSolucionId = null;
    @track selectedSolucionName = '';
    @track activeEnlaces = []; // Array of Levantamiento Ids
    
    @track isSaving = false;
    @track showSolModal = false;
    @track newSolName = '';
    @track isFullScreen = false;

    connectedCallback() {
        this.loadInitialData();
    }

    async loadInitialData() {
        try {
            this.tableConfigs = await getTableConfigs();
            await this.loadSoluciones();
            await this.loadDetails();
        } catch (error) {
            console.error('Error loading initial data:', error);
        }
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

    get hallazgosPointerEvents() {
        return this.selectedSolucionId ? 'auto' : 'none';
    }

    get isHallazgosDisabled() {
        return !this.selectedSolucionId || this.isSaving;
    }

    loadSoluciones() {
        return getSolucionesOpp({ recordId: this.recordId })
            .then(result => {
                this.solutions = result.map(s => ({
                    ...s,
                    className: s.Id === this.selectedSolucionId ? 'sol-item active-sol' : 'sol-item'
                }));
            });
    }

    loadDetails() {
        return getLevantamientoDetails({ recordId: this.recordId })
            .then(result => this.formatGroupedDetails(result))
            .catch(error => console.error('Error details:', error));
    }

    formatGroupedDetails(records) {
        const groups = {};
        records.forEach(rec => {
            const type = rec.Tipo_Servicio__c || 'GENERAL';
            const typeUpper = type.toUpperCase();
            if (!groups[type]) groups[type] = { label: type, records: [] };
            
            const identifier = [rec.Nivel__c, rec.Area_Cocina_Banos__c, rec.Zona_Genero__c]
                .filter(item => item)
                .join(' - ');
            
            const displayName = identifier ? identifier : rec.Name;

            let detailItems = [];
            if (rec.Nivel__c) detailItems.push({ label: 'Nivel', value: rec.Nivel__c });
            if (rec.Area_Cocina_Banos__c) detailItems.push({ label: 'Área', value: rec.Area_Cocina_Banos__c });
            if (rec.Zona_Genero__c) detailItems.push({ label: 'Zona', value: rec.Zona_Genero__c });
            
            let specs = [];
            
            const config = this.tableConfigs.find(c => c.value === typeUpper);
            if (config && config.fields && config.fields.length > 0) {
                config.fields.forEach((field, index) => {
                    const label = config.labels[index] || field;
                    const value = rec[field];
                    if ((value !== undefined && value !== null && value !== '') && !['Nivel__c', 'Area_Cocina_Banos__c', 'Zona_Genero__c'].includes(field)) {
                        specs.push(`${label}: ${value}`);
                    }
                });
            } 
            
            if (specs.length === 0) {
                if (typeUpper === 'BIOENZIMÁTICO') {
                    if (rec.VE__c) specs.push(`VE: ${rec.VE__c}`);
                    if (rec.VP__c) specs.push(`VP: ${rec.VP__c}`);
                    if (rec.Bidon_10L__c) specs.push(`10L: ${rec.Bidon_10L__c}`);
                    if (rec.Bidon_20L__c) specs.push(`20L: ${rec.Bidon_20L__c}`);
                    if (rec.Bidon_25L__c) specs.push(`25L: ${rec.Bidon_25L__c}`);
                    if (rec.Piso__c || rec.Mueble__c || rec.Pared__c) specs.push(`Ubic: P:${rec.Piso__c||0}/M:${rec.Mueble__c||0}/W:${rec.Pared__c||0}`);
                    if (rec.Escamoche__c) specs.push(`Escamoche: ${rec.Escamoche__c}`);
                    if (rec.Azolves__c) specs.push(`Azolves: ${rec.Azolves__c}`);
                    if (rec.Residuos_Tarja__c) specs.push(`Residuos: ${rec.Residuos_Tarja__c}`);
                    if (rec.Coladeras__c || rec.Coladeras__c === 0) specs.push(`Coladeras: ${rec.Coladeras__c}`);
                    if (rec.Tapon_Registro__c || rec.Tapon_Registro__c === 0) specs.push(`Tapón Reg: ${rec.Tapon_Registro__c}`);
                    if (rec.Tarja__c || rec.Tarja__c === 0) specs.push(`Tarjas: ${rec.Tarja__c}`);
                    if (rec.Tinas_por_Tarja__c || rec.Tinas_por_Tarja__c === 0) specs.push(`Tinas x Tarja: ${rec.Tinas_por_Tarja__c}`);
                    if (rec.Trampa_Grasa__c || rec.Trampa_Grasa__c === 0) specs.push(`Trampa Grasa: ${rec.Trampa_Grasa__c}`);
                    if (rec.Modelo_TG_Bio__c) specs.push(`Mod TG: ${rec.Modelo_TG_Bio__c}`);
                    if (rec.ST_1__c || rec.ST_1__c === 0) specs.push(`ST-1: ${rec.ST_1__c}`);
                    if (rec.Ovalines_Lavabo__c || rec.Ovalines_Lavabo__c === 0) specs.push(`Ovalines: ${rec.Ovalines_Lavabo__c}`);
                } else if (typeUpper === 'GRASAS') {
                    if (rec.Modelo_Grasas__c) specs.push(`Mod: ${rec.Modelo_Grasas__c}`);
                    if (rec.Frecuencia_Limpieza__c) specs.push(`Frec: ${rec.Frecuencia_Limpieza__c}`);
                    if (rec.Estado_Trampa__c) specs.push(`Estado: ${rec.Estado_Trampa__c}`);
                    if (rec.SP__c || rec.ENT__c) specs.push(`SP:${rec.SP__c||0} / ENT:${rec.ENT__c||0}`);
                    if (rec.Tornillo__c || rec.Sello__c || rec.Mampara__c || rec.Canastilla__c || rec.Ret_Salida__c) {
                        specs.push(`Tor:${rec.Tornillo__c||0}/Sel:${rec.Sello__c||0}/Mam:${rec.Mampara__c||0}/Can:${rec.Canastilla__c||0}/Ret:${rec.Ret_Salida__c||0}`);
                    }
                } else if (typeUpper === 'VACTOR') {
                    if (rec.Vactor_Descripcion__c) specs.push(`Desc: ${rec.Vactor_Descripcion__c}`);
                    if (rec.Vactor_Medida__c) specs.push(`Medida: ${rec.Vactor_Medida__c}`);
                    if (rec.Vactor_Material__c) specs.push(`Material: ${rec.Vactor_Material__c}`);
                    if (rec.Vactor_Servicio_Requerido__c) specs.push(`Servicio: ${rec.Vactor_Servicio_Requerido__c}`);
                    if (rec.Vactor_Largo__c || rec.Vactor_Largo__c === 0) specs.push(`L:${rec.Vactor_Largo__c}m`);
                    if (rec.Vactor_Ancho__c || rec.Vactor_Ancho__c === 0) specs.push(`A:${rec.Vactor_Ancho__c}m`);
                    if (rec.Vactor_Profundidad__c || rec.Vactor_Profundidad__c === 0) specs.push(`P:${rec.Vactor_Profundidad__c}m`);
                    if (rec.Metros_Lineales__c || rec.Metros_Lineales__c === 0) specs.push(`Total: ${rec.Metros_Lineales__c}m lineales`);
                    if (rec.Vactor_Distancia_Camion__c) specs.push(`Distancia: ${rec.Vactor_Distancia_Camion__c}`);
                    if (rec.Vactor_Permiso_Delegacion__c) specs.push(`Permiso Del: ${rec.Vactor_Permiso_Delegacion__c}`);
                    if (rec.Vactor_Permiso_Plaza__c) specs.push(`Permiso Plaza: ${rec.Vactor_Permiso_Plaza__c}`);
                    if (rec.Vactor_Dificultad__c) specs.push(`Dificultad: ${rec.Vactor_Dificultad__c}`);
                    if (rec.Vactor_Alcance_Pyatz__c) specs.push(`Alcance: ${rec.Vactor_Alcance_Pyatz__c}`);
                } else if (typeUpper === 'INTIMA') {
                    if (rec.WC__c || rec.WC__c === 0) specs.push(`WC: ${rec.WC__c}`);
                    if (rec.Frecuencia__c) specs.push(`Freq: ${rec.Frecuencia__c}`);
                    if (rec.Dias_Servicio_Censo__c) specs.push(`Días: ${rec.Dias_Servicio_Censo__c}`);
                } else if (typeUpper === 'DESAZOLVE MECANICO') {
                    if (rec.Metros_Lineales__c || rec.Metros_Lineales__c === 0) specs.push(`Mts: ${rec.Metros_Lineales__c}`);
                    if (rec.Tarjas_Servicios__c || rec.Tarjas_Servicios__c === 0) specs.push(`Tarjas: ${rec.Tarjas_Servicios__c}`);
                    if (rec.Cuarto_Humado__c || rec.Cuarto_Humado__c === 0) specs.push(`Cuarto Húmedo: ${rec.Cuarto_Humado__c}`);
                    if (rec.Equipos_ARM__c || rec.Equipos_ARM__c === 0) specs.push(`ARM: ${rec.Equipos_ARM__c}`);
                    if (rec.Coladeras__c || rec.Coladeras__c === 0) specs.push(`Coladeras: ${rec.Coladeras__c}`);
                    if (rec.Tapon_Registro__c || rec.Tapon_Registro__c === 0) specs.push(`Tapón Reg: ${rec.Tapon_Registro__c}`);
                    if (rec.WC__c || rec.Ovalines_Lavabo__c || rec.Mingitorios__c) specs.push(`Puntos: WC:${rec.WC__c||0}/Ov:${rec.Ovalines_Lavabo__c||0}/Min:${rec.Mingitorios__c||0}`);
                } else if (typeUpper === 'AROMATIZANTES') {
                    if (rec.WC__c || rec.WC__c === 0) specs.push(`WC: ${rec.WC__c}`);
                    if (rec.Equipos_ARM__c || rec.Equipos_ARM__c === 0) specs.push(`ARM: ${rec.Equipos_ARM__c}`);
                }
            }

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
                metrics: specs,
                estado: rec.Estado_Instalacion__c,
                estadoClass: estadoClass,
                observaciones: rec.Observaciones_Tecnicas__c,
                selected: this.activeEnlaces.includes(rec.Id)
            });
        });
        this.groupedDetails = Object.values(groups);
    }

    async handleSolSelect(event) {
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

        // Fetch enlaces
        try {
            this.activeEnlaces = await getEnlacesForSolucion({ solucionId: solId });
            this.updateCheckboxes();
        } catch(e) {
            console.error('Error fetching enlaces', e);
        }
    }

    updateCheckboxes() {
        let updatedGroups = [];
        this.groupedDetails.forEach(g => {
            let updatedRecords = g.records.map(r => {
                return { ...r, selected: this.activeEnlaces.includes(r.id) };
            });
            updatedGroups.push({ ...g, records: updatedRecords });
        });
        this.groupedDetails = updatedGroups;
    }

    async handleCheckboxChange(event) {
        const recId = event.target.dataset.id;
        const isChecked = event.target.checked;
        
        if (isChecked && !this.activeEnlaces.includes(recId)) {
            this.activeEnlaces.push(recId);
        } else if (!isChecked && this.activeEnlaces.includes(recId)) {
            this.activeEnlaces = this.activeEnlaces.filter(id => id !== recId);
        }
        
        // Auto-save enlaces
        this.isSaving = true;
        try {
            await saveEnlaces({ solucionId: this.selectedSolucionId, hallazgosIds: this.activeEnlaces });
        } catch(e) {
            console.error('Error saving enlaces', e);
        } finally {
            this.isSaving = false;
            this.updateCheckboxes();
        }
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
        saveSolucionOpp({ 
            recordId: this.recordId, 
            solucionId: null, 
            nombre: this.newSolName, 
            descripcion: '' 
        })
        .then((newId) => {
            this.selectedSolucionId = newId;
            this.selectedSolucionName = this.newSolName;
            this.memoriaText = '';
            this.activeEnlaces = [];
            this.showSolModal = false;
            return this.loadSoluciones();
        })
        .then(() => {
            this.updateCheckboxes();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Nueva solución creada.',
                variant: 'success'
            }));
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error,
                variant: 'error'
            }));
        })
        .finally(() => this.isSaving = false);
    }

    handleSaveDescription() {
        if (!this.selectedSolucionId) return;
        this.isSaving = true;
        saveSolucionOpp({
            recordId: this.recordId,
            solucionId: this.selectedSolucionId,
            nombre: this.selectedSolucionName,
            descripcion: this.memoriaText
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Memoria guardada', variant: 'success' }));
            return this.loadSoluciones();
        })
        .finally(() => this.isSaving = false);
    }

    handleDeleteSol(event) {
        const id = event.target.dataset.id;
        deleteSolucion({ solucionId: id }).then(() => {
            if(this.selectedSolucionId === id) {
                this.selectedSolucionId = null;
                this.memoriaText = '';
                this.activeEnlaces = [];
                this.updateCheckboxes();
            }
            this.loadSoluciones();
        });
    }

    get editorTitle() { 
        return this.selectedSolucionId ? `Redacción: ${this.selectedSolucionName}` : 'Editor de Memoria Técnica'; 
    }
}