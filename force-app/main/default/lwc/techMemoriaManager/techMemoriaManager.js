import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitialData from '@salesforce/apex/QuoteTechnicalController.getInitialData';
import saveMemoria from '@salesforce/apex/QuoteTechnicalController.saveMemoria';
import getLevantamientoSummary from '@salesforce/apex/QuoteTechnicalController.getLevantamientoSummary';

export default class TechMemoriaManager extends LightningElement {
    @api recordId;
    @track memoriaText = '';
    @track surveySummary = [];
    @track isSaving = false;

    connectedCallback() {
        this.loadInitialData();
        this.loadSummary();
    }

    loadInitialData() {
        getInitialData({ recordId: this.recordId })
            .then(result => {
                if (result.quote) {
                    this.memoriaText = result.quote.Memoria_Descriptiva__c || '';
                }
            })
            .catch(error => {
                console.error('Error loading initial data:', error);
            });
    }

    loadSummary() {
        getLevantamientoSummary({ recordId: this.recordId })
            .then(result => {
                this.surveySummary = result;
            })
            .catch(error => {
                console.error('Error loading summary:', error);
            });
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
                    message: error.body.message,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }
}