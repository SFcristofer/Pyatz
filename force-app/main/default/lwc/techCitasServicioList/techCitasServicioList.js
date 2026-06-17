import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCitasServicio        from '@salesforce/apex/TechCitasServicioController.getCitasServicio';
import verificarSA             from '@salesforce/apex/TechCitasServicioController.verificarSA';
import desverificarSA          from '@salesforce/apex/TechCitasServicioController.desverificarSA';
import getSAHistory            from '@salesforce/apex/TechCitasServicioController.getSAHistory';

const STATUS_CLASS_MAP = {
    'Completado': 'status-pill status-completado',
    'En curso':   'status-pill status-en-curso',
    'Programado': 'status-pill status-programado',
    'Ninguno':    'status-pill status-ninguno',
    'Pausado':    'status-pill status-pausado',
};

export default class TechCitasServicioList extends LightningElement {
    @api recordId;
    @track isLoading      = true;
    @track hasError       = false;
    @track errorMessage   = '';
    @track citas          = [];
    @track showModal      = false;
    @track modalUrl       = '';
    @track modalTitle     = '';
    
    // Verificación
    @track verifyingSAId  = null;
    @track isVerifying       = false;
    @track showVerifyModal   = false;
    @track modalFirmante     = '';
    @track modalCargo        = '';

    @track showHistoryModal  = false;
    @track historyTitle      = '';
    @track historyData       = [];
    @track loadingHistory    = false;

    _wiredResult;

    @wire(getCitasServicio, { workOrderId: '$recordId' })
    wiredCitas(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.citas = this._mapCitas(result.data);
            this.hasError = false;
        } else if (result.error) {
            this.hasError = true;
            this.errorMessage = result.error?.body?.message || 'Error al cargar citas de servicio.';
        }
    }

    _mapCitas(data) {
        return data.map(c => {
            const total     = c.totalRevisiones     || 0;
            const completed = c.revisionesCompletadas || 0;
            const pct       = total > 0 ? Math.round((completed / total) * 100) : 0;
            return {
                ...c,
                zonasTratar:   c.zonasTratar || '—',
                statusClass:   STATUS_CLASS_MAP[c.status] || 'status-pill status-default',
                progressStyle: `width: ${pct}%`,
                hasRevisiones: Array.isArray(c.revisiones) && c.revisiones.length > 0,
                revisiones: (c.revisiones || []).map(r => ({
                    ...r,
                    tipoReporte: r.tipoReporte || '—',
                    statusClass: r.status === 'Completada' ? 'rev-status rev-completada'
                           : r.status === 'Pausado'    ? 'rev-status rev-pausada'
                           :                             'rev-status rev-en-proceso',
                    hasFotos: (r.totalFotos || 0) > 0,
                    hasNC:    (r.totalNoConformidades || 0) > 0,
                })),
            };
        });
    }

    get isEmpty()        { return !this.isLoading && !this.hasError && this.citas.length === 0; }
    get hasCitas()       { return !this.isLoading && !this.hasError && this.citas.length > 0;  }
    get hasHistoryData() { return this.historyData && this.historyData.length > 0; }

    handleOpenSA(event) {
        const saId = event.currentTarget.dataset.saId;
        window.open(`/lightning/r/ServiceAppointment/${saId}/view`, '_blank');
    }

    handleSaPDF(event) {
        const saId  = event.currentTarget.dataset.saId;
        const saNum = event.currentTarget.dataset.saNum;
        this.modalTitle = `Revisiones — ${saNum}`;
        this.modalUrl   = `/apex/ServiceReviewPDF?id=${saId}`;
        this.showModal  = true;
    }

    handleUnifiedPDF() {
        this.modalTitle = 'PDF Consolidado';
        this.modalUrl   = `/apex/ServiceReviewPDF?workOrderId=${this.recordId}`;
        this.showModal  = true;
    }

    handleCloseModal() {
        this.showModal  = false;
        this.modalUrl   = '';
    }

    handleVerificar(event) {
        this.verifyingSAId = event.currentTarget.dataset.saId;
        this.modalFirmante = '';
        this.modalCargo    = '';
        this.showVerifyModal = true;
    }

    handleVerifyModalFirmanteChange(e) { this.modalFirmante = e.target.value; }
    handleVerifyModalCargoChange(e)    { this.modalCargo    = e.target.value; }

    handleCancelVerificar() {
        this.showVerifyModal = false;
        this.verifyingSAId   = null;
    }

    async handleConfirmVerificar() {
        this.isVerifying     = true;
        this.showVerifyModal = false;
        try {
            await verificarSA({
                saId:           this.verifyingSAId,
                nombreFirmante: this.modalFirmante,
                cargoFirmante:  this.modalCargo
            });
            await refreshApex(this._wiredResult);
        } catch (e) {
            console.error('Error al verificar SA:', e);
        } finally {
            this.isVerifying = false;
            this.verifyingSAId = null;
        }
    }

    async handleDesverificar(event) {
        const saId = event.currentTarget.dataset.saId;
        this.isVerifying = true;
        try {
            await desverificarSA({ saId: saId });
            await refreshApex(this._wiredResult);
        } catch (e) {
            console.error('Error al desverificar SA:', e);
        } finally {
            this.isVerifying = false;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult);
    }

    handleShowHistory(event) {
        const saId  = event.currentTarget.dataset.saId;
        const saNum = event.currentTarget.dataset.saNum;
        this.historyTitle    = `Historial — ${saNum}`;
        this.historyData     = [];
        this.showHistoryModal = true;
        this.loadingHistory  = true;
        getSAHistory({ saId })
            .then(data  => { this.historyData = data; })
            .catch(()   => { this.historyData = []; })
            .finally(() => { this.loadingHistory = false; });
    }

    handleCloseHistory() {
        this.showHistoryModal = false;
        this.historyData      = [];
    }
}