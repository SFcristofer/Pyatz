import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPLAnalysis from '@salesforce/apex/QuoteTechnicalController.getPLAnalysis';
import savePLAnalysis from '@salesforce/apex/QuoteTechnicalController.savePLAnalysis';
import getRelatedFiles from '@salesforce/apex/QuoteTechnicalController.getRelatedFiles';

export default class TechQuotePLAnalyzer extends NavigationMixin(LightningElement) {
    @api recordId;
    @api costoBase;
    
    @track isLoading = false;
    @track pl1 = { anio: 1, costo: 0, margen: 30, indirecto: 10, comision1: 3, comision2: 0, regalia: 5, dias: 30 };
    @track pl2 = { anio: 2, costo: 0, margen: 30, indirecto: 10, comision1: 3, comision2: 0, regalia: 5, dias: 30 };
    @track res1 = {};
    @track res2 = {};
    @track relatedFiles = [];

    connectedCallback() {
        this.pl1.costo = parseFloat(this.costoBase || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        this.pl2.costo = parseFloat(this.costoBase || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        this.loadPLData();
        this.loadFiles();
    }

    loadFiles() {
        getRelatedFiles({ recordId: this.recordId })
            .then(result => { this.relatedFiles = result; })
            .catch(error => { console.error('Error cargando archivos:', error); });
    }

    handleUploadFinished() {
        this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Documento cargado', variant: 'success' }));
        this.loadFiles();
    }

    handlePreviewFile(event) {
        const docId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: docId }
        });
    }

    loadPLData() {
        this.isLoading = true;
        getPLAnalysis({ quoteId: this.recordId })
            .then(result => {
                if (result && result.length > 0) {
                    result.forEach(rec => {
                        const data = {
                            anio: rec.Anio__c,
                            costo: rec.Costo_Inversion__c || this.costoBase,
                            margen: rec.Margen_Esperado__c,
                            indirecto: rec.Gastos_Indirectos__c,
                            comision1: rec.Comision_Venta__c,
                            comision2: rec.Comision_Venta_2__c || 0,
                            regalia: rec.Regalias__c,
                            dias: rec.Dias_Financiamiento__c
                        };
                        if (rec.Anio__c === 1) this.pl1 = data;
                        else this.pl2 = data;
                    });
                }
                this.recalculateAll();
            })
            .catch(err => { console.error('Error P&L:', err); })
            .finally(() => { this.isLoading = false; });
    }

    handleGlobalPLChange(event) {
        const field = event.target.dataset.field;
        const val = parseFloat(event.target.value) || 0;
        this.pl1 = { ...this.pl1, [field]: val };
        this.pl2 = { ...this.pl2, [field]: val };
        this.recalculateAll();
    }

    recalculateAll() {
        this.res1 = this.calculatePL(this.pl1);
        this.res2 = this.calculatePL(this.pl2);
    }

    calculatePL(data) {
        const costoVal = parseFloat(data.costo || 0);
        const margenVal = parseFloat(data.margen || 0);
        const indirectoVal = parseFloat(data.indirecto || 0);
        const comision1Val = parseFloat(data.comision1 || 0);
        const comision2Val = parseFloat(data.comision2 || 0);
        const regaliaVal = parseFloat(data.regalia || 0);
        const diasVal = parseFloat(data.dias || 0);

        const venta = margenVal >= 100 ? 0 : (costoVal / (1 - (margenVal / 100)));
        const ind = venta * (indirectoVal / 100);
        const com1 = venta * (comision1Val / 100);
        const com2 = venta * (comision2Val / 100);
        const reg = venta * (regaliaVal / 100);
        const fin = venta * 0.000611 * diasVal;

        const utilidadBruta = venta - costoVal - ind - com1 - com2 - reg - fin;
        const isr = utilidadBruta > 0 ? (utilidadBruta * 0.06) : 0;
        const ru = utilidadBruta > 0 ? (utilidadBruta * 0.05) : 0;

        const egresoTotal = costoVal + ind + com1 + com2 + reg + fin + isr + ru;
        const utilidadNeta = venta - egresoTotal;
        const margenRealPct = venta > 0 ? (utilidadNeta / venta) * 100 : 0;

        const fmt = (val) => val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

        return {
            venta: fmt(venta),
            ind: fmt(ind),
            com1: fmt(com1),
            com2: fmt(com2),
            reg: fmt(reg),
            fin: fmt(fin),
            isr: fmt(isr),
            ru: fmt(ru),
            costoReal: fmt(egresoTotal),
            utilidad: fmt(utilidadNeta),
            margenReal: margenRealPct.toFixed(2)
        };
    }

    handleCancel() { this.dispatchEvent(new CustomEvent('close')); }

    handleSave() {
        this.isLoading = true;
        const plData = [this.pl1, this.pl2];
        savePLAnalysis({ quoteId: this.recordId, plDataJson: JSON.stringify(plData) })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Análisis guardado', variant: 'success' }));
                this.handleCancel();
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err.body.message, variant: 'error' }));
            })
            .finally(() => { this.isLoading = false; });
    }
}