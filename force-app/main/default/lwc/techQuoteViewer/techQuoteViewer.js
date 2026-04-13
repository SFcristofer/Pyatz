import { LightningElement, api } from 'lwc';

export default class TechQuoteViewer extends LightningElement {
    @api recordId;

    get pdfUrl() {
        if (!this.recordId) return '';
        // Construir URL a la página Visualforce del PDF
        return `/apex/QuoteTechnicalPDF?id=${this.recordId}`;
    }
}