import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveSurveyData from '@salesforce/apex/QuoteTechnicalController.saveSurveyData';
import getLevantamientoDetails from '@salesforce/apex/QuoteTechnicalController.getLevantamientoDetails';

export default class TechLevantamientoManager extends LightningElement {
    @api recordId;
    @track surveyType = 'BIOENZIMÁTICO'; 
    @track surveyData = [];
    @track isSaving = false;
    @track isLoading = false;

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
        this.loadExistingData();
    }

    handleSurveyTypeChange(event) {
        this.surveyType = event.detail.value;
        this.loadExistingData();
    }

    loadExistingData() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.surveyData = []; 
        
        getLevantamientoDetails({ recordId: this.recordId })
            .then(result => {
                const type = this.surveyType.toUpperCase();
                const filtered = result.filter(r => r.Tipo_Servicio__c === type);
                
                if (filtered && filtered.length > 0) {
                    this.surveyData = filtered.map((r, idx) => {
                        let row = { 
                            id: r.Id, 
                            rowNumber: idx + 1, 
                            nivel: r.Nivel__c, 
                            area: r.Area_Cocina_Banos__c, 
                            zona: r.Zona_Genero__c, 
                            obs: r.Observaciones_Tecnicas__c 
                        };
                        
                        if (type === 'BIOENZIMÁTICO') {
                            Object.assign(row, { 
                                ve: r.VE__c, vp: r.VP__c, c10l: r.Bidon_10L__c, c20l: r.Bidon_20L__c, c25l: r.Bidon_25L__c, 
                                piso: r.Piso__c, mueble: r.Mueble__c, pared: r.Pared__c, 
                                foto: r.Fotografia__c, // CORRECCIÓN: Mapeo de foto
                                residuos: r.Residuos_Tarja__c, escamoche: r.Escamoche__c, instala: r.Estado_Instalacion__c, azolves: r.Azolves__c, 
                                coladeras: r.Coladeras__c, tapon: r.Tapon_Registro__c, tarja: r.Tarja__c, tinas: r.Tinas_por_Tarja__c, 
                                tgrasa: r.Trampa_Grasa__c, modelo: r.Modelo_TG_Bio__c, st1: r.ST_1__c, ovalines: r.Ovalines_Lavabo__c 
                            });
                        } else if (type === 'GRASAS') {
                            Object.assign(row, { 
                                sp: r.SP__c, ent: r.ENT__c, modelo: r.Modelo_Grasas__c, frecuencia: r.Frecuencia_Limpieza__c, 
                                estado: r.Estado_Trampa__c, tornillo: r.Tornillo__c, sello: r.Sello__c, mampara: r.Mampara__c, 
                                canastilla: r.Canastilla__c, retSalida: r.Ret_Salida__c, 
                                foto: r.Fotografia__c // Mapeo de foto para grasas también
                            });
                        } else if (type === 'INTIMA') {
                            Object.assign(row, { wc: r.WC__c, frecuencia: r.Frecuencia__c, dias: r.Dias_Servicio_Censo__c });
                            this.gmUsuariasInt = r.GM_Usuarias_Internas__c;
                            this.gmUsuariasExt = r.GM_Usuarias_Externas__c;
                            this.gmFreqUso = r.GM_Frecuencia_Uso__c;
                            this.gmSanitarios = r.GM_Sanitarios_Totales__c;
                            this.gmCubiculos = r.GM_Cubiculos_Totales__c;
                            this.gmContenedores = r.GM_Contenedores_Sugeridos__c;
                            this.gmFreqRecoleccion = r.GM_Frecuencia_Recoleccion__c;
                            this.gmDiasServicio = r.GM_Dias_Servicio__c;
                            this.gmHorario = r.GM_Horario_Servicio__c;
                            this.gmPermisos = r.GM_Permisos_Acceso__c;
                            this.gmConsideraciones = r.GM_Consideraciones_Especiales__c;
                            this.gmCapacitacion = r.GM_Requiere_Capacitacion__c;
                            this.gmPresupuesto = r.GM_Presupuesto_Asignado__c;
                            this.gmMotivo = r.GM_Motivo_Necesidad__c;
                            this.gmPermiteLev = r.GM_Permite_Levantamiento_Foto__c;
                        } else if (type === 'DESAZOLVE MECANICO') {
                            Object.assign(row, { ovalines: r.Ovalines_Lavabo__c, coladeras: r.Coladeras__c, tapon: r.Tapon_Registro__c, mingitorios: r.Mingitorios__c, wc: r.WC__c, mtLineal: r.Metros_Lineales__c, tarjas: r.Tarjas_Servicios__c, cuartoHumado: r.Cuarto_Humado__c });
                        } else if (type === 'AROMATIZANTES') {
                            Object.assign(row, { arm: r.Equipos_ARM__c });
                        } else if (type === 'VACTOR') {
                            Object.assign(row, { descripcion: r.Vactor_Descripcion__c, medida: r.Vactor_Medida__c, material: r.Vactor_Material__c, servicio: r.Vactor_Servicio_Requerido__c, largo: r.Vactor_Largo__c, ancho: r.Vactor_Ancho__c, prof: r.Vactor_Profundidad__c, mtLineal: r.Metros_Lineales__c, distancia: r.Vactor_Distancia_Camion__c, permDelegacion: r.Vactor_Permiso_Delegacion__c, permPlaza: r.Vactor_Permiso_Plaza__c, dificultad: r.Vactor_Dificultad__c, alcance: r.Vactor_Alcance_Pyatz__c });
                        }
                        return row;
                    });
                } else {
                    this.handleAddSurveyRow();
                }
            })
            .catch(error => {
                console.error('Error loading survey:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
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