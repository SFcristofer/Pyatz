import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getDocumentStates from '@salesforce/apex/QuoteTechnicalController.getDocumentStates';
import renameUploadedFile from '@salesforce/apex/QuoteTechnicalController.renameUploadedFile';
import deleteDocument from '@salesforce/apex/QuoteTechnicalController.deleteDocument';
import { refreshApex } from '@salesforce/apex';

export default class TechDocumentManager extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isLoading = false;
    wiredDocumentResult;

    @track documents = [
        { key: 'INE', label: 'INE (Identificación)', value: null, column: 'left' },
        { key: 'CURP', label: 'CURP Certificada', value: null, column: 'left' },
        { key: 'CSF', label: 'Const. Situación Fiscal', value: null, column: 'left' },
        { key: 'IMSS', label: 'Alta IMSS / Registro Patronal', value: null, column: 'left' },
        { key: 'VIGENCIA', label: 'Vigencia de Derechos', value: null, column: 'left' },
        { key: 'DC3_ALTURAS', label: 'DC-3 Alturas (NOM-009)', value: null, column: 'right' },
        { key: 'DC3_CONFINADOS', label: 'DC-3 Espacios Confinados', value: null, column: 'right' },
        { key: 'DC3_QUIMICOS', label: 'DC-3 Manejo de Químicos', value: null, column: 'right' },
        { key: 'DC3_EXT1', label: 'DC-3 Especialidad A', value: null, column: 'right' },
        { key: 'DC3_EXT2', label: 'DC-3 Especialidad B', value: null, column: 'right' }
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
            const docId = data[doc.key];
            const isDone = docId != null;
            return { 
                ...doc, 
                value: docId,
                isCompleted: isDone,
                containerClass: isDone ? 'doc-row completed' : 'doc-row pending',
                statusIcon: isDone ? 'action:approval' : 'action:priority',
                statusVariant: isDone ? 'success' : 'inverse',
                statusLabel: isDone ? 'CARGADO' : 'PENDIENTE',
                badgeClass: isDone ? 'custom-badge success' : 'custom-badge pending'
            };
        });
    }

    get completedCount() { return this.documents.filter(d => d.isCompleted).length; }
    get totalCount() { return this.documents.length; }
    get completedPercentage() { return Math.round((this.completedCount / this.totalCount) * 100); }

    get leftColumn() { return this.documents.filter(d => d.column === 'left'); }
    get rightColumn() { return this.documents.filter(d => d.column === 'right'); }

    handlePreview(event) {
        const docId = event.target.dataset.id;
        if (docId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: docId
                }
            });
        }
    }

    async handleDelete(event) {
        const docId = event.target.dataset.id;
        const docLabel = event.target.dataset.label;

        const result = await LightningConfirm.open({
            message: `¿Estás seguro de que deseas eliminar el documento "${docLabel}"? Esta acción no se puede deshacer.`,
            variant: 'headerless',
            label: 'Confirmar eliminación',
            theme: 'error'
        });

        if (result && docId) {
            this.isLoading = true;
            deleteDocument({ documentId: docId })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Eliminado',
                        message: 'El documento ha sido eliminado correctamente.',
                        variant: 'success'
                    }));
                    return refreshApex(this.wiredDocumentResult);
                })
                .catch(error => {
                    console.error('Error al eliminar:', error);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'No se pudo eliminar el archivo.',
                        variant: 'error'
                    }));
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleUploadFinished(event) {
        const docKey = event.currentTarget.dataset.key;
        const uploadedFiles = event.detail.files;
        
        if (uploadedFiles.length > 0) {
            const documentId = uploadedFiles[0].documentId;
            this.isLoading = true;

            renameUploadedFile({ documentId: documentId, docType: docKey })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Documento Recibido',
                        message: `Se ha registrado ${docKey} exitosamente`,
                        variant: 'success'
                    }));
                    return refreshApex(this.wiredDocumentResult);
                })
                .catch(error => {
                    console.error('Error:', error);
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: 'No se pudo procesar el archivo',
                        variant: 'error'
                    }));
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }
}