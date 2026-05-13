import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCitasServicio from '@salesforce/apex/TechCitasServicioController.getCitasServicio';

const STATUS_CLASS_MAP = {
    'Completado': 'status-pill status-completado',
    'En curso':   'status-pill status-en-curso',
    'Programado': 'status-pill status-programado',
    'Ninguno':    'status-pill status-ninguno',
};

export default class TechCitasServicioList extends LightningElement {
    @api recordId;
    @track isLoading   = true;
    @track hasError    = false;
    @track errorMessage = '';
    @track citas       = [];
    @track showModal   = false;
    @track modalUrl    = '';
    @track modalTitle  = '';

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
                    statusClass: r.status === 'Completada'
                        ? 'rev-status rev-completada'
                        : 'rev-status rev-en-proceso',
                    hasFotos: (r.totalFotos || 0) > 0,
                    hasNC:    (r.totalNoConformidades || 0) > 0,
                })),
            };
        });
    }

    get isEmpty()  { return !this.isLoading && !this.hasError && this.citas.length === 0; }
    get hasCitas() { return !this.isLoading && !this.hasError && this.citas.length > 0;  }

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

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult);
    }
}
