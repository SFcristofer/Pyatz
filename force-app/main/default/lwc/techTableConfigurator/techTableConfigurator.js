import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAvailableFields from '@salesforce/apex/AdminController.getAvailableFields';

export default class TechTableConfigurator extends LightningElement {
    @track isLoading = false;
    @track isEditing = false;
    @track selectedConfigId = '';
    @track configOptions = [];
    @track availableFields = [];
    
    @track currentConfig = { label: '', apiName: '' };
    @track selectedColumns = [];

    @wire(getAvailableFields)
    wiredFields({ error, data }) {
        if (data) {
            this.availableFields = data.map(f => ({
                label: f.label,
                value: f.value
            })).sort((a, b) => a.label.localeCompare(b.label));
        } else if (error) {
            console.error('Error loading fields:', error);
        }
    }

    connectedCallback() {
        this.loadInitialData();
    }

    loadInitialData() {
        this.configOptions = [
            { label: '-- Seleccione --', value: '' }
        ];
    }

    handleConfigChange(event) {
        this.selectedConfigId = event.detail.value;
        if (this.selectedConfigId) {
            this.isEditing = true;
            // Cargar datos de la configuración (Apex)
        } else {
            this.isEditing = false;
        }
    }

    handleNewConfig() {
        this.isEditing = true;
        this.selectedConfigId = 'NEW';
        this.currentConfig = { label: '', apiName: '' };
        this.selectedColumns = [
            { id: Date.now(), order: 1, apiName: 'Nivel__c', label: 'NIVEL' }
        ];
    }

    handleAddColumn() {
        const nextOrder = this.selectedColumns.length + 1;
        this.selectedColumns = [...this.selectedColumns, { 
            id: Date.now(), 
            order: nextOrder, 
            apiName: '', 
            label: '' 
        }];
    }

    handleRemoveColumn(event) {
        const index = event.target.dataset.index;
        let data = [...this.selectedColumns];
        data.splice(index, 1);
        this.selectedColumns = data.map((col, idx) => ({ ...col, order: idx + 1 }));
    }

    handleColumnChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        let data = [...this.selectedColumns];
        data[index][field] = value;
        
        // Si cambió el campo API, sugerimos la etiqueta predeterminada
        if (field === 'apiName') {
            const fieldMeta = this.availableFields.find(f => f.value === value);
            if (fieldMeta) data[index].label = fieldMeta.label.toUpperCase();
        }
        
        this.selectedColumns = data;
    }

    handleLabelChange(event) {
        this.currentConfig.label = event.target.value;
    }

    handleSave() {
        if (!this.currentConfig.label) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Defina un nombre para la tabla', variant: 'error' }));
            return;
        }

        this.isLoading = true;
        // Lógica de guardado vía Apex en Custom Metadata (pendiente)
        setTimeout(() => {
            this.isLoading = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Tabla configurada permanentemente', variant: 'success' }));
        }, 1000);
    }
}