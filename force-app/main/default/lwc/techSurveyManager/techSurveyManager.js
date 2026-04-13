import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TechSurveyManager extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track surveyType = 'BIO';
    @track surveyData = [];
    @track isLoading = false;

    // Estados específicos para Gestión Menstrual (Íntima)
    @track gmUsuariasInt; @track gmUsuariasExt; @track gmFreqUso; @track gmSanitarios;
    @track gmCubiculos; @track gmContenedores; @track gmFreqRecoleccion; @track gmDiasServicio;
    @track gmHorario; @track gmPermisos; @track gmConsideraciones; @track gmCapacitacion;
    @track gmPresupuesto; @track gmMotivo; @track gmPermiteLev;

    get surveyTypeOptions() {
        return [
            { label: 'Bioenzimático (Cocina/Baños)', value: 'BIO' },
            { label: 'Grasas / Trampas', value: 'GRASAS' },
            { label: 'Gestión Menstrual (Íntima)', value: 'INTIMA' },
            { label: 'Desazolve Mecánico', value: 'DESAZOLVE_MEC' },
            { label: 'Aromatizantes', value: 'AROMATIZANTES' },
            { label: 'Vactor (Servicio Pesado)', value: 'VACTOR' }
        ];
    }

    // Identificadores de Plantilla
    get isBio() { return this.surveyType === 'BIO'; }
    get isGrasas() { return this.surveyType === 'GRASAS'; }
    get isIntima() { return this.surveyType === 'INTIMA'; }
    get isDesazolveMec() { return this.surveyType === 'DESAZOLVE_MEC'; }
    get isAromatizantes() { return this.surveyType === 'AROMATIZANTES'; }
    get isVactor() { return this.surveyType === 'VACTOR'; }

    connectedCallback() {
        this.handleAddSurveyRow(); // Fila inicial por defecto
    }

    handleSurveyTypeChange(event) {
        this.surveyType = event.detail.value;
        this.surveyData = [];
        this.handleAddSurveyRow();
    }

    handleAddSurveyRow() {
        const newRow = { 
            id: Date.now(), 
            rowNumber: this.surveyData.length + 1,
            nivel: '', area: '', zona: '',
            // Bio
            ve: 0, vp: 0, b10: 0, b20: 0, b25: 0, piso: 0, mueble: 0, pared: 0,
            residuos: '', escamoche: '', inst: '', azolves: '', obs: '',
            coladeras: 0, tapon: 0, tarja: 0, tinas: 0, tg: 0, modtg: '', st1: 0, ovalines: 0,
            // Grasas
            sp: 0, ent: 0, modelo: '', frecuencia: '', estado: '',
            tornillo: 0, sello: 0, mampara: 0, canastilla: 0, ret: 0,
            // Vactor
            desc: '', medida: '', material: '', servicio: '', largo: 0, ancho: 0, prof: 0, metros: 0,
            distancia: '', permiso: '', dificultad: ''
        };
        this.surveyData = [...this.surveyData, newRow];
    }

    handleRemoveSurveyRow(event) {
        const index = event.currentTarget.dataset.index;
        this.surveyData = this.surveyData.filter((_, i) => i !== parseInt(index));
        // Re-enumerar
        this.surveyData = this.surveyData.map((row, i) => ({ ...row, rowNumber: i + 1 }));
    }

    handleSurveyChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        const value = event.target.value;
        let newData = [...this.surveyData];
        newData[index][field] = value;
        this.surveyData = newData;
    }

    handleGmChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    // Cálculos de Totales (Getters)
    get surveyTotals() {
        let totals = { wc: 0, arm: 0, ovalines: 0, coladeras: 0, tapon: 0, mingitorios: 0, tarjas: 0 };
        this.surveyData.forEach(row => {
            if (row.wc) totals.wc += parseFloat(row.wc) || 0;
            if (row.arm) totals.arm += parseFloat(row.arm) || 0;
            if (row.ovalines) totals.ovalines += parseFloat(row.ovalines) || 0;
            if (row.coladeras) totals.coladeras += parseFloat(row.coladeras) || 0;
            if (row.tapon) totals.tapon += parseFloat(row.tapon) || 0;
            if (row.mingitorios) totals.mingitorios += parseFloat(row.mingitorios) || 0;
            if (row.tarjas) totals.tarjas += parseFloat(row.tarjas) || 0;
        });
        return totals;
    }

    handleSaveSurvey() {
        this.isLoading = true;
        
        // Empaquetar todo el estado del levantamiento
        const markersData = {
            surveyType: this.surveyType,
            surveyData: this.surveyData,
            gmData: {
                int: this.gmUsuariasInt, ext: this.gmUsuariasExt, freq: this.gmFreqUso,
                san: this.gmSanitarios, cub: this.gmCubiculos, cont: this.gmContenedores
            }
        };

        const jsonString = JSON.stringify(markersData);
        const base64Data = btoa(unescape(encodeURIComponent(jsonString)));

        console.log('Datos de Levantamiento Preparados:', markersData);

        // Simulamos el guardado para que el usuario visualice el flujo
        setTimeout(() => {
            this.isLoading = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Levantamiento Capturado',
                message: 'La información ha sido preparada para guardarse en la ' + this.objectApiName + ' (Simulado hasta crear el campo).',
                variant: 'success'
            }));
        }, 800);
    }
}