import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getDocumentStates from '@salesforce/apex/CommunicationController.getDocumentStates';
import renameUploadedFile from '@salesforce/apex/CommunicationController.renameUploadedFile';
import deleteDocument from '@salesforce/apex/CommunicationController.deleteDocument';
import { refreshApex } from '@salesforce/apex';

export default class TechDocumentManager extends NavigationMixin(LightningElement) {
    @api recordId;
    @track isLoading = false;
    @track newTagInput = '';
    wiredDocumentResult;

    @track documents = []; // LISTA DINÁMICA

    @wire(getDocumentStates, { opportunityId: '$recordId' })
    wiredStates(result) {
        this.wiredDocumentResult = result;
        if (result.data) {
            this.updateLocalStates(result.data);
        } else if (result.error) {
            console.error('Error recuperando expediente:', result.error);
        }
    }

    handleTagInputChange(event) {
        this.newTagInput = event.target.value.toUpperCase();
    }

    handleAddTag() {
        if (!this.newTagInput) return;
        
        // Verificar si ya existe en la lista
        const exists = this.documents.find(d => d.key === this.newTagInput);
        if (exists) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Aviso', message: 'Esta etiqueta ya está en la lista', variant: 'info' }));
            return;
        }

        // Añadir card vacía
        const newDoc = {
            key: this.newTagInput,
            label: this.newTagInput,
            value: null,
            isCompleted: false,
            isEnterprise: this.checkIsEnterprise(this.newTagInput),
            containerClass: 'doc-row pending dynamic-add',
            statusIcon: 'action:priority',
            statusVariant: 'inverse',
            statusLabel: 'ESPERANDO ARCHIVO',
            badgeClass: 'custom-badge pending'
        };

        this.documents = [newDoc, ...this.documents];
        this.newTagInput = '';
    }

    checkIsEnterprise(tag) {
        return ['INE', 'CURP', 'CSF', 'IMSS', 'VIGENCIA', 'ACTA', 'RFC'].includes(tag);
    }

    updateLocalStates(data) {
        // 1. Transformar lo que viene de Salesforce en nuestro formato de cards
        const existingDocs = Object.keys(data).map(tag => {
            const isEnterpriseDoc = this.checkIsEnterprise(tag);
            const docId = data[tag];
            return {
                key: tag,
                label: tag,
                value: docId,
                isCompleted: true,
                isEnterprise: isEnterpriseDoc,
                containerClass: isEnterpriseDoc ? 'doc-row completed enterprise' : 'doc-row completed',
                statusIcon: isEnterpriseDoc ? 'standard:account' : 'action:approval',
                statusVariant: 'success',
                statusLabel: isEnterpriseDoc ? 'PERFIL CLIENTE' : 'EXPEDIENTE OK',
                badgeClass: isEnterpriseDoc ? 'custom-badge enterprise' : 'custom-badge success'
            };
        });

        // 2. Mezclar con lo que el usuario haya añadido manualmente pero que aún no tiene archivo
        const pendingDocs = this.documents.filter(d => !d.isCompleted && !data[d.key]);
        
        // 3. Ordenar: Primero los completados, luego los pendientes
        this.documents = [...existingDocs, ...pendingDocs];
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