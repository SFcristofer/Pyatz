import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveSurveyData from '@salesforce/apex/QuoteTechnicalController.saveSurveyData';

export default class TechLevantamientoManager extends LightningElement {
    @api recordId;
    @track surveyType = 'BIOENZIMÁTICO'; // Sincronizado con el valor oficial
    @track surveyData = [];
    @track isSaving = false;

    // --- VARIABLES GESTIÓN MENSTRUAL ---
    @track gmUsuariasInt = 0; @track gmUsuariasExt = 0; @track gmFreqUso = '';
    @track gmSanitarios = 0; @track gmCubiculos = 0; @track gmContenedores = 0;
    @track gmFreqRecoleccion = ''; @track gmDiasServicio = ''; @track gmHorario = '';
    @track gmPermisos = ''; @track gmConsideraciones = ''; @track gmCapacitacion = '';
    @track gmPresupuesto = ''; @track gmMotivo = ''; @track gmPermiteLev = '';

    // API pública para que el orquestador pueda ordenar el guardado
    @api 
    async save() {
        return this.handleSave();
    }

    async handleSave() {
        if (!this.recordId) return false;
        
        this.isSaving = true;
        try {
            // Recopilar datos de diagnóstico para Gestión Menstrual
            const diagData = {
                gmUsuariasInt: this.gmUsuariasInt,
                gmUsuariasExt: this.gmUsuariasExt,
                gmFreqUso: this.gmFreqUso,
                gmSanitarios: this.gmSanitarios,
                gmCubiculos: this.gmCubiculos,
                gmContenedores: this.gmContenedores,
                gmFreqRecoleccion: this.gmFreqRecoleccion,
                gmDiasServicio: this.gmDiasServicio,
                gmHorario: this.gmHorario,
                gmPermisos: this.gmPermisos,
                gmConsideraciones: this.gmConsideraciones,
                gmCapacitacion: this.gmCapacitacion,
                gmPresupuesto: this.gmPresupuesto,
                gmMotivo: this.gmMotivo,
                gmPermiteLev: this.gmPermiteLev
            };

            await saveSurveyData({
                oppId: this.recordId,
                type: this.surveyType,
                surveyDataJson: JSON.stringify(this.surveyData),
                diagDataJson: JSON.stringify(diagData) // Nuevo parámetro
            });
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Levantamiento ' + this.surveyType + ' guardado correctamente.',
                variant: 'success'
            }));
            return true;
        } catch (error) {
            console.error('Error saving survey:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error al guardar',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
            return false;
        } finally {
            this.isSaving = false;
        }
    }

    connectedCallback() {
        if (this.surveyData.length === 0) {
            this.handleAddSurveyRow();
        }
    }

    get surveyTypeOptions() {
        return [
            { label: 'Bioenzimático', value: 'BIOENZIMÁTICO' },
            { label: 'Grasas / Trampas', value: 'GRASAS' },
            { label: 'Gestión Menstrual (Íntima)', value: 'INTIMA' },
            { label: 'Desazolve Mecánico', value: 'DESAZOLVE MECANICO' },
            { label: 'Aromatizantes', value: 'AROMATIZANTES' },
            { label: 'Desazolve con Vactor', value: 'VACTOR' }
        ];
    }

    // Getters de visibilidad
    get isBio() { return this.surveyType === 'BIOENZIMÁTICO'; }
    get isGrasas() { return this.surveyType === 'GRASAS'; }
    get isIntima() { return this.surveyType === 'INTIMA'; }
    get isDesazolveMec() { return this.surveyType === 'DESAZOLVE MECANICO'; }
    get isAromatizantes() { return this.surveyType === 'AROMATIZANTES'; }
    get isVactor() { return this.surveyType === 'VACTOR'; }

    handleSurveyTypeChange(event) {
        this.surveyType = event.detail.value;
        this.surveyData = [];
        this.handleAddSurveyRow();
    }

    handleAddSurveyRow() {
        const type = this.surveyType;
        let newRow = { id: Date.now() + Math.random(), rowNumber: this.surveyData.length + 1 };
        
        if (type === 'BIOENZIMÁTICO') {
            Object.assign(newRow, { nivel: '', area: '', zona: '', ve: 0, vp: 0, c10l: 0, c20l: 0, c25l: 0, piso: 0, mueble: 0, pared: 0, foto: '', residuos: '', escamoche: '', instala: '', azolves: '', obs: '', coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tgrasa: 0, modelo: '', st1: 0, ovalines: 0 });
        } else if (type === 'GRASAS') {
            Object.assign(newRow, { nivel: '', area: '', zona: '', sp: 0, ent: 0, modelo: '', frecuencia: '', estado: '', tornillo: 0, sello: 0, mampara: 0, canastilla: 0, retSalida: 0, foto: '' });
        } else if (type === 'INTIMA') {
            Object.assign(newRow, { nivel: '', area: '', zona: '', wc: 0, frecuencia: '', dias: '' });
        } else if (type === 'DESAZOLVE MECANICO') {
            Object.assign(newRow, { nivel: '', area: '', zona: '', ovalines: 0, coladeras: 0, tapon: 0, mingitorios: 0, wc: 0, mtLineal: 0, tarjas: 0, cuartoHumado: 0 });
        } else if (type === 'AROMATIZANTES') {
            Object.assign(newRow, { nivel: '', area: '', zona: '', arm: 0 });
        } else if (type === 'VACTOR') {
            Object.assign(newRow, { descripcion: '', medida: '', material: '', servicio: '', largo: 0, ancho: 0, prof: 0, mtLineal: 0, distancia: '', permDelegacion: '', permPlaza: '', dificultad: '', alcance: '', obs: '' });
        }
        
        this.surveyData = [...this.surveyData, newRow];
    }

    handleRemoveSurveyRow(event) {
        const index = event.target.dataset.index;
        const data = [...this.surveyData];
        data.splice(index, 1);
        this.surveyData = data.map((row, idx) => ({ ...row, rowNumber: idx + 1 }));
    }

    handleSurveyChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        const value = event.target.value;
        const data = [...this.surveyData];
        data[index][field] = value;

        // Lógica de colores dinámica
        if (field === 'escamoche') {
            if (value && value.includes('Correcto')) data[index].escamocheClass = 'cell-select bg-green-soft';
            else if (value && value.includes('medias')) data[index].escamocheClass = 'cell-select bg-orange-soft';
            else if (value && value.includes('Pésimo')) data[index].escamocheClass = 'cell-select bg-red-soft';
            else data[index].escamocheClass = 'cell-select';
        }
        if (field === 'estado') {
            if (value === 'EN BUEN ESTADO') data[index].estadoClass = 'cell-select bg-green-soft';
            else if (value === 'EN MAL ESTADO') data[index].estadoClass = 'cell-select bg-orange-soft';
            else if (value === 'EN PESIMO ESTADO') data[index].estadoClass = 'cell-select bg-red-soft';
            else data[index].estadoClass = 'cell-select';
        }
        this.surveyData = data;
    }

    handleGmChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    // Getters para totales automáticos
    get surveyTotals() {
        const type = this.surveyType;
        let totals = { ve: 0, vp: 0, c10l: 0, c20l: 0, c25l: 0, piso: 0, mueble: 0, pared: 0, coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tgrasa: 0, st1: 0, ovalines: 0, sp: 0, ent: 0, tornillo: 0, sello: 0, mampara: 0, canastilla: 0, retSalida: 0, wc: 0, mingitorios: 0, mtLineal: 0, tarjas: 0, cuartoHumado: 0, arm: 0, largo: 0, ancho: 0, prof: 0, mtLinealVactor: 0 };
        
        this.surveyData.forEach(row => {
            if (type === 'BIOENZIMÁTICO') { 
                totals.ve += Number(row.ve || 0); totals.vp += Number(row.vp || 0); totals.c10l += Number(row.c10l || 0); totals.c20l += Number(row.c20l || 0); totals.c25l += Number(row.c25l || 0); totals.piso += Number(row.piso || 0); totals.mueble += Number(row.mueble || 0); totals.pared += Number(row.pared || 0); totals.coladeras += Number(row.coladeras || 0); totals.tapon += Number(row.tapon || 0); totals.tarja += Number(row.tarja || 0); totals.tinas += Number(row.tinas || 0); totals.tgrasa += Number(row.tgrasa || 0); totals.st1 += Number(row.st1 || 0); totals.ovalines += Number(row.ovalines || 0); 
            }
            else if (type === 'GRASAS') { 
                totals.sp += Number(row.sp || 0); totals.ent += Number(row.ent || 0); totals.tornillo += Number(row.tornillo || 0); totals.sello += Number(row.sello || 0); totals.mampara += Number(row.mampara || 0); totals.canastilla += Number(row.canastilla || 0); totals.retSalida += Number(row.retSalida || 0); 
            }
            else if (type === 'INTIMA') { totals.wc += Number(row.wc || 0); }
            else if (type === 'DESAZOLVE MECANICO') { 
                totals.ovalines += Number(row.ovalines || 0); totals.coladeras += Number(row.coladeras || 0); totals.tapon += Number(row.tapon || 0); totals.mingitorios += Number(row.mingitorios || 0); totals.wc += Number(row.wc || 0); totals.mtLineal += Number(row.mtLineal || 0); totals.tarjas += Number(row.tarjas || 0); totals.cuartoHumado += Number(row.cuartoHumado || 0); 
            }
            else if (type === 'AROMATIZANTES') { totals.arm += Number(row.arm || 0); }
            else if (type === 'VACTOR') { 
                totals.largo += Number(row.largo || 0); 
                totals.ancho += Number(row.ancho || 0); 
                totals.prof += Number(row.prof || 0); 
                totals.mtLinealVactor += Number(row.mtLineal || 0); 
            }
        });
        return totals;
    }

    // Getters auxiliares para Gestión Menstrual (checks de visualización)
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