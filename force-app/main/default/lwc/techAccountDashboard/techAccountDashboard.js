import { LightningElement, api, wire, track } from 'lwc';
import getDashboardData from '@salesforce/apex/AccountDashboardController.getDashboardData';

export default class TechAccountDashboard extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track hasError = false;

    woOpen = 0;
    woClosed = 0;
    quoteActive = 0;
    quotePending = 0;
    scActive = 0;
    scInactive = 0;
    zonaCount = 0;

    @wire(getDashboardData, { accountId: '$recordId' })
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.woOpen       = data.woOpen       ?? 0;
            this.woClosed     = data.woClosed     ?? 0;
            this.quoteActive  = data.quoteActive  ?? 0;
            this.quotePending = data.quotePending ?? 0;
            this.scActive     = data.scActive     ?? 0;
            this.scInactive   = data.scInactive   ?? 0;
            this.zonaCount    = data.zonaCount    ?? 0;
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            console.error('AccountDashboard error:', error);
        }
    }
}
