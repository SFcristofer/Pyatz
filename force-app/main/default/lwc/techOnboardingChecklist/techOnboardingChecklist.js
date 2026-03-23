import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import checkOnboardingAccess from '@salesforce/apex/QuoteTechnicalController.checkOnboardingAccess';
import updateOnboardingPin from '@salesforce/apex/QuoteTechnicalController.updateOnboardingPin';
import addProjectCollaborator from '@salesforce/apex/QuoteTechnicalController.addProjectCollaborator';
import getEvidenceGallery from '@salesforce/apex/QuoteTechnicalController.getEvidenceGallery';
import renameUploadedFile from '@salesforce/apex/QuoteTechnicalController.renameUploadedFile';
import searchUsers from '@salesforce/apex/QuoteTechnicalController.searchUsers';

export default class TechOnboardingChecklist extends NavigationMixin(LightningElement) {
    @api recordId;

    // --- ESTADO SEGURIDAD ---
    @track isLocked = true;
    @track isOwner = false;
    @track enteredPin = '';
    @track newPin = '';
    @track showPinConfig = false;
    
    // --- ESTADO GESTIÓN DE EVIDENCIAS ---
    @track docSearchTerm = '';
    @track activeDocTag = '';
    @track evidenceList = [];
    @track isLoading = false;
    
    // --- ESTADO COLABORADORES ---
    @track userSearchTerm = '';
    @track userResults = [];
    @track showCollaboratorModal = false;

    _wiredGallery;

    connectedCallback() {
        this.validateAccess();
    }

    validateAccess() {
        checkOnboardingAccess({ opportunityId: this.recordId, providedPin: this.enteredPin })
            .then(result => {
                this.isLocked = !result.hasAccess;
                this.isOwner = result.isOwner;
                if (!this.isLocked) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Acceso Concedido',
                        message: 'Bóveda de Onboarding desbloqueada.',
                        variant: 'success'
                    }));
                } else if (this.enteredPin) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Acceso Denegado',
                        message: 'El PIN ingresado es incorrecto.',
                        variant: 'error'
                    }));
                }
            });
    }

    handlePinChange(event) { this.enteredPin = event.target.value; }
    handleNewPinChange(event) { this.newPin = event.target.value; }

    @wire(getEvidenceGallery, { opportunityId: '$recordId' })
    wiredGallery(result) {
        this._wiredGallery = result;
        if (result.data) {
            this.evidenceList = result.data;
        }
    }

    // --- MANEJADORES DE EVIDENCIA ---
    handleDocSearchChange(event) { this.docSearchTerm = event.target.value; }
    handleDocSearchKeyPress(event) {
        if (event.keyCode === 13) { // ENTER
            this.activeDocTag = this.docSearchTerm.trim().toUpperCase();
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.isLoading = true;
            renameUploadedFile({ 
                documentId: uploadedFiles[0].documentId, 
                docType: this.activeDocTag 
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Documento Registrado',
                    message: `Evidencia guardada como [${this.activeDocTag}]`,
                    variant: 'success'
                }));
                this.activeDocTag = '';
                this.docSearchTerm = '';
                return refreshApex(this._wiredGallery);
            })
            .finally(() => { this.isLoading = false; });
        }
    }

    handlePreviewFile(event) {
        const docId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: docId }
        });
    }

    // --- CONFIGURACIÓN DE SEGURIDAD ---
    handleOpenPinConfig() { this.showPinConfig = true; }
    handleClosePinConfig() { this.showPinConfig = false; }
    handleSavePin() {
        updateOnboardingPin({ opportunityId: this.recordId, newPin: this.newPin })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'PIN Actualizado', variant: 'success' }));
                this.showPinConfig = false;
            });
    }

    // --- GESTIÓN DE COLABORADORES ---
    handleOpenCollaborators() { this.showCollaboratorModal = true; }
    handleCloseCollaborators() { this.showCollaboratorModal = false; this.userResults = []; }
    
    handleUserSearch(event) {
        this.userSearchTerm = event.target.value;
        if (this.userSearchTerm.length > 2) {
            searchUsers({ searchTerm: this.userSearchTerm })
                .then(result => { this.userResults = result; });
        } else {
            this.userResults = [];
        }
    }

    handleAddCollaborator(event) {
        const userId = event.currentTarget.dataset.id;
        addProjectCollaborator({ opportunityId: this.recordId, agentId: userId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Colaborador Añadido', variant: 'success' }));
                this.handleCloseCollaborators();
            });
    }
}