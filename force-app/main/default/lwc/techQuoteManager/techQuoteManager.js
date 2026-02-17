import { LightningElement, track } from 'lwc';

export default class TechQuoteManager extends LightningElement {
    @track viewMode = 'list'; // 'list' o 'edit'
    @track selectedRecordId = null;

    get isListView() {
        return this.viewMode === 'list';
    }

    get isEditView() {
        return this.viewMode === 'edit';
    }

    handleCreateNew() {
        this.selectedRecordId = null;
        this.viewMode = 'edit';
    }

    handleEditQuote(event) {
        this.selectedRecordId = event.detail;
        this.viewMode = 'edit';
    }

    handleShowList() {
        this.viewMode = 'list';
    }
}