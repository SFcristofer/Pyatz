import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import saveSurveyData from '@salesforce/apex/SurveyController.saveSurveyData';
import getLevantamientoDetails from '@salesforce/apex/SurveyController.getLevantamientoDetails';
import getAvailableFields from '@salesforce/apex/AdminController.getAvailableFields';
import getTableConfigs from '@salesforce/apex/AdminController.getTableConfigs';
import saveTableConfig from '@salesforce/apex/AdminController.saveTableConfig';
import toggleTableStatus from '@salesforce/apex/AdminController.toggleTableStatus';

export default class TechLevantamientoManager extends LightningElement {
    @api recordId;
    @track surveyType = 'BIOENZIMÁTICO'; 
    @track surveyData = [];
    @track isSaving = false;
    @track isLoading = false;

    // --- ESTADO CONFIGURACIÓN DINÁMICA ---
    @track isConfigModalOpen = false;
    @track dynamicColumns = [];
    @track availableFields = [];
    @track allTableConfigs = [];
    @track currentTableConfig = null;
    @track _rawResult = []; 
    wiredConfigsResult; // Para usar refreshApex

    // --- VARIABLES GESTIÓN MENSTRUAL ---
    @track gmUsuariasInt = 0; @track gmUsuariasExt = 0; @track gmFreqUso = '';
    @track gmSanitarios = 0; @track gmCubiculos = 0; @track gmContenedores = 0;
    @track gmFreqRecoleccion = ''; @track gmDiasServicio = ''; @track gmHorario = '';
    @track gmPermisos = ''; @track gmConsideraciones = ''; @track gmCapacitacion = '';
    @track gmPresupuesto = ''; @track gmMotivo = ''; @track gmPermiteLev = '';

    @wire(getAvailableFields)
    wiredFields({ error, data }) {
        if (data) {
            this.availableFields = [...data].sort((a, b) => a.label.localeCompare(b.label));
        }
    }

    @wire(getTableConfigs)
    wiredConfigs(result) {
        this.wiredConfigsResult = result;
        if (result.data) {
            this.allTableConfigs = result.data;
            this.updateCurrentConfig();
            if (this._rawResult && this._rawResult.length > 0) {
                this.processSurveyData(this._rawResult);
            }
        }
    }

    updateCurrentConfig() {
        const type = (this.surveyType || '').toUpperCase();
        this.currentTableConfig = this.allTableConfigs.find(c => (c.label || '').toUpperCase() === type);
        if (this.currentTableConfig) {
            this.dynamicColumns = this.currentTableConfig.fields.map((f, i) => ({
                id: i, order: i + 1, apiName: f, label: this.currentTableConfig.labels[i] || f
            }));
        } else {
            this.dynamicColumns = [];
        }
    }

    get isDynamic() {
        const classics = ['BIOENZIMÁTICO', 'GRASAS', 'INTIMA', 'DESAZOLVE MECANICO', 'AROMATIZANTES', 'VACTOR'];
        return !classics.includes((this.surveyType || '').toUpperCase()) && this.dynamicColumns.length > 0;
    }

    connectedCallback() {
        this.loadExistingData();
    }

    handleSurveyTypeChange(event) {
        this.surveyType = event.detail.value;
        this.surveyData = [];
        this.updateCurrentConfig();
        this.loadExistingData();
    }

    loadExistingData() {
        if (!this.recordId) return;
        this.isLoading = true;
        getLevantamientoDetails({ recordId: this.recordId })
            .then(result => {
                this._rawResult = result;
                this.processSurveyData(result);
            })
            .catch(error => console.error('Error loading survey:', error))
            .finally(() => this.isLoading = false);
    }

    processSurveyData(result) {
        const type = (this.surveyType || '').toUpperCase();
        const filtered = result.filter(r => (r.Tipo_Servicio__c || '').toUpperCase() === type);
        
        if (filtered && filtered.length > 0) {
            this.surveyData = filtered.map((r, idx) => {
                let row = this.createBaseRow(idx + 1);
                row.id = r.Id;
                row.nivel = r.Nivel__c || '';
                row.area = r.Area_Cocina_Banos__c || '';
                row.zona = r.Zona_Genero__c || '';
                row.obs = r.Observaciones_Tecnicas__c || '';
                
                if (this.isDynamic) {
                    row.cells = this.dynamicColumns.map(col => ({
                        field: col.apiName,
                        value: r[col.apiName] || ''
                    }));
                    this.dynamicColumns.forEach(col => { row[col.apiName] = r[col.apiName] || ''; });
                } else {
                    Object.assign(row, { 
                        ve: r.VE__c || 0, vp: r.VP__c || 0, c10l: r.Bidon_10L__c || 0, c20l: r.Bidon_20L__c || 0, c25l: r.Bidon_25L__c || 0, 
                        piso: r.Piso__c || 0, mueble: r.Mueble__c || 0, pared: r.Pared__c || 0, foto: r.Fotografia__c || '',
                        residuos: r.Residuos_Tarja__c || '', escamoche: r.Escamoche__c || '', instala: r.Estado_Instalacion__c || '', 
                        azolves: r.Azolves__c || '', coladeras: r.Coladeras__c || 0, tapon: r.Tapon_Registro__c || 0, 
                        tarja: r.Tarja__c || 0, tinas: r.Tinas_por_Tarja__c || 0, tgrasa: r.Trampa_Grasa__c || 0, 
                        modelo: r.Modelo_TG_Bio__c || '', st1: r.ST_1__c || 0, ovalines: r.Ovalines_Lavabo__c || 0,
                        sp: r.SP__c || 0, ent: r.ENT__c || 0, frecuencia: r.Frecuencia_Limpieza__c || '', estado: r.Estado_Trampa__c || '',
                        tornillo: r.Tornillo__c || 0, sello: r.Sello__c || 0, mampara: r.Mampara__c || 0, canastilla: r.Canastilla__c || 0, retSalida: r.Ret_Salida__c || 0,
                        wc: r.WC__c || 0, dias: r.Dias_Servicio_Censo__c || '', mingitorios: r.Mingitorios__c || 0, mtLineal: r.Metros_Lineales__c || 0, 
                        tarjas: r.Tarjas_Servicios__c || 0, cuartoHumado: r.Cuarto_Humado__c || 0, arm: r.Equipos_ARM__c || 0,
                        descripcion: r.Vactor_Descripcion__c || '', medida: r.Vactor_Medida__c || '', material: r.Vactor_Material__c || '', 
                        servicio: r.Vactor_Servicio_Requerido__c || '', largo: r.Vactor_Largo__c || 0, ancho: r.Vactor_Ancho__c || 0, 
                        prof: r.Vactor_Profundidad__c || 0, distancia: r.Vactor_Distancia_Camion__c || '', 
                        permDelegacion: r.Vactor_Permiso_Delegacion__c || '', permPlaza: r.Vactor_Permiso_Plaza__c || '', 
                        dificultad: r.Vactor_Dificultad__c || '', alcance: r.Vactor_Alcance_Pyatz__c || ''
                    });
                    if (type === 'INTIMA') {
                        this.gmUsuariasInt = r.GM_Usuarias_Internas__c || 0;
                        this.gmUsuariasExt = r.GM_Usuarias_Externas__c || 0;
                        this.gmFreqUso = r.GM_Frecuencia_Uso__c || '';
                        this.gmSanitarios = r.GM_Sanitarios_Totales__c || 0;
                        this.gmCubiculos = r.GM_Cubiculos_Totales__c || 0;
                        this.gmContenedores = r.GM_Contenedores_Sugeridos__c || 0;
                        this.gmFreqRecoleccion = r.GM_Frecuencia_Recoleccion__c || '';
                        this.gmDiasServicio = r.GM_Dias_Servicio__c || '';
                        this.gmHorario = r.GM_Horario_Servicio__c || '';
                        this.gmPermisos = r.GM_Permisos_Acceso__c || '';
                        this.gmConsideraciones = r.GM_Consideraciones_Especiales__c || '';
                        this.gmCapacitacion = r.GM_Requiere_Capacitacion__c || '';
                        this.gmPresupuesto = r.GM_Presupuesto_Asignado__c || '';
                        this.gmMotivo = r.GM_Motivo_Necesidad__c || '';
                        this.gmPermiteLev = r.GM_Permite_Levantamiento_Foto__c || '';
                    }
                }
                return row;
            });
        } else {
            this.handleAddSurveyRow();
        }
    }

    createBaseRow(num) {
        return { 
            id: Date.now() + Math.random(), 
            rowNumber: num, nivel: '', area: '', zona: '', obs: '', cells: [],
            ve: 0, vp: 0, c10l: 0, c20l: 0, c25l: 0, piso: 0, mueble: 0, pared: 0, 
            coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tgrasa: 0, st1: 0, ovalines: 0, 
            sp: 0, ent: 0, tornillo: 0, sello: 0, mampara: 0, canastilla: 0, retSalida: 0, 
            wc: 0, mingitorios: 0, mtLineal: 0, tarjas: 0, cuartoHumado: 0, arm: 0, largo: 0, ancho: 0, prof: 0
        };
    }

    handleAddSurveyRow() {
        let newRow = this.createBaseRow(this.surveyData.length + 1);
        if (this.isDynamic && this.dynamicColumns.length > 0) {
            newRow.cells = this.dynamicColumns.map(col => ({ field: col.apiName, value: '' }));
            this.dynamicColumns.forEach(col => { newRow[col.apiName] = ''; });
        }
        this.surveyData = [...this.surveyData, newRow];
    }

    handleRemoveSurveyRow(event) {
        const index = event.target.dataset.index;
        let data = [...this.surveyData];
        data.splice(index, 1);
        this.surveyData = data.map((row, idx) => ({ ...row, rowNumber: idx + 1 }));
    }

    handleSurveyChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.surveyData[index][field] = value;
        this.surveyData = [...this.surveyData];
    }

    handleDynamicChange(event) {
        const rowIndex = event.target.dataset.rowIndex;
        const field = event.target.dataset.field;
        const value = event.target.value;
        const row = this.surveyData[rowIndex];
        if (row.cells) {
            const cell = row.cells.find(c => c.field === field);
            if (cell) cell.value = value;
        }
        row[field] = value;
        this.surveyData = [...this.surveyData];
    }

    // --- CONFIGURACIÓN ---
    handleOpenConfig() {
        this.updateCurrentConfig();
        if (this.currentTableConfig) {
            this.dynamicColumns = this.currentTableConfig.fields.map((f, i) => ({
                id: i, order: i + 1, apiName: f, label: this.currentTableConfig.labels[i] || f
            }));
        } else {
            this.dynamicColumns = [{ id: Date.now(), order: 1, apiName: 'Nivel__c', label: 'NIVEL' }];
        }
        this.isConfigModalOpen = true;
    }

    handleCloseConfig() { this.isConfigModalOpen = false; }
    handleAddConfigColumn() { this.dynamicColumns = [...this.dynamicColumns, { id: Date.now(), order: this.dynamicColumns.length + 1, apiName: '', label: '' }]; }
    handleRemoveConfigColumn(event) { const idx = event.target.dataset.index; let cols = [...this.dynamicColumns]; cols.splice(idx, 1); this.dynamicColumns = cols.map((c, i) => ({ ...c, order: i + 1 })); }
    
    handleConfigColumnChange(event) { 
        const idx = event.target.dataset.index; 
        const val = event.detail.value; 
        this.dynamicColumns[idx].apiName = val; 
        const f = this.availableFields.find(af => af.value === val); 
        if (f) this.dynamicColumns[idx].label = f.label.toUpperCase(); 
        this.dynamicColumns = [...this.dynamicColumns]; 
    }
    
    handleConfigLabelChange(event) { 
        const idx = event.target.dataset.index; 
        this.dynamicColumns[idx].label = event.detail.value; 
        this.dynamicColumns = [...this.dynamicColumns]; 
    }
    
    handleSurveyTypeChangeInModal(event) { this.surveyType = event.detail.value; }

    async handleSaveConfig() {
        this.isLoading = true;
        try {
            const newName = this.surveyType;
            const apiNames = this.dynamicColumns.map(c => c.apiName).join(',');
            const labels = this.dynamicColumns.map(c => c.label).join(',');
            await saveTableConfig({ label: newName, apiNames: apiNames, columnLabels: labels });
            
            // Refrescar la caché de configuraciones
            await refreshApex(this.wiredConfigsResult);
            
            // Forzar la selección de la nueva tabla
            this.surveyType = newName.toUpperCase();
            this.updateCurrentConfig();
            this.loadExistingData(); // Carga las filas (o inicializa una vacía)
            
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Diseño publicado y seleccionado.', variant: 'success' }));
            this.isConfigModalOpen = false;
        } catch (e) { 
            console.error(e); 
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo guardar la configuración.', variant: 'error' }));
        } finally { 
            this.isLoading = false; 
        }
    }

    async handleToggleStatus() {
        if (!this.currentTableConfig) return;
        this.isLoading = true;
        try {
            const newStatus = !this.currentTableConfig.active;
            await toggleTableStatus({ label: this.surveyType, isActive: newStatus });
            await refreshApex(this.wiredConfigsResult);
            this.updateCurrentConfig();
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: `Tabla ${newStatus ? 'Activada' : 'Desactivada'}`, variant: 'info' }));
        } catch (e) { console.error(e); } finally { this.isLoading = false; }
    }

    @api
    async save() {
        if (!this.recordId) return true;
        this.isSaving = true;
        try {
            const diagData = { 
                gmUsuariasInt: this.gmUsuariasInt, gmUsuariasExt: this.gmUsuariasExt, gmFreqUso: this.gmFreqUso, 
                gmSanitarios: this.gmSanitarios, gmCubiculos: this.gmCubiculos, gmContenedores: this.gmContenedores, 
                gmFreqRecoleccion: this.gmFreqRecoleccion, gmDiasServicio: this.gmDiasServicio, gmHorario: this.gmHorario, 
                gmPermisos: this.gmPermisos, gmConsideraciones: this.gmConsideraciones, gmCapacitacion: this.gmCapacitacion, 
                gmPresupuesto: this.gmPresupuesto, gmMotivo: this.gmMotivo, gmPermiteLev: this.gmPermiteLev 
            };
            await saveSurveyData({ 
                oppId: this.recordId, type: this.surveyType, 
                surveyDataJson: JSON.stringify(this.surveyData), 
                diagDataJson: JSON.stringify(diagData) 
            });
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Levantamiento guardado.', variant: 'success' }));
            return true;
        } catch (error) { 
            console.error(error); 
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Error al guardar', 
                message: 'No se pudo guardar el levantamiento. Por favor intente de nuevo.', 
                variant: 'error' 
            }));
            return false;
        } finally { 
            this.isSaving = false; 
        }
    }

    handleSave() {
        this.save();
    }

    get surveyTypeOptions() {
        let options = [
            { label: 'Bioenzimático', value: 'BIOENZIMÁTICO' },
            { label: 'Grasas / Trampas', value: 'GRASAS' },
            { label: 'Gestión Menstrual (Íntima)', value: 'INTIMA' },
            { label: 'Desazolve Mecánico', value: 'DESAZOLVE MECANICO' },
            { label: 'Aromatizantes', value: 'AROMATIZANTES' },
            { label: 'Desazolve con Vactor', value: 'VACTOR' }
        ];

        if (this.allTableConfigs) {
            // Obtener los tipos que ya tienen datos en este registro
            const existingTypes = new Set((this._rawResult || []).map(r => (r.Tipo_Servicio__c || '').toUpperCase()));

            this.allTableConfigs.forEach(conf => {
                const val = (conf.label || '').toUpperCase();
                // Mostrar solo si está activa O si el registro actual ya tiene datos de ese tipo
                if (conf.active || existingTypes.has(val)) {
                    if (!options.find(opt => opt.value === val)) {
                        options.push({ label: conf.label + (conf.active ? '' : ' (Archivada)'), value: val });
                    }
                }
            });
        }
        return options;
    }

    get currentStatusLabel() {
        return this.currentTableConfig && this.currentTableConfig.active ? 'Desactivar Tabla' : 'Activar Tabla';
    }

    get currentStatusVariant() {
        return this.currentTableConfig && this.currentTableConfig.active ? 'destructive-text' : 'success';
    }

    get surveyTotals() {
        const type = (this.surveyType || '').toUpperCase();
        let t = { ve: 0, vp: 0, c10l: 0, c20l: 0, c25l: 0, piso: 0, mueble: 0, pared: 0, coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tgrasa: 0, st1: 0, ovalines: 0, sp: 0, ent: 0, tornillo: 0, sello: 0, mampara: 0, canastilla: 0, retSalida: 0, wc: 0, mingitorios: 0, mtLineal: 0, tarjas: 0, cuartoHumado: 0, arm: 0, largo: 0, ancho: 0, prof: 0, mtLinealVactor: 0 };
        if (!this.surveyData) return t;
        this.surveyData.forEach(row => {
            if (!row) return;
            t.ve += Number(row.ve || 0); t.vp += Number(row.vp || 0); t.c10l += Number(row.c10l || 0); t.c20l += Number(row.c20l || 0); t.c25l += Number(row.c25l || 0); t.piso += Number(row.piso || 0); t.mueble += Number(row.mueble || 0); t.pared += Number(row.pared || 0); t.coladeras += Number(row.coladeras || 0); t.tapon += Number(row.tapon || 0); t.tarja += Number(row.tarja || 0); t.tinas += Number(row.tinas || 0); t.tgrasa += Number(row.tgrasa || 0); t.st1 += Number(row.st1 || 0); t.ovalines += Number(row.ovalines || 0);
            t.sp += Number(row.sp || 0); t.ent += Number(row.ent || 0); t.tornillo += Number(row.tornillo || 0); t.sello += Number(row.sello || 0); t.mampara += Number(row.mampara || 0); t.canastilla += Number(row.canastilla || 0); t.retSalida += Number(row.retSalida || 0);
            t.wc += Number(row.wc || 0); t.mingitorios += Number(row.mingitorios || 0); t.mtLineal += Number(row.mtLineal || 0); t.tarjas += Number(row.tarjas || 0); t.cuartoHumado += Number(row.cuartoHumado || 0); t.arm += Number(row.arm || 0); t.largo += Number(row.largo || 0); t.ancho += Number(row.ancho || 0); t.prof += Number(row.prof || 0); t.mtLinealVactor += Number(row.mtLineal || 0);
        });
        return t;
    }

    get isBio() { return this.surveyType === 'BIOENZIMÁTICO'; }
    get isGrasas() { return this.surveyType === 'GRASAS'; }
    get isIntima() { return this.surveyType === 'INTIMA'; }
    get isDesazolveMec() { return this.surveyType === 'DESAZOLVE MECANICO'; }
    get isAromatizantes() { return this.surveyType === 'AROMATIZANTES'; }
    get isVactor() { return this.surveyType === 'VACTOR'; }
    get isGmFreqLV() { return this.gmFreqUso === 'Lunes a viernes'; }
    get isGmFreqAlt() { return this.gmFreqUso === 'Días alternados (ej. home office)'; }
    get isGmRec7() { return this.gmFreqRecoleccion === '7 días'; }
    get isGmRec14() { return this.gmFreqRecoleccion === '14 días'; }
    get isGmRec21() { return this.gmFreqRecoleccion === '21 días'; }
    get isGmRec28() { return this.gmFreqRecoleccion === '28 días'; }
    get isGmRecOtro() { return this.gmFreqRecoleccion === 'Otro:'; }
    get isGmDiasLV() { return this.gmDiasServicio === 'Lunes a Viernes'; }
    get isGmDiasFin() { return this.gmDiasServicio === 'Sábado o domingo'; }
    get isGmPermSi() { return this.gmPermisos === 'Si'; }
    get isGmPermNo() { return this.gmPermisos === 'No'; }
    get isGmCapSi() { return this.gmCapacitacion === 'Si'; }
    get isGmCapNo() { return this.gmCapacitacion === 'No'; }
    get isGmLevSi() { return this.gmPermiteLev === 'Si'; }
    get isGmLevNo() { return this.gmPermiteLev === 'No'; }
}