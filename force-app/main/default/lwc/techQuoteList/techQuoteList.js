import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuotesList from '@salesforce/apex/QuoteTechnicalController.getQuotesList';
import getQuoteStats from '@salesforce/apex/QuoteTechnicalController.getQuoteStats';
import cloneQuote from '@salesforce/apex/QuoteTechnicalController.cloneQuote';

export default class TechQuoteList extends LightningElement {
    @track quotes = [];
    @track stats = { Total: 0, Aprobada: 0, Pendiente: 0, Rechazada: 0, Actualizada: 0 };
    @track isLoading = true;

    // CLONING STATE
    @track showCloneModal = false;
    @track isLoadingClone = false;
    @track selectedQuoteId = null;
    @track cloneOptions = {
        copyLineItems: true,
        copySedes: true,
        copyTexts: true
    };

    columns = [
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
        },
        {
            type: 'action',
            typeAttributes: { rowActions: [
                { label: 'Editar', name: 'edit', iconName: 'utility:edit' },
                { label: 'Clonar', name: 'clone', iconName: 'utility:copy' },
                { label: 'Descargar PDF', name: 'pdf', iconName: 'utility:file_spec' }
            ]}
        }
    ];

    @wire(getQuoteStats)
    wiredStats({ error, data }) {
        if (data) {
            console.log('Estadísticas recibidas de Apex:', JSON.stringify(data));
            this.stats = data;
        } else if (error) {
            console.error('Error en getQuoteStats:', error);
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
        // Disparamos un evento para que el padre cambie al modo editor
        this.dispatchEvent(new CustomEvent('createnew'));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.dispatchEvent(new CustomEvent('editquote', { detail: row.id }));
        } else if (actionName === 'clone') {
            this.selectedQuoteId = row.id;
            this.showCloneModal = true;
        }
    }

    // CLONING LOGIC
    handleCloneOptionChange(event) {
        const name = event.target.dataset.name;
        this.cloneOptions = { ...this.cloneOptions, [name]: event.target.checked };
    }

    handleCloseCloneModal() {
        this.showCloneModal = false;
        this.selectedQuoteId = null;
    }

    handleExecuteClone() {
        this.isLoadingClone = true;
        cloneQuote({ quoteId: this.selectedQuoteId, options: this.cloneOptions })
            .then(newQuoteId => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Éxito',
                    message: 'Presupuesto clonado con éxito. Redirigiendo al editor...',
                    variant: 'success'
                }));
                this.isLoadingClone = false;
                this.showCloneModal = false;
                
                // Redirigir al editor con el nuevo ID
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