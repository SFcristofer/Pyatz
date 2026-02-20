import { LightningElement, track } from 'lwc';

export default class QuoteTechnicalManager extends LightningElement {
    @track viewMode = 'list'; // 'list' o 'edit'

    get isListView() {
        return this.viewMode === 'list';
    }

    get isEditView() {
        return this.viewMode === 'edit';
    }

    handleShowEditor() {
        this.viewMode = 'edit';
    }

    handleShowList() {
        this.viewMode = 'list';
    }
}