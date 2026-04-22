import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import saveNote from '@salesforce/apex/OperationsController.saveNote';
import getTacticalHistory from '@salesforce/apex/OperationsController.getTacticalHistory';
import updateTaskActivity from '@salesforce/apex/OperationsController.updateTaskActivity';

export default class TechTacticalFollowUp extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity ID
    
    @track activeTab = 'activity';
    @track showFullHistory = false;
    @track isLoadingHistory = false;
    @track historyItems = [];
    
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

    // --- MANEJADORES GESTIÓN TAREAS ---
    handleEditTask(event) {
        const taskId = event.target.dataset.id;
        this.historyItems = this.historyItems.map(item => {
            return { ...item, isEditing: item.id === taskId };
        });
    }

    handleCancelEdit() {
        this.historyItems = this.historyItems.map(item => {
            return { ...item, isEditing: false };
        });
        this.newTaskStatus = '';
        this.newTaskObs = '';
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
                // ORDENAMIENTO CRONOLÓGICO INTEGRAL (Descendente)
                this.historyItems = [...result].sort((a, b) => {
                    return new Date(b.date) - new Date(a.date);
                });
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