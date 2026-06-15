import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import SUBETAPA_FIELD from '@salesforce/schema/Opportunity.Subetapa__c';
import getEmailTemplatesByFolders from '@salesforce/apex/CommunicationController.getEmailTemplatesByFolders';
import getAvailableAttachments from '@salesforce/apex/CommunicationController.getAvailableAttachments';
import sendEmailWithAttachments from '@salesforce/apex/CommunicationController.sendEmailWithAttachments';
import renderTemplate from '@salesforce/apex/CommunicationController.renderTemplate';
import getEmailEngagementDetails from '@salesforce/apex/CommunicationController.getEmailEngagementDetails';
import getContactsFromLatestQuoteSedes from '@salesforce/apex/CommunicationController.getContactsFromLatestQuoteSedes';
import getInternalTeam from '@salesforce/apex/CommunicationController.getInternalTeam';

export default class TechCommunicationHub extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity ID
    @api folderName; // Nombre de la carpeta de plantillas a filtrar (opcional)

    @track selectedFolder = '';
    @track selectedTemplateId = '';
    @track templates = [];
    @track availableAttachments = { quotes: [], surveys: [], files: [], fichas: [] };
    @track selectedAttachments = [];
    @track sedeContacts = [];
    @track internalContacts = [];
    
    @track toEmail = '';
    @track ccEmail = '';
    @track subject = '';
    @track emailBody = '';
    @track isLoadingTemplates = false;
    @track isLoadingAttachments = false;
    @track isSending = false;
    
    @track currentSubetapa = '';
    @track currentStage = '';

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD, SUBETAPA_FIELD] })
    wiredOpp({ error, data }) {
        if (data) {
            this.currentStage = getFieldValue(data, STAGE_FIELD) || '';
            this.currentSubetapa = getFieldValue(data, SUBETAPA_FIELD) || '';
        } else if (error) {
            console.error('Error fetching opp stage:', error);
        }
    }

    get showInternalTeam() {
        const stageStr = this.currentStage ? this.currentStage.toLowerCase() : '';
        const subStr = this.currentSubetapa ? this.currentSubetapa.toLowerCase() : '';
        // Mostramos el equipo interno solo si la etapa/subetapa incluye enhorabuena o ganada
        return stageStr.includes('enhorabuena') || subStr.includes('enhorabuena') || stageStr.includes('cerrada ganada') || stageStr.includes('closed won');
    }

    // --- ESTADO DE ENGAGEMENT ---
    @track showEngagementModal = false;
    @track isLoadingEngagement = false;
    @track engagementDetails = [];

    connectedCallback() {
        // Si se recibe una carpeta específica, la seleccionamos por defecto
        if (this.folderName) {
            this.selectedFolder = this.folderName;
        }
    }

    handleShowEngagement() {
        this.showEngagementModal = true;
        this.loadEngagementHistory();
    }

    handleCloseEngagement() {
        this.showEngagementModal = false;
    }

    loadEngagementHistory() {
        this.isLoadingEngagement = true;
        getEmailEngagementDetails({ oppId: this.recordId })
            .then(result => {
                // Procesamos para añadir iconos dinámicos
                this.engagementDetails = result.map(email => ({
                    ...email,
                    iconName: email.isOpened ? 'standard:task2' : 'standard:email',
                    iconVariant: email.isOpened ? 'success' : '',
                    recipients: email.recipients.map(r => ({
                        ...r,
                        icon: r.type === 'Principal' ? 'standard:contact' : 'standard:groups'
                    }))
                }));
                this.isLoadingEngagement = false;
            })
            .catch(error => {
                console.error('Error loading engagement:', error);
                this.isLoadingEngagement = false;
            });
    }

    // --- MANEJADORES DE ACTIVIDAD NATIVA ---
    handleLogCall() {
        this.navigateToGlobalAction('LogACall');
    }

    handleNewTask() {
        this.navigateToGlobalAction('NewTask');
    }

    handleNewEvent() {
        this.navigateToGlobalAction('NewEvent');
    }

    navigateToGlobalAction(actionName) {
        // Navegación nativa autorizada por Salesforce para evitar errores de CSP
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

    get folderOptions() {
        if (this.folderName) {
            return [{ label: this.folderName, value: this.folderName }];
        }
        return [
            { label: 'Pyatz - CORREOS A CLIENTES', value: 'Pyatz-CORREOS A CLIENTES' },
            { label: 'Pyatz - CORREOS INTERNOS', value: 'Pyatz-CORREOS INTERNOS' }
        ];
    }

    @wire(getEmailTemplatesByFolders, { folderNames: '$computedFolderNames' })
    wiredTemplates({ error, data }) {
        if (data) {
            this.templates = data;
        } else if (error) {
            console.error('Error loading templates:', error);
        }
    }

    get computedFolderNames() {
        return this.folderName ? [this.folderName] : ['Pyatz-CORREOS A CLIENTES', 'Pyatz-CORREOS INTERNOS'];
    }

    @wire(getAvailableAttachments, { oppId: '$recordId' })
    wiredAttachments({ error, data }) {
        this.isLoadingAttachments = true;
        if (data) {
            this.availableAttachments = data;
            this.isLoadingAttachments = false;
        } else if (error) {
            console.error('Error loading attachments:', error);
            this.isLoadingAttachments = false;
        }
    }

    @wire(getContactsFromLatestQuoteSedes, { oppId: '$recordId' })
    wiredSedeContacts({ error, data }) {
        if (data) {
            this.sedeContacts = data;
        } else if (error) {
            console.error('Error loading sede contacts:', error);
        }
    }

    @wire(getInternalTeam, { oppId: '$recordId' })
    wiredInternalTeam({ error, data }) {
        if (data) {
            this.internalContacts = data;
        } else if (error) {
            console.error('Error loading internal team:', error);
        }
    }

    handleQuickAddContact(event) {
        const email = event.target.dataset.email;
        const checked = event.target.checked;
        let currentEmails = this.toEmail ? this.toEmail.split(',').map(e => e.trim()).filter(e => e) : [];
        if (checked) {
            if (!currentEmails.includes(email)) currentEmails.push(email);
        } else {
            currentEmails = currentEmails.filter(e => e !== email);
        }
        this.toEmail = currentEmails.join(', ');
    }

    get filteredTemplates() {
        if (!this.selectedFolder) return [];
        return this.templates
            .filter(t => t.folder === this.selectedFolder)
            .map(t => ({ label: t.name, value: t.id }));
    }

    get isTemplateDisabled() {
        return !this.selectedFolder;
    }

    get isSendDisabled() {
        return !this.toEmail || !this.subject || this.isSending;
    }

    handleFolderChange(event) {
        this.selectedFolder = event.detail.value;
        this.selectedTemplateId = '';
    }

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
        this.loadTemplateContent();
    }

    async loadTemplateContent() {
        if (!this.selectedTemplateId) return;
        
        try {
            // Buscamos el contexto de ID (Preferimos una Quote para que las variables de la plantilla se llenen)
            let contextId = this.recordId;
            const selectedQuotes = this.selectedAttachments.filter(a => a.type === 'Quote');
            
            if (selectedQuotes.length > 0) {
                contextId = selectedQuotes[0].id;
            } else if (this.availableAttachments.quotes && this.availableAttachments.quotes.length > 0) {
                // Si no hay seleccionada, usamos la primera disponible por defecto para el renderizado
                contextId = this.availableAttachments.quotes[0].id;
            }

            const content = await renderTemplate({ 
                templateId: this.selectedTemplateId, 
                quoteId: contextId 
            });
            this.emailBody = content;
            this._currentDraftBody = ''; // Resetear el borrador para que tome la nueva plantilla
            
            // Actualizar asunto automáticamente si la plantilla lo tiene o usar el nombre de la plantilla
            const tpl = this.templates.find(t => t.id === this.selectedTemplateId);
            if (tpl) this.subject = tpl.name;
            
        } catch (error) {
            console.error('Error rendering template:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error al cargar plantilla',
                message: 'No se pudo procesar la plantilla. Verifique que la oportunidad tenga al menos un presupuesto.',
                variant: 'warning'
            }));
        }
    }

    handleAttachmentToggle(event) {
        const attId = event.target.dataset.id;
        const type = event.target.dataset.type;
        const name = event.target.label;
        const checked = event.target.checked;

        if (checked) {
            this.selectedAttachments.push({ id: attId, type: type, name: name });
        } else {
            this.selectedAttachments = this.selectedAttachments.filter(a => a.id !== attId || a.type !== type);
        }
    }

    handleEmailChange(event) { this.toEmail = event.detail.value; }
    handleCcChange(event) { this.ccEmail = event.detail.value; }
    handleSubjectChange(event) { this.subject = event.detail.value; }
    // Almacena el cuerpo sin causar un re-render continuo
    _currentDraftBody = '';

    handleBodyChange(event) { 
        this._currentDraftBody = event.detail.value; 
    }

    handleSendEmail() {
        this.isSending = true;
        
        // Usar el borrador actual si existe, si no usar el original cargado
        const finalBody = this._currentDraftBody || this.emailBody;

        sendEmailWithAttachments({
            oppId: this.recordId,
            toEmail: this.toEmail,
            ccEmail: this.ccEmail,
            subject: this.subject,
            body: finalBody,
            selectedAttachments: this.selectedAttachments
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Correo enviado correctamente y registrado en la actividad.',
                variant: 'success'
            }));
            this.isSending = false;
            
            // LIMPIEZA DE FORMULARIO
            this.clearForm();

            // NOTIFICAR AVANCE DE FASE
            this.dispatchEvent(new CustomEvent('fasesuccess', {
                detail: { phase: 'Negociación' }
            }));
        })
        .catch(error => {
            this.isSending = false;
            console.error('Error enviando:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        });
    }

    clearForm() {
        this.toEmail = '';
        this.ccEmail = '';
        this.subject = '';
        this.emailBody = '';
        this.selectedAttachments = [];
        this.selectedTemplateId = '';
        this.selectedFolder = '';
        
        // Desmarcar checkboxes de adjuntos en el DOM
        const checkboxes = this.template.querySelectorAll('lightning-input[data-type]');
        checkboxes.forEach(cb => {
            cb.checked = false;
        });

        // Desmarcar contactos
        const contactChecks = this.template.querySelectorAll('lightning-input[data-email]');
        contactChecks.forEach(cb => {
            cb.checked = false;
        });
    }
}