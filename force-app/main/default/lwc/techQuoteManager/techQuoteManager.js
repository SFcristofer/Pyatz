import { LightningElement, track, api } from 'lwc';

export default class TechQuoteManager extends LightningElement {
    @api recordId;
    @track viewMode = 'list'; // 'list' o '360'
    @track selectedRecordId = null;

    // Al iniciar, si ya viene un recordId (ej: en una Record Page), ir directo al 360
    connectedCallback() {
        if (this.recordId) {
            this.selectedRecordId = this.recordId;
            this.viewMode = '360';
        }
    }

    // --- NAVEGACIÓN PREMIUM ---
    
    // Al seleccionar una oportunidad desde la lista
    handleSelectOpportunity(event) {
        this.selectedRecordId = event.detail;
        this.viewMode = '360';
    }

    // Al presionar el botón de volver al listado
    handleShowList() {
        this.selectedRecordId = null;
        this.viewMode = 'list';
    }

    // Getters para renderizado condicional
    get isListView() {
        return this.viewMode === 'list';
    }

    get is360View() {
        return this.viewMode === '360';
    }
}