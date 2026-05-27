import { LightningElement, api, wire, track } from 'lwc';
import getDashboardData  from '@salesforce/apex/AccountDashboardController.getDashboardData';
import getOpportunities  from '@salesforce/apex/AccountDashboardController.getOpportunities';
import getQuotes         from '@salesforce/apex/AccountDashboardController.getQuotes';
import getContracts      from '@salesforce/apex/AccountDashboardController.getContracts';
import getWorkOrders     from '@salesforce/apex/AccountDashboardController.getWorkOrders';

const COLS = {
    opp: [
        { label: 'Oportunidad', fieldName: 'recordUrl', type: 'url',
          typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, sortable: true },
        { label: 'Etapa',       fieldName: 'StageName',   sortable: true },
        { label: 'Monto',       fieldName: 'Amount',      type: 'currency',
          typeAttributes: { currencyCode: 'MXN', minimumFractionDigits: 0 }, sortable: true },
        { label: 'Cierre',      fieldName: 'CloseDate',   type: 'date-local', sortable: true },
        { label: 'Prob. %',     fieldName: 'Probability', type: 'number',
          cellAttributes: { alignment: 'right' }, sortable: true, initialWidth: 90 },
    ],
    quote: [
        { label: 'Presupuesto',  fieldName: 'recordUrl', type: 'url',
          typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, sortable: true },
        { label: 'Estado',       fieldName: 'Status',         sortable: true },
        { label: 'Total',        fieldName: 'TotalPrice',     type: 'currency',
          typeAttributes: { currencyCode: 'MXN', minimumFractionDigits: 0 }, sortable: true },
        { label: 'Oportunidad',  fieldName: 'OpportunityName', sortable: true },
        { label: 'Vencimiento',  fieldName: 'ExpirationDate', type: 'date-local', sortable: true },
    ],
    contract: [
        { label: 'Contrato', fieldName: 'recordUrl', type: 'url',
          typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, sortable: true },
        { label: 'Estado',   fieldName: 'ApprovalStatus', sortable: true },
        { label: 'Total',    fieldName: 'TotalPrice',     type: 'currency',
          typeAttributes: { currencyCode: 'MXN', minimumFractionDigits: 0 }, sortable: true },
        { label: 'Inicio',   fieldName: 'StartDate',      type: 'date-local', sortable: true },
        { label: 'Fin',      fieldName: 'EndDate',        type: 'date-local', sortable: true },
    ],
    wo: [
        { label: '#',         fieldName: 'recordUrl', type: 'url',
          typeAttributes: { label: { fieldName: 'WorkOrderNumber' }, target: '_blank' },
          sortable: true, initialWidth: 110 },
        { label: 'Asunto',    fieldName: 'Subject',      sortable: true },
        { label: 'Estado',    fieldName: 'Status',       sortable: true },
        { label: 'Prioridad', fieldName: 'Priority',     sortable: true },
        { label: 'Creada',    fieldName: 'CreatedDate',  type: 'date',
          typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }, sortable: true },
    ],
};

const PANEL = {
    opp:      { title: 'Oportunidades',      icon: 'standard:opportunity', fn: getOpportunities },
    quote:    { title: 'Presupuestos',       icon: 'standard:quotes',      fn: getQuotes        },
    contract: { title: 'Contratos',          icon: 'standard:contract',    fn: getContracts     },
    wo:       { title: 'Órdenes de Trabajo', icon: 'standard:work_order',  fn: getWorkOrders    },
};

export default class TechAccountDashboard extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track hasError  = false;

    oppOpen = 0; oppWon = 0;
    woOpen  = 0; woClosed = 0;
    quoteActive = 0; quotePending = 0;
    scActive    = 0; scInactive   = 0;

    @track isPanelOpen    = false;
    @track isPanelLoading = false;
    @track panelType      = null;
    @track panelRecords   = [];
    @track sortedBy;
    @track sortDirection  = 'asc';

    @wire(getDashboardData, { accountId: '$recordId' })
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.oppOpen      = data.oppOpen      ?? 0;
            this.oppWon       = data.oppWon       ?? 0;
            this.woOpen       = data.woOpen       ?? 0;
            this.woClosed     = data.woClosed     ?? 0;
            this.quoteActive  = data.quoteActive  ?? 0;
            this.quotePending = data.quotePending ?? 0;
            this.scActive     = data.scActive     ?? 0;
            this.scInactive   = data.scInactive   ?? 0;
            this.hasError     = false;
        } else if (error) {
            this.hasError = true;
            console.error('AccountDashboard error:', error);
        }
    }

    get panelTitle()   { return this.panelType ? PANEL[this.panelType].title : ''; }
    get panelIcon()    { return this.panelType ? PANEL[this.panelType].icon  : ''; }
    get panelColumns() { return this.panelType ? COLS[this.panelType]        : []; }
    get panelCount()   { return this.panelRecords.length; }
    get hasRecords()   { return this.panelRecords.length > 0; }

    async handleCardClick(evt) {
        const type = evt.currentTarget.dataset.type;
        this.panelType      = type;
        this.isPanelOpen    = true;
        this.isPanelLoading = true;
        this.panelRecords   = [];
        this.sortedBy       = undefined;
        this.sortDirection  = 'asc';
        try {
            const raw = await PANEL[type].fn({ accountId: this.recordId });
            this.panelRecords = raw.map(r => {
                const row = { ...r, recordUrl: `/lightning/r/${r.Id}/view` };
                if (type === 'quote' && r.Opportunity) row.OpportunityName = r.Opportunity.Name;
                return row;
            });
        } catch (e) {
            console.error('Panel fetch error:', e);
        } finally {
            this.isPanelLoading = false;
        }
    }

    closePanel()         { this.isPanelOpen = false; }
    stopPropagation(evt) { evt.stopPropagation(); }

    handleSort(evt) {
        const { fieldName, sortDirection } = evt.detail;
        this.sortedBy     = fieldName;
        this.sortDirection = sortDirection;
        const factor = sortDirection === 'asc' ? 1 : -1;
        this.panelRecords = [...this.panelRecords].sort((a, b) => {
            const av = a[fieldName] ?? '';
            const bv = b[fieldName] ?? '';
            return av > bv ? factor : av < bv ? -factor : 0;
        });
    }
}
