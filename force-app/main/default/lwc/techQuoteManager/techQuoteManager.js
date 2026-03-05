import { LightningElement, track } from 'lwc';

export default class TechQuoteManager extends LightningElement {
    @track viewMode = 'list'; // 'list', 'edit', 'contract' o 'workorder'
    @track selectedRecordId = null;

    get isListView() {
        return this.viewMode === 'list';
    }

    get isEditView() {
        return this.viewMode === 'edit';
    }

    get isContractView() {
        return this.viewMode === 'contract';
    }

    get isWorkOrderView() {
        return this.viewMode === 'workorder';
    }

    handleCreateNew() {
        this.selectedRecordId = null;
        this.viewMode = 'edit';
    }

    handleEditQuote(event) {
        this.selectedRecordId = event.detail;
        this.viewMode = 'edit';
    }

    handleViewContract(event) {
        this.selectedRecordId = event.detail;
        this.viewMode = 'contract';
    }

    handleGenerateWorkOrders(event) {
        this.selectedRecordId = event.detail;
        this.viewMode = 'workorder';
    }

    handleShowList() {
        this.viewMode = 'list';
    }
}