import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitialData from '@salesforce/apex/QuoteTechnicalController.getInitialData';
import saveMemoria from '@salesforce/apex/QuoteTechnicalController.saveMemoria';
import getLevantamientoDetails from '@salesforce/apex/QuoteTechnicalController.getLevantamientoDetails';

export default class TechMemoriaManager extends LightningElement {
    @api recordId;
    @track memoriaText = '';
    @track groupedDetails = [];
    @track isSaving = false;

    connectedCallback() {
        this.loadInitialData();
        this.loadDetails();
    }

    loadInitialData() {
        getInitialData({ recordId: this.recordId })
            .then(result => {
                const data = result.quote || result.opportunity;
                if (data) {
                    this.memoriaText = data.Memoria_Descriptiva__c || '';
                }
            })
            .catch(error => {
                console.error('Error loading initial data:', error);
            });
    }

    loadDetails() {
        getLevantamientoDetails({ recordId: this.recordId })
            .then(result => {
                this.formatGroupedDetails(result);
            })
            .catch(error => {
                console.error('Error loading details:', error);
            });
    }

    formatGroupedDetails(records) {
        const groups = {};
        records.forEach(rec => {
            const type = rec.Tipo_Servicio__c || 'GENERAL';
            if (!groups[type]) {
                groups[type] = { label: type, records: [] };
            }
            
            // Preparar campos visibles dinámicamente
            let detailItems = [];
            if (rec.Nivel__c) detailItems.push({ label: 'Nivel', value: rec.Nivel__c });
            if (rec.Area_Cocina_Banos__c) detailItems.push({ label: 'Área', value: rec.Area_Cocina_Banos__c });
            if (rec.Zona_Genero__c) detailItems.push({ label: 'Zona', value: rec.Zona_Genero__c });
            if (rec.Estado_Instalacion__c) detailItems.push({ label: 'Estado', value: rec.Estado_Instalacion__c });
            if (rec.Cantidad_Principal__c > 0) detailItems.push({ label: 'Cantidad', value: rec.Cantidad_Principal__c });
            if (rec.Metros_Lineales__c > 0) detailItems.push({ label: 'Metros', value: rec.Metros_Lineales__c });
            if (rec.Frecuencia__c) detailItems.push({ label: 'Frecuencia', value: rec.Frecuencia__c });

            groups[type].records.push({
                id: rec.Id,
                name: rec.Name,
                obs: rec.Observaciones_Tecnicas__c,
                fields: detailItems
            });
        });
        this.groupedDetails = Object.values(groups);
    }

    handleTextChange(event) {
        this.memoriaText = event.target.value;
    }

    handleSave() {
        this.isSaving = true;
        saveMemoria({ recordId: this.recordId, text: this.memoriaText })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Memoria descriptiva guardada correctamente.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }
}