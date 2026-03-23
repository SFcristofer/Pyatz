import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentStates from '@salesforce/apex/QuoteTechnicalController.getDocumentStates';
import renameUploadedFile from '@salesforce/apex/QuoteTechnicalController.renameUploadedFile';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

export default class TechPyatzDocumentManager extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isLoading = false;
    wiredDocumentResult;

    @track documents = [
        { key: 'PY_RFC', label: 'RFC Pyatz', value: null },
        { key: 'PY_ACTA', label: 'Acta Constitutiva', value: null },
        { key: 'PY_REPSE', label: 'Registro REPSE', value: null },
        { key: 'PY_OPINION', label: 'Opinión Cumplimiento SAT', value: null },
        { key: 'PY_CSF', label: 'Constancia Fiscal Pyatz', value: null }
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
                statusLabel: isDone ? 'DISPONIBLE PARA ENVÍO' : 'FALTA EN REPOSITORIO',
                containerClass: isDone ? 'doc-row completed pyatz' : 'doc-row pending pyatz-pending'
            };
        });
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
                        title: 'Repositorio Actualizado',
                        message: `Se ha guardado ${docKey} en el expediente maestro corporativo`,
                        variant: 'success'
                    }));
                    return refreshApex(this.wiredDocumentResult);
                })
                .catch(error => {
                    console.error('Error:', error);
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handlePreview(event) {
        const docId = event.target.dataset.id;
        if (docId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: docId }
            });
        }
    }

    handleSendAll() {
        this.isLoading = true;
        // Simulación de envío
        setTimeout(() => {
            this.isLoading = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Expediente Enviado',
                message: 'Se ha enviado la documentación de Pyatz al contacto principal del cliente.',
                variant: 'success'
            }));
        }, 1500);
    }
}