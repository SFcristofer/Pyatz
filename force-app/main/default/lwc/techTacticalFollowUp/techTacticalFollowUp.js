import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import saveNote from '@salesforce/apex/QuoteTechnicalController.saveNote';
import getTacticalHistory from '@salesforce/apex/QuoteTechnicalController.getTacticalHistory';

export default class TechTacticalFollowUp extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity ID
    
    @track activeTab = 'activity';
    @track showFullHistory = false;
    @track isLoadingHistory = false;
    @track historyItems = [];
    
    // --- ESTADO NOTAS ---
    @track noteTitle = '';
    @track noteContent = '';

    connectedCallback() {
        this.loadHistory();
    }

    // --- MANEJADORES DE ARCHIVOS ---
    handleNoteTitleChange(event) { this.noteTitle = event.detail.value; }
    handleNoteContentChange(event) { this.noteContent = event.detail.value; }
    
    get isNoteEmpty() {
        return !this.noteTitle || !this.noteContent;
    }

    handleSaveNote() {
        if (this.isNoteEmpty) return;
        
        this.isLoadingHistory = true;
        saveNote({ 
            parentId: this.recordId, 
            title: this.noteTitle, 
            content: this.noteContent 
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Nota Guardada',
                message: 'La nota técnica se ha vinculado correctamente a la oportunidad.',
                variant: 'success'
            }));
            this.noteTitle = '';
            this.noteContent = '';
            if (this.showFullHistory) this.loadHistory();
            else this.isLoadingHistory = false;
        })
        .catch(error => {
            console.error('Error saving note:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'No se pudo guardar la nota.',
                variant: 'error'
            }));
            this.isLoadingHistory = false;
        });
    }

    // --- ACCIONES DE ACTIVIDAD ---
    handleLogCall() { this.navigateToGlobalAction('LogACall'); }
    handleNewTask() { this.navigateToGlobalAction('NewTask'); }

    navigateToGlobalAction(actionName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: `Global.${actionName}`
            },
            state: {
                recordId: this.recordId,
                contextId: this.recordId,
                defaultFieldValues: `WhatId=${this.recordId}`
            }
        });
    }

    // --- MANEJADORES DE ARCHIVOS ---
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Éxito',
            message: uploadedFiles.length + ' archivos subidos al expediente.',
            variant: 'success'
        }));
        if (this.showFullHistory) this.loadHistory();
    }

    // --- MANEJADORES DE HISTORIAL ---
    handleToggleHistory(event) {
        this.showFullHistory = event.target.checked;
        if (this.showFullHistory) {
            this.loadHistory();
        }
    }

    loadHistory() {
        this.isLoadingHistory = true;
        getTacticalHistory({ oppId: this.recordId })
            .then(result => {
                this.historyItems = result;
                this.isLoadingHistory = false;
            })
            .catch(error => {
                console.error('Error loading history:', error);
                this.isLoadingHistory = false;
            });
    }

    refreshHistory() {
        this.loadHistory();
    }
}