import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentStates from '@salesforce/apex/QuoteTechnicalController.getDocumentStates';
import renameUploadedFile from '@salesforce/apex/QuoteTechnicalController.renameUploadedFile';
import { refreshApex } from '@salesforce/apex';

export default class TechDocumentManager extends LightningElement {
    @api recordId;
    @track isLoading = false;
    wiredDocumentResult;

    options = [
        { label: 'Si', value: 'Si' },
        { label: 'No', value: 'No' }
    ];

    @track documents = [
        { key: 'INE', label: 'INE (Identificación)', value: 'No', column: 'left' },
        { key: 'CURP', label: 'CURP Certificada', value: 'No', column: 'left' },
        { key: 'CSF', label: 'Const. Situación Fiscal', value: 'No', column: 'left' },
        { key: 'IMSS', label: 'Alta IMSS / Registro Patronal', value: 'No', column: 'left' },
        { key: 'VIGENCIA', label: 'Vigencia de Derechos', value: 'No', column: 'left' },
        { key: 'DC3_ALTURAS', label: 'DC-3 Alturas (NOM-009)', value: 'No', column: 'right' },
        { key: 'DC3_CONFINADOS', label: 'DC-3 Espacios Confinados', value: 'No', column: 'right' },
        { key: 'DC3_QUIMICOS', label: 'DC-3 Manejo de Químicos', value: 'No', column: 'right' },
        { key: 'DC3_EXT1', label: 'DC-3 Especialidad A', value: 'No', column: 'right' },
        { key: 'DC3_EXT2', label: 'DC-3 Especialidad B', value: 'No', column: 'right' }
    ];

    @wire(getDocumentStates, { opportunityId: '$recordId' })
    wiredStates(result) {
        this.wiredDocumentResult = result;
        if (result.data) {
            this.updateLocalStates(result.data);
        }
    }

    updateLocalStates(data) {
        this.documents = this.documents.map(doc => {
            const val = data[doc.key] || 'No';
            return { 
                ...doc, 
                value: val,
                containerClass: val === 'Si' ? 'doc-card completed' : 'doc-card pending',
                statusIcon: val === 'Si' ? 'utility:success' : 'utility:clock',
                statusVariant: val === 'Si' ? 'success' : 'default',
                statusText: val === 'Si' ? 'Documento cargado correctamente' : 'Pendiente de adjuntar'
            };
        });
    }

    get completedCount() { return this.documents.filter(d => d.value === 'Si').length; }
    get totalCount() { return this.documents.length; }
    get completedPercentage() { return Math.round((this.completedCount / this.totalCount) * 100); }

    get leftColumn() { return this.documents.filter(d => d.column === 'left'); }
    get rightColumn() { return this.documents.filter(d => d.column === 'right'); }

    handleUploadFinished(event) {
        // Usamos currentTarget para asegurar que leemos el data-key del lightning-file-upload
        const docKey = event.currentTarget.dataset.key;
        const uploadedFiles = event.detail.files;
        
        console.log('Upload finished for:', docKey, 'Files:', uploadedFiles);

        if (uploadedFiles.length > 0) {
            const documentId = uploadedFiles[0].documentId;
            this.isLoading = true;

            renameUploadedFile({ documentId: documentId, docType: docKey })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Éxito',
                        message: `Documento ${docKey} cargado y vinculado`,
                        variant: 'success'
                    }));
                    // Forzamos actualización de los checks
                    return refreshApex(this.wiredDocumentResult);
                })
                .catch(error => {
                    console.error('Error al renombrar archivo:', error);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error en proceso',
                        message: 'El archivo se subió pero no pudo ser etiquetado.',
                        variant: 'warning'
                    }));
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }
}