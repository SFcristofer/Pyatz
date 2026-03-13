import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getProcessHistory from '@salesforce/apex/QuoteTechnicalController.getProcessHistory';
import getOpenOpportunities from '@salesforce/apex/QuoteTechnicalController.getOpenOpportunities';

export default class TechProcessSummary extends LightningElement {
    @api recordId; // Oportunidad base
    @track displayRecordId; // ID que estamos visualizando actualmente
    @track openOppOptions = []; // Opciones para el dropdown de pipeline activo
    processData = [];
    _wiredResult;

    connectedCallback() {
        this.displayRecordId = this.recordId;
    }

    @wire(getOpenOpportunities)
    wiredOpenOpps({ error, data }) {
        if (data) {
            this.openOppOptions = data;
        } else if (error) {
            console.error('Error loading open opportunities:', error);
        }
    }

    @wire(getProcessHistory, { opportunityId: '$displayRecordId' })
    wiredHistory(result) {
        this._wiredResult = result;
        if (result.data) {
            this.processData = result.data;
        } else if (result.error) {
            console.error('Error loading history:', result.error);
        }
    }

    handleRecordChange(event) {
        // Capturamos el ID de forma segura según el componente que disparó el evento
        const selectedId = event.detail.recordId || event.detail.value;
        
        if (selectedId && selectedId !== this.displayRecordId) {
            this.displayRecordId = selectedId;
            // Forzamos un refresco manual por si el wire no detecta el cambio de inmediato
            this.refreshData();
        } else if (!selectedId) {
            this.resetToDefault();
        }
    }

    resetToDefault() {
        this.displayRecordId = this.recordId;
    }

    get isViewingOther() {
        return this.displayRecordId !== this.recordId;
    }

    /**
     * Método público para que el padre pida refrescar los datos.
     */
    @api
    async refreshData() {
        await refreshApex(this._wiredResult);
    }

    get processedData() {
        const emojiMap = {
            'realizado': '✅', 'aceptado': '✅', 'confirmado': '✅', 'enhorabuena': '🎉',
            'en proceso': '⏳', 'pendiente': '🕒', 'ajuste': '⚙️',
            'rechazado': '❌', 'falta información': '⚠️', 'mal': '🚫'
        };

        return this.processData.map(item => {
            let statusClass = 'slds-badge ';
            const s = (item.Estado__c || '').toLowerCase();
            let emoji = '⚪';

            // Determinar color y emoji
            if (['realizado', 'aceptado', 'confirmado', 'enhorabuena'].some(v => s.includes(v))) {
                statusClass += 'slds-theme_success';
                emoji = emojiMap[s] || '✅';
            } else if (['en proceso', 'pendiente', 'ajuste'].some(v => s.includes(v))) {
                statusClass += 'slds-theme_warning';
                emoji = emojiMap[s] || '⏳';
            } else if (['rechazado', 'falta información', 'mal'].some(v => s.includes(v))) {
                statusClass += 'slds-theme_error';
                emoji = emojiMap[s] || '❌';
            } else {
                statusClass += 'slds-theme_lightest';
            }

            return {
                stage: item.Etapa__c.toUpperCase(),
                subStage: item.Subetapa__c,
                status: `${emoji} ${item.Estado__c}`,
                statusClass: statusClass + ' slds-p-horizontal_small slds-m-vertical_xx-small',
                lastUpdate: new Date(item.LastModifiedDate).toLocaleDateString()
            };
        });
    }
}