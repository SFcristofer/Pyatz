import { LightningElement, track, wire } from 'lwc';
import getQuotesList from '@salesforce/apex/QuoteTechnicalController.getQuotesList';

export default class QuoteTechnicalList extends LightningElement {
    @track quotes = [];
    @track isLoading = true;

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
                { label: 'Descargar PDF', name: 'pdf', iconName: 'utility:file_spec' }
            ]}
        }
    ];

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

    handleNewQuote() {
        // Disparamos un evento para que el padre cambie al modo editor
        this.dispatchEvent(new CustomEvent('createnew'));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.dispatchEvent(new CustomEvent('editquote', { detail: row.id }));
        }
    }
}