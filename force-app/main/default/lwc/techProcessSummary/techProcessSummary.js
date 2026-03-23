import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getProcessHistory from '@salesforce/apex/QuoteTechnicalController.getProcessHistory';
import getOpenOpportunities from '@salesforce/apex/QuoteTechnicalController.getOpenOpportunities';
import getEvidenceGallery from '@salesforce/apex/QuoteTechnicalController.getEvidenceGallery';
import renameUploadedFile from '@salesforce/apex/QuoteTechnicalController.renameUploadedFile';

export default class TechProcessSummary extends NavigationMixin(LightningElement) {
    @api recordId; // Oportunidad base
    @track displayRecordId; // ID que estamos visualizando actualmente
    @track openOppOptions = []; // Opciones para el dropdown de pipeline activo
    @track isExpanded = true; // Variable de control para visibilidad de la tabla
    
    // --- ESTADO GESTIÓN DE EVIDENCIAS ---
    @track docSearchTerm = '';
    @track activeDocTag = '';
    @track evidenceList = [];
    @track isLoadingEvidence = false;

    processData = [];
    _wiredResult;
    _wiredGallery;

    connectedCallback() {
        this.displayRecordId = this.recordId;
    }

    /**
     * Navega a la previsualización nativa de Salesforce
     */
    handlePreviewFile(event) {
        const docId = event.currentTarget.dataset.id;
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

    /**
     * Alterna la visibilidad de la tabla de resumen
     */
    handleToggleVisibility() {
        this.isExpanded = !this.isExpanded;
    }

    get toggleIcon() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get toggleTooltip() {
        return this.isExpanded ? 'Ocultar Resumen' : 'Mostrar Resumen';
    }

    @wire(getOpenOpportunities)
    wiredOpenOpps({ error, data }) {
        if (data) {
            this.openOppOptions = data;
        } else if (error) {
            console.error('Error loading open opportunities:', error);
        }
    }

    @wire(getProcessHistory, { opportunityId: '$displayRecordId' })
    wiredHistory(result) {
        this._wiredResult = result;
        if (result.data) {
            this.processData = result.data;
        } else if (result.error) {
            console.error('Error loading history:', result.error);
        }
    }

    @wire(getEvidenceGallery, { opportunityId: '$displayRecordId' })
    wiredGallery(result) {
        this._wiredGallery = result;
        if (result.data) {
            this.evidenceList = result.data;
        } else if (result.error) {
            console.error('Error loading gallery:', result.error);
        }
    }

    // --- MANEJADORES DE EVIDENCIA ---
    handleDocSearchChange(event) {
        this.docSearchTerm = event.target.value;
    }

    handleDocSearchKeyPress(event) {
        if (event.keyCode === 13) { // ENTER
            if (this.docSearchTerm.trim()) {
                this.activeDocTag = this.docSearchTerm.trim().toUpperCase();
            } else {
                this.activeDocTag = '';
            }
        }
    }

    get isUploadVisible() {
        return this.activeDocTag !== '';
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.isLoadingEvidence = true;
            renameUploadedFile({ 
                documentId: uploadedFiles[0].documentId, 
                docType: this.activeDocTag 
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Evidencia Cargada',
                    message: `Se ha registrado el documento como [${this.activeDocTag}]`,
                    variant: 'success'
                }));
                this.activeDocTag = '';
                this.docSearchTerm = '';
                return refreshApex(this._wiredGallery);
            })
            .then(() => {
                return refreshApex(this._wiredResult);
            })
            .catch(error => {
                console.error('Error renaming:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'No se pudo etiquetar el archivo correctamente.',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoadingEvidence = false;
            });
        }
    }

    handleRecordChange(event) {
        // Capturamos el ID de forma segura según el componente que disparó el evento
        const selectedId = event.detail.recordId || event.detail.value;
        
        if (selectedId && selectedId !== this.displayRecordId) {
            this.displayRecordId = selectedId;
            // Forzamos un refresco manual por si el wire no detecta el cambio de inmediato
            this.refreshData();
        } else if (!selectedId) {
            this.resetToDefault();
        }
    }

    resetToDefault() {
        this.displayRecordId = this.recordId;
    }

    get isViewingOther() {
        return this.displayRecordId !== this.recordId;
    }

    /**
     * Método público para que el padre pida refrescar los datos.
     */
    @api
    async refreshData() {
        await refreshApex(this._wiredResult);
    }

    get processedData() {
        const emojiMap = {
            'realizado': '✅', 'aceptado': '✅', 'confirmado': '✅', 'enhorabuena': '🎉',
            'en proceso': '⏳', 'pendiente': '🕒', 'ajuste': '⚙️',
            'rechazado': '❌', 'falta información': '⚠️', 'mal': '🚫'
        };

        return this.processData.map(item => {
            let statusClass = 'slds-badge ';
            const s = (item.Estado__c || '').toLowerCase();
            let emoji = '⚪';

            // Determinar color y emoji
            if (['realizado', 'aceptado', 'confirmado', 'enhorabuena'].some(v => s.includes(v))) {
                statusClass += 'slds-theme_success';
                emoji = emojiMap[s] || '✅';
            } else if (['en proceso', 'pendiente', 'ajuste'].some(v => s.includes(v))) {
                statusClass += 'slds-theme_warning';
                emoji = emojiMap[s] || '⏳';
            } else if (['rechazado', 'falta información', 'mal'].some(v => s.includes(v))) {
                statusClass += 'slds-theme_error';
                emoji = emojiMap[s] || '❌';
            } else {
                statusClass += 'slds-theme_lightest';
            }

            return {
                stage: item.Etapa__c.toUpperCase(),
                subStage: item.Subetapa__c,
                status: `${emoji} ${item.Estado__c}`,
                statusClass: statusClass + ' slds-p-horizontal_small slds-m-vertical_xx-small',
                aging: this.calculateAging(item.LastModifiedDate),
                agingClass: this.getAgingClass(item.LastModifiedDate),
                lastUpdate: new Date(item.LastModifiedDate).toLocaleDateString()
            };
        });
    }

    calculateAging(lastModDate) {
        const lastMod = new Date(lastModDate);
        const today = new Date();
        const diffTime = Math.abs(today - lastMod);
        const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 0) return 'Hoy';
        return `${diffDays} día${diffDays > 1 ? 's' : ''}`;
    }

    getAgingClass(lastModDate) {
        const lastMod = new Date(lastModDate);
        const today = new Date();
        const diffDays = Math.floor(Math.abs(today - lastMod) / (1000 * 60 * 60 * 24));
        
        if (diffDays > 5) return 'slds-text-color_error slds-text-title_bold'; // Alerta: más de 5 días
        if (diffDays > 2) return 'slds-text-color_warning slds-text-title_bold'; // Precaución: más de 2 días
        return 'slds-text-color_weak';
    }
}