import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getQuotesList from '@salesforce/apex/QuoteTechnicalController.getQuotesList';
import getQuoteStats from '@salesforce/apex/QuoteTechnicalController.getQuoteStats';
import cloneQuote from '@salesforce/apex/QuoteTechnicalController.cloneQuote';
import searchSedes from '@salesforce/apex/QuoteTechnicalController.searchSedes';
import searchProspectos from '@salesforce/apex/QuoteTechnicalController.searchProspectos';

export default class TechQuoteList extends NavigationMixin(LightningElement) {
    @api opportunityId;
    @api viewMode = 'list'; // 'list' o 'send'
    @track quotes = [];
    @track stats = { Total: 0, Aprobada: 0, Pendiente: 0, Rechazada: 0, Actualizada: 0 };
    @track isLoading = true;

    // CLONING STATE (IGEOAPP STYLE)
    @track showCloneModal = false;
    @track isLoadingClone = false;
    @track selectedQuoteId = null;
    @track cloneOptions = { copyLineItems: true, copyTexts: true };
    
    @track destinyValue = 'original'; // 'original' o 'new'
    @track targetId = null;
    @track searchResults = [];
    @track selectedSearchName = '';

    destinyOptions = [
        { label: 'Sede Existente', value: 'original' },
        { label: 'Cliente Potencial', value: 'new' }
    ];

    get columns() {
        let cols = [
            { label: 'Folio', fieldName: 'folio', type: 'text', initialWidth: 100 },
            { label: 'Asunto', fieldName: 'asunto', type: 'text' },
            { label: 'Cliente', fieldName: 'cliente', type: 'text' },
            { label: 'Sede', fieldName: 'sede', type: 'text' },
            { label: 'Generado por', fieldName: 'generadoPor', type: 'text' },
            { label: 'Fecha', fieldName: 'fecha', type: 'date' },
            { 
                label: 'Monto', 
                fieldName: 'monto', 
                type: 'currency',
                cellAttributes: { alignment: 'left' }
            },
            { 
                label: 'Estado', 
                fieldName: 'estado', 
                type: 'text',
                cellAttributes: { 
                    class: { fieldName: 'estadoClass' } 
                }
            }
        ];

        if (this.viewMode === 'send') {
            cols.push({
                type: 'action',
                typeAttributes: { rowActions: [
                    { label: 'Enviar por Correo (SF)', name: 'send_email', iconName: 'utility:send' },
                    { label: 'Ver PDF', name: 'pdf', iconName: 'utility:file_spec' }
                ]}
            });
        } else {
            cols.push({
                type: 'action',
                typeAttributes: { rowActions: [
                    { label: 'Editar', name: 'edit', iconName: 'utility:edit' },
                    { label: 'Configurar Contrato', name: 'contract', iconName: 'standard:contract' },
                    { label: 'Clonar', name: 'clone', iconName: 'utility:copy' },
                    { label: 'Descargar PDF Presupuesto', name: 'pdf', iconName: 'utility:file_spec' }
                ]}
            });
        }
        return cols;
    }

    @wire(getQuoteStats)
    wiredStats({ error, data }) {
        if (data) {
            this.stats = data;
        } else if (error) {
            console.error('Error stats:', error);
        }
    }

    @wire(getQuotesList)
    wiredQuotes({ error, data }) {
        this.isLoading = true;
        if (data) {
            this.quotes = data;
            this.isLoading = false;
        } else if (error) {
            console.error('Error cargando cotizaciones:', error);
            this.isLoading = false;
        }
    }

    get totalCount() { return this.stats.Total; }
    get approvedCount() { return this.stats.Aprobada; }
    get pendingCount() { return this.stats.Pendiente; }
    get rejectedCount() { return this.stats.Rechazada; }
    get updatedCount() { return this.stats.Actualizada; }

    handleNewQuote() {
        this.dispatchEvent(new CustomEvent('createnew'));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.dispatchEvent(new CustomEvent('editquote', { detail: row.id }));
        } else if (actionName === 'contract') {
            this.dispatchEvent(new CustomEvent('viewcontract', { detail: row.id }));
        } else if (actionName === 'clone') {
            this.selectedQuoteId = row.id;
            this.showCloneModal = true;
        } else if (actionName === 'send_email') {
            this.openEmailComposer(row.id);
        }
    }

    openEmailComposer(quoteId) {
        // Navegación nativa autorizada para evitar errores de CSP
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Global.SendEmail'
            },
            state: {
                recordId: this.opportunityId,
                contextId: quoteId,
                defaultFieldValues: `WhatId=${this.opportunityId}`
            }
        });
    }

    // CLONING LOGIC (IGEOAPP STYLE)
    get isProspecto() { return this.destinyValue === 'new'; }

    handleDestinyChange(event) {
        this.destinyValue = event.target.value;
        this.targetId = null;
        this.selectedSearchName = '';
        this.searchResults = [];
    }

    handleSedeSearch(event) {
        const searchTerm = event.target.value;
        this.selectedSearchName = searchTerm;
        if (searchTerm.length >= 3) {
            searchSedes({ searchTerm: searchTerm })
                .then(result => { this.searchResults = result; })
                .catch(error => console.error('Error sedes:', error));
        } else { this.searchResults = []; }
    }

    handleProspectoSearch(event) {
        const searchTerm = event.target.value;
        this.selectedSearchName = searchTerm;
        if (searchTerm.length >= 3) {
            searchProspectos({ searchTerm: searchTerm })
                .then(result => { this.searchResults = result; })
                .catch(error => console.error('Error prospectos:', error));
        } else { this.searchResults = []; }
    }

    handleResultSelect(event) {
        this.targetId = event.currentTarget.dataset.id;
        this.selectedSearchName = event.currentTarget.dataset.name;
        this.searchResults = [];
    }

    handleCloneOptionChange(event) {
        const name = event.target.dataset.name;
        this.cloneOptions = { ...this.cloneOptions, [name]: event.target.checked };
    }

    handleCloseCloneModal() {
        this.showCloneModal = false;
        this.selectedQuoteId = null;
        this.targetId = null;
        this.selectedSearchName = '';
        this.destinyValue = 'original';
    }

    handleExecuteClone() {
        if (!this.targetId && !this.selectedSearchName.includes('CLON')) {
            // Permitimos clonar sin destino si no se cambió nada (clonación rápida en el mismo lugar)
        }

        this.isLoadingClone = true;
        const sedeId = this.isProspecto ? null : this.targetId;
        const prospectoId = this.isProspecto ? this.targetId : null;

        cloneQuote({ 
            quoteId: this.selectedQuoteId, 
            options: this.cloneOptions,
            targetSedeId: sedeId,
            targetProspectoId: prospectoId
        })
            .then(newQuoteId => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Presupuesto clonado con éxito. Redirigiendo al editor...',
                    variant: 'success'
                }));
                this.isLoadingClone = false;
                this.showCloneModal = false;
                this.dispatchEvent(new CustomEvent('editquote', { detail: newQuoteId }));
            })
            .catch(error => {
                this.isLoadingClone = false;
                console.error('Error clonando:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error al clonar',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
}