import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import saveNote from '@salesforce/apex/OperationsController.saveNote';
import getTacticalHistory from '@salesforce/apex/OperationsController.getTacticalHistory';
import updateTaskActivity from '@salesforce/apex/OperationsController.updateTaskActivity';
import getEmailDetails from '@salesforce/apex/OperationsController.getEmailDetails';

export default class TechTacticalFollowUp extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity ID
    
    @track activeAction = null; // 'note', 'email', 'file'
    @track isLoadingHistory = false;
    @track historyItems = [];
    @track groupedHistory = [];

    // --- ESTADO MODAL CORREO ---
    @track showEmailModal = false;
    @track selectedEmail = {};
    @track isLoadingEmail = false;

    // --- MANEJO DE TARJETAS DE ACCIÓN ---
    get noteCardClass() { return this.activeAction === 'note' ? 'action-card active-card' : 'action-card'; }
    get emailCardClass() { return this.activeAction === 'email' ? 'action-card active-card' : 'action-card'; }
    get fileCardClass() { return this.activeAction === 'file' ? 'action-card active-card' : 'action-card'; }

    get isActionNote() { return this.activeAction === 'note'; }
    get isActionEmail() { return this.activeAction === 'email'; }
    get isActionFile() { return this.activeAction === 'file'; }

    handleActionClick(event) {
        const action = event.currentTarget.dataset.action;
        if (this.activeAction === action) {
            this.activeAction = null; // Cierra si se hace clic otra vez
        } else {
            this.activeAction = action;
        }
    }

    handleCancelAction() {
        this.activeAction = null;
    }
    
    // --- ESTADO NOTAS ---
    @track noteTitle = '';
    @track noteContent = '';

    // --- ESTADO GESTIÓN TAREAS ---
    @track editingTaskId = null;
    @track newTaskStatus = '';
    @track newTaskObs = '';

    get statusOptions() {
        return [
            { label: 'No iniciada', value: 'Not Started' },
            { label: 'En curso', value: 'In Progress' },
            { label: 'Completada', value: 'Completed' },
            { label: 'En espera', value: 'Waiting on someone else' },
            { label: 'Aplazada', value: 'Deferred' }
        ];
    }

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
            this.activeAction = null;
            this.loadHistory();
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

    handleEditTask(event) {
        const taskId = event.target.dataset.id;
        this.historyItems = this.historyItems.map(item => {
            return { ...item, isEditing: item.id === taskId };
        });
        this.refreshGrouping();
    }

    handleCancelEdit() {
        this.historyItems = this.historyItems.map(item => {
            return { ...item, isEditing: false };
        });
        this.newTaskStatus = '';
        this.newTaskObs = '';
        this.refreshGrouping();
    }

    handleStatusChange(event) {
        this.newTaskStatus = event.detail.value;
    }

    handleObsTaskChange(event) {
        this.newTaskObs = event.detail.value;
    }

    handleSaveTaskUpdate(event) {
        const taskId = event.target.dataset.id;
        const currentItem = this.historyItems.find(it => it.id === taskId);
        
        // Si no hay cambios, no hacemos nada
        if (!this.newTaskStatus && !this.newTaskObs) {
            this.handleCancelEdit();
            return;
        }

        this.isLoadingHistory = true;
        updateTaskActivity({
            taskId: taskId,
            newStatus: this.newTaskStatus || currentItem.status,
            observation: this.newTaskObs
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Tarea Actualizada',
                message: 'Se ha registrado el avance en la tarea técnica.',
                variant: 'success'
            }));
            this.newTaskStatus = '';
            this.newTaskObs = '';
            this.loadHistory();
        })
        .catch(error => {
            console.error('Error updating task:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'No se pudo actualizar la tarea.',
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
        this.activeAction = null;
        // REFRESCO REACTIVO: Actualizar historial inmediatamente
        this.loadHistory();
    }

    // --- MANEJADORES DE HISTORIAL ---
    loadHistory() {
        this.isLoadingHistory = true;
        getTacticalHistory({ oppId: this.recordId })
            .then(result => {
                this.historyItems = result.map(item => {
                    return {
                        ...item,
                        isPendingTask: item.isTask && item.status !== 'Completed',
                        desc: item.desc || 'Sin descripción adicional.'
                    };
                }).sort((a, b) => {
                    return (b.date || 0) - (a.date || 0);
                });
                this.refreshGrouping();
                this.isLoadingHistory = false;
            })
            .catch(error => {
                console.error('Error loading 360 history:', error);
                this.isLoadingHistory = false;
            });
    }

    refreshGrouping() {
        let groups = [];
        let currentGroup = null;
        this.historyItems.forEach(item => {
            const d = new Date(item.date);
            const options = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
            const dateStr = d.toLocaleDateString('es-MX', options).toUpperCase();
            
            if (!currentGroup || currentGroup.dateLabel !== dateStr) {
                currentGroup = {
                    id: 'group-' + item.id,
                    dateLabel: dateStr,
                    items: []
                };
                groups.push(currentGroup);
            }
            currentGroup.items.push(item);
        });
        this.groupedHistory = groups;
    }

    refreshHistory() {
        this.loadHistory();
    }

    // --- MANEJO DE CORREOS COMPLETOS ---
    handleViewEmail(event) {
        const emailId = event.target.dataset.id;
        this.showEmailModal = true;
        this.isLoadingEmail = true;
        this.selectedEmail = {};
        
        getEmailDetails({ emailId: emailId })
            .then(result => {
                this.selectedEmail = result;
                this.isLoadingEmail = false;
            })
            .catch(error => {
                console.error('Error loading email details:', error);
                this.isLoadingEmail = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'No se pudo cargar el correo.',
                    variant: 'error'
                }));
            });
    }

    closeEmailModal() {
        this.showEmailModal = false;
        this.selectedEmail = {};
    }

    previewAttachment(event) {
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
}