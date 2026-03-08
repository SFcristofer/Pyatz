import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveSurveyData from '@salesforce/apex/QuoteTechnicalController.saveSurveyData';

export default class TechLevantamientoManager extends LightningElement {
    @api recordId;
    @track surveyType = 'Bioenzimatico';
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
            await saveSurveyData({
                oppId: this.recordId,
                type: this.surveyType,
                surveyDataJson: JSON.stringify(this.surveyData)
            });
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Levantamiento guardado correctamente.',
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
            { label: 'Bioenzimático', value: 'Bioenzimatico' },
            { label: 'Grasas / Trampas', value: 'Grasas' },
            { label: 'Gestión Menstrual (Íntima)', value: 'Intima' },
            { label: 'Desazolve Mecánico', value: 'DesazolveMec' },
            { label: 'Aromatizantes', value: 'Aromatizantes' },
            { label: 'Desazolve con Vactor', value: 'Vactor' }
        ];
    }

    // Getters de visibilidad
    get isBio() { return this.surveyType === 'Bioenzimatico'; }
    get isGrasas() { return this.surveyType === 'Grasas'; }
    get isIntima() { return this.surveyType === 'Intima'; }
    get isDesazolveMec() { return this.surveyType === 'DesazolveMec'; }
    get isAromatizantes() { return this.surveyType === 'Aromatizantes'; }
    get isVactor() { return this.surveyType === 'Vactor'; }

    handleSurveyTypeChange(event) {
        this.surveyType = event.detail.value;
        this.surveyData = [];
        this.handleAddSurveyRow();
    }

    handleAddSurveyRow() {
        let newRow = { id: Date.now(), rowNumber: this.surveyData.length + 1 };
        
        if (this.isBio) {
            Object.assign(newRow, { nivel: '', area: '', zona: '', ve: 0, vp: 0, c10l: 0, c20l: 0, c25l: 0, piso: 0, mueble: 0, pared: 0, foto: '', residuos: '', escamoche: '', instala: '', azolves: '', obs: '', coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tgrasa: 0, modelo: '', st1: 0, ovalines: 0 });
        } else if (this.isGrasas) {
            Object.assign(newRow, { nivel: '', area: '', zona: '', sp: 0, ent: 0, modelo: '', frecuencia: '', estado: '', tornillo: 0, sello: 0, mampara: 0, canastilla: 0, retSalida: 0, foto: '' });
        } else if (this.isIntima) {
            Object.assign(newRow, { nivel: '', area: '', zona: '', wc: 0, frecuencia: '', dias: '' });
        } else if (this.isDesazolveMec) {
            Object.assign(newRow, { nivel: '', area: '', zona: '', ovalines: 0, coladeras: 0, tapon: 0, mingitorios: 0, wc: 0, mtLineal: 0, tarjas: 0, cuartoHumado: 0 });
        } else if (this.isAromatizantes) {
            Object.assign(newRow, { nivel: '', area: '', zona: '', arm: 0 });
        } else if (this.isVactor) {
            Object.assign(newRow, { desc: '', medida: '', material: '', servicio: '', largo: 0, ancho: 0, prof: 0, mtLineal: 0, distancia: '', permDelegacion: '', permPlaza: '', dificultad: '', alcance: '', obs: '' });
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
            if (value.includes('Correcto')) data[index].escamocheClass = 'cell-select bg-green-soft';
            else if (value.includes('medias')) data[index].escamocheClass = 'cell-select bg-orange-soft';
            else if (value.includes('Pésimo')) data[index].escamocheClass = 'cell-select bg-red-soft';
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
        let totals = { ve: 0, vp: 0, c10l: 0, c20l: 0, c25l: 0, piso: 0, mueble: 0, pared: 0, coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tgrasa: 0, st1: 0, ovalines: 0, sp: 0, ent: 0, tornillo: 0, sello: 0, mampara: 0, canastilla: 0, retSalida: 0, wc: 0, mingitorios: 0, mtLineal: 0, tarjas: 0, cuartoHumado: 0, arm: 0, largo: 0, ancho: 0, prof: 0, mtLinealVactor: 0 };
        this.surveyData.forEach(row => {
            if (this.isBio) { 
                totals.ve += Number(row.ve || 0); totals.vp += Number(row.vp || 0); totals.c10l += Number(row.c10l || 0); totals.c20l += Number(row.c20l || 0); totals.c25l += Number(row.c25l || 0); totals.piso += Number(row.piso || 0); totals.mueble += Number(row.mueble || 0); totals.pared += Number(row.pared || 0); totals.coladeras += Number(row.coladeras || 0); totals.tapon += Number(row.tapon || 0); totals.tarja += Number(row.tarja || 0); totals.tinas += Number(row.tinas || 0); totals.tgrasa += Number(row.tgrasa || 0); totals.st1 += Number(row.st1 || 0); totals.ovalines += Number(row.ovalines || 0); 
            }
            else if (this.isGrasas) { 
                totals.sp += Number(row.sp || 0); totals.ent += Number(row.ent || 0); totals.tornillo += Number(row.tornillo || 0); totals.sello += Number(row.sello || 0); totals.mampara += Number(row.mampara || 0); totals.canastilla += Number(row.canastilla || 0); totals.retSalida += Number(row.retSalida || 0); 
            }
            else if (this.isIntima) { totals.wc += Number(row.wc || 0); }
            else if (this.isDesazolveMec) { 
                totals.ovalines += Number(row.ovalines || 0); totals.coladeras += Number(row.coladeras || 0); totals.tapon += Number(row.tapon || 0); totals.mingitorios += Number(row.mingitorios || 0); totals.wc += Number(row.wc || 0); totals.mtLineal += Number(row.mtLineal || 0); totals.tarjas += Number(row.tarjas || 0); totals.cuartoHumado += Number(row.cuartoHumado || 0); 
            }
            else if (this.isAromatizantes) { totals.arm += Number(row.arm || 0); }
            else if (this.isVactor) { 
                totals.largo += Number(row.largo || 0); totals.ancho += Number(row.ancho || 0); totals.prof += Number(row.prof || 0); totals.mtLinealVactor += Number(row.mtLineal || 0); 
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