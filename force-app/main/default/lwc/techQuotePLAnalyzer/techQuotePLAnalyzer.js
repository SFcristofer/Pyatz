import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPLAnalysis from '@salesforce/apex/QuoteTechnicalController.getPLAnalysis';
import savePLAnalysis from '@salesforce/apex/QuoteTechnicalController.savePLAnalysis';

export default class TechQuotePLAnalyzer extends LightningElement {
    @api recordId;
    @api costoBase = 0; // Costo que viene de los servicios agregados en el editor padre

    @track isLoading = false;
    @track pl1 = { costo: 0, margen: 25, indirecto: 15, comision1: 2, comision2: 0, regalia: 5, dias: 7 };
    @track pl2 = { costo: 0, margen: 41, indirecto: 15, comision1: 2, comision2: 0, regalia: 5, dias: 7 };

    connectedCallback() {
        this.loadPLData();
    }

    // Si el costo base cambia en el padre, actualizamos los escenarios
    @api
    refreshCosto(nuevoCosto) {
        this.pl1.costo = nuevoCosto;
        this.pl2.costo = nuevoCosto;
    }

    loadPLData() {
        if (!this.recordId) return;
        this.isLoading = true;
        getPLAnalysis({ quoteId: this.recordId })
            .then(plRecords => {
                if (plRecords && plRecords.length > 0) {
                    plRecords.forEach(rec => {
                        const data = {
                            costo: rec.Costo_Inversion__c || this.costoBase,
                            margen: rec.Margen_Esperado__c,
                            indirecto: rec.Gastos_Indirectos__c,
                            comision1: rec.Comision_Venta__c,
                            comision2: 0,
                            regalia: rec.Regalias__c,
                            dias: rec.Dias_Financiamiento__c
                        };
                        if (rec.Anio__c === 1) this.pl1 = data;
                        else if (rec.Anio__c === 2) this.pl2 = data;
                    });
                } else {
                    // Si no hay registros, usar el costo base que viene del padre
                    this.pl1.costo = this.costoBase;
                    this.pl2.costo = this.costoBase;
                }
            })
            .catch(err => console.error('Error cargando P&L:', err))
            .finally(() => { this.isLoading = false; });
    }

    calculatePL(data) {
        const venta = data.margen >= 100 ? 0 : (data.costo / (1 - (data.margen / 100)));
        const ind = venta * (data.indirecto / 100);
        const com1 = venta * (data.comision1 / 100);
        const com2 = venta * (data.comision2 / 100);
        const reg = venta * (data.regalia / 100);
        const fin = venta * 0.000611 * data.dias;

        const utilidadBruta = venta - data.costo - ind - com1 - com2 - reg - fin;
        const isr = utilidadBruta > 0 ? (utilidadBruta * 0.06) : 0;
        const ru = utilidadBruta > 0 ? (utilidadBruta * 0.05) : 0;

        const costoTotal = parseFloat(data.costo) + ind + com1 + com2 + reg + fin + isr + ru;
        const margenDolares = venta - costoTotal;
        const margenPct = venta > 0 ? (margenDolares / venta) * 100 : 0;

        return {
            venta: venta.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            ind: ind.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            com1: com1.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            com2: com2.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            reg: reg.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            fin: fin.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            isr: isr.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            ru: ru.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            costoTotal: costoTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            resPesos: margenDolares.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
            resPct: margenPct.toFixed(2)
        };
    }

    get res1() { return this.calculatePL(this.pl1); }
    get res2() { return this.calculatePL(this.pl2); }

    handleGlobalPLChange(event) {
        const field = event.target.dataset.field;
        const val = parseFloat(event.target.value) || 0;
        this.pl1 = { ...this.pl1, [field]: val };
        this.pl2 = { ...this.pl2, [field]: val };
    }

    handlePL1Change(event) {
        const field = event.target.dataset.field;
        this.pl1 = { ...this.pl1, [field]: parseFloat(event.target.value) || 0 };
    }

    handlePL2Change(event) {
        const field = event.target.dataset.field;
        this.pl2 = { ...this.pl2, [field]: parseFloat(event.target.value) || 0 };
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        if (!this.recordId) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Atención', message: 'Guarde el presupuesto antes de aplicar el P&L.', variant: 'warning' }));
            return;
        }
        this.isLoading = true;
        const plData = [ { anio: 1, ...this.pl1 }, { anio: 2, ...this.pl2 } ];

        savePLAnalysis({ quoteId: this.recordId, plDataJson: JSON.stringify(plData) })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Análisis P&L guardado y aplicado.', variant: 'success' }));
                this.handleClose();
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body.message, variant: 'error' }));
            })
            .finally(() => { this.isLoading = false; });
    }
}