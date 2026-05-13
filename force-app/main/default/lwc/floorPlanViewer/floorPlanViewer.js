import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getControlPoints from '@salesforce/apex/FloorPlanController.getControlPoints';
import getFloorPlanImageUrl from '@salesforce/apex/FloorPlanController.getFloorPlanImageUrl';

const STATUS_COLORS = {
    Active:    '#16a34a',
    Triggered: '#dc2626',
    Inactive:  '#6b7280'
};

const TYPE_ABBR = {
    'Trap':            'T',
    'Bait Station':    'B',
    'Sensor':          'S',
    'Inspection Area': 'I',
    'Other':           'O'
};

export default class FloorPlanViewer extends LightningElement {
    @api recordId;

    @track controlPoints   = [];
    @track imageUrl        = null;
    @track isLoading       = true;
    @track errorMessage    = null;
    @track showModal       = false;
    @track modalMode       = 'create';
    @track pendingX        = 0;
    @track pendingY        = 0;
    @track selectedPointId = null;

    _wiredPointsResult;
    _wiredImageResult;
    _imageLoaded = false;
    _imageRect   = null;

    @wire(getFloorPlanImageUrl, { floorPlanId: '$recordId' })
    wiredImage(result) {
        this._wiredImageResult = result;
        if (result.data !== undefined) {
            this.imageUrl = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = 'Error al cargar imagen del plano.';
            this.isLoading = false;
        }
    }

    @wire(getControlPoints, { floorPlanId: '$recordId' })
    wiredPoints(result) {
        this._wiredPointsResult = result;
        if (result.data) {
            this.controlPoints = result.data.map(p => this._mapPoint(p));
            this.errorMessage = null;
        } else if (result.error) {
            this.errorMessage = 'Error al cargar puntos de control.';
        }
    }

    // Mismo patrón exacto de la versión que funcionó
    _mapPoint(p) {
        const num = p.Name ? p.Name.replace(/\D/g, '').replace(/^0+/, '') || p.Name : '';
        return {
            ...p,
            statusColor:  STATUS_COLORS[p.Status__c] || STATUS_COLORS.Active,
            typeAbbr:     TYPE_ABBR[p.PointType__c] || '?',
            pointNum:     num,
            svgTransform: `transform: translate(${p.XPercent__c}%, ${p.YPercent__c}%)`
        };
    }

    get countActive()    { return this.controlPoints.filter(p => p.Status__c === 'Active').length; }
    get countTriggered() { return this.controlPoints.filter(p => p.Status__c === 'Triggered').length; }
    get countInactive()  { return this.controlPoints.filter(p => p.Status__c === 'Inactive').length; }

    handleImageLoad() {
        this._imageLoaded = true;
        this._updateImageRect();
    }

    _updateImageRect() {
        const img = this.template.querySelector('.floor-plan-image');
        if (img) this._imageRect = img.getBoundingClientRect();
    }

    handleCanvasClick(event) {
        const isPoint = event.target.closest && event.target.closest('.cp-group');
        if (isPoint) return;
        if (!this._imageLoaded) return;
        this._updateImageRect();
        if (!this._imageRect) return;
        const rect = this._imageRect;
        const x = ((event.clientX - rect.left) / rect.width)  * 100;
        const y = ((event.clientY - rect.top)  / rect.height) * 100;
        if (x < 0 || x > 100 || y < 0 || y > 100) return;
        this.pendingX = parseFloat(x.toFixed(2));
        this.pendingY = parseFloat(y.toFixed(2));
        this.modalMode = 'create';
        this.selectedPointId = null;
        this.showModal = true;
    }

    handlePointClick(event) {
        event.stopPropagation();
        this.selectedPointId = event.currentTarget.dataset.id;
        this.modalMode = 'view';
        this.showModal = true;
    }

    handleModalClose()  { this.showModal = false; this.selectedPointId = null; }
    handlePointSaved()  { this.showModal = false; this.selectedPointId = null; this._refreshData(); }
    handleRefresh()     { this._refreshData(); }

    handleUploadFinished(event) {
        if (event.detail.files?.length > 0) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Plano cargado correctamente.', variant: 'success' }));
            this._refreshData();
        }
    }

    _refreshData() {
        this.isLoading = true;
        Promise.all([refreshApex(this._wiredPointsResult), refreshApex(this._wiredImageResult)])
            .finally(() => { this.isLoading = false; });
    }
}