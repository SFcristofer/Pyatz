import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getChecklist from '@salesforce/apex/OperationsController.getChecklist';
import renameUploadedFile from '@salesforce/apex/OperationsController.renameUploadedFile';

export default class TechFileChecklist extends LightningElement {
    @api recordId;
    @api category; // 'Alta Cliente' o 'Alta Pyatz'
    @track items = [];
    @track isLoading = false;
    @track activeTag = '';

    connectedCallback() {
        this.loadChecklist();
    }

    async loadChecklist() {
        this.isLoading = true;
        try {
            const data = await getChecklist({ 
                opportunityId: this.recordId, 
                category: this.category 
            });
            this.items = data.map(item => ({
                ...item,
                statusClass: item.isLoaded ? 'status-loaded' : 'status-pending',
                iconName: item.isLoaded ? 'utility:check' : 'utility:clock',
                showUpload: !item.isLoaded || this.category === 'Alta Pyatz' // Permitir actualizar Pyatz
            }));
        } catch (error) {
            console.error('Error loading checklist:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadClick(event) {
        this.activeTag = event.target.dataset.tag;
        const label = event.target.dataset.label;

        const result = await LightningConfirm.open({
            message: `Está a punto de cargar el documento: "${label}". Por políticas de confidencialidad, una vez subido no podrá previsualizarlo ni eliminarlo. ¿Desea continuar con la carga?`,
            variant: 'headerless',
            label: 'Advertencia de Seguridad',
            theme: 'warning'
        });

        if (result) {
            // Activar el input de archivo oculto o mostrar el componente de carga
            const uploader = this.template.querySelector(`[data-id="${this.activeTag}"]`);
            if (uploader) {
                // En LWC nativo no podemos disparar el click del file upload por seguridad
                // pero podemos mostrar un modal o un área de carga
                this.items = this.items.map(item => ({
                    ...item,
                    isUploading: item.tag === this.activeTag
                }));
            }
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const tag = event.target.dataset.tag;

        if (uploadedFiles.length > 0) {
            this.isLoading = true;
            renameUploadedFile({ 
                documentId: uploadedFiles[0].documentId, 
                docType: tag 
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Archivo cargado y protegido correctamente.',
                    variant: 'success'
                }));
                this.loadChecklist();
            })
            .catch(error => {
                console.error('Error renaming:', error);
                this.isLoading = false;
            });
        }
    }
}