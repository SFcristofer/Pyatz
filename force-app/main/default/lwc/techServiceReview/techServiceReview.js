import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getLocationService } from 'lightning/mobileCapabilities';
import ORG_TIMEZONE from '@salesforce/i18n/timeZone';

import getServiceAppointmentInfo from '@salesforce/apex/ServiceReviewController.getServiceAppointmentInfo';
import createRevision            from '@salesforce/apex/ServiceReviewController.createRevision';
import cancelRevision            from '@salesforce/apex/ServiceReviewController.cancelRevision';
import saveRevisionData          from '@salesforce/apex/ServiceReviewController.saveRevisionData';
import savePhoto                 from '@salesforce/apex/ServiceReviewController.savePhoto';
import getRevisionPhotos         from '@salesforce/apex/ServiceReviewController.getRevisionPhotos';
import deletePhoto               from '@salesforce/apex/ServiceReviewController.deletePhoto';
import saveSignature             from '@salesforce/apex/ServiceReviewController.saveSignature';
import getRevisionSignature      from '@salesforce/apex/ServiceReviewController.getRevisionSignature';

import getFormTemplates from '@salesforce/apex/FormTemplateController.getFormTemplates';
import getFormTemplate  from '@salesforce/apex/FormTemplateController.getFormTemplate';

// ─── Wizard steps ─────────────────────────────────────────────────────────────
const STEP_LOADING    = 'loading';
const STEP_OVERVIEW   = 'overview';
const STEP_PHOTOS     = 'photos';
const STEP_SIGNATURE  = 'signature';
const STEP_FORM_SEL   = 'formSelect';
const STEP_FORM_FILL  = 'formFill';
const STEP_DONE       = 'done';

const SIG_IDLE    = 'idle';
const SIG_SIGNING = 'signing';
const SIG_PREVIEW = 'preview';

const MAX_CANVAS_WIDTH = 1280;
const INK_COLOR = '#1a1a2e';
const INK_WIDTH = 3;
const STAMP_BG  = '#f5f5f5';
const STAMP_ACC = '#0176d3';

// Form templates are now loaded dynamically from Form_Template__c via FormTemplateController

// ─── Component ────────────────────────────────────────────────────────────────

export default class TechServiceReview extends LightningElement {

    @api recordId;

    // Navigation
    @track currentStep     = STEP_LOADING;
    @track saInfo          = null;

    // Active revision
    @track revisionId      = null;
    @track savedRevNumber  = 0;

    // ── Photos ────────────────────────────────────────────────────────────────
    @track coords            = null;
    @track gpsReady          = false;
    @track loadingGps        = true;
    @track gpsError          = '';
    @track photoReady        = false;
    @track savingPhoto       = false;
    @track revisionPhotos    = [];
    @track loadingRevPhotos  = false;
    @track selectedPhoto     = null;
    @track confirmDeletePhoto = false;
    @track deletingPhoto     = false;
    @track loadingFullPhoto  = false;

    _woInfo          = {};
    _pendingImg      = null;
    photoTimestamp   = '';

    // ── Signature ─────────────────────────────────────────────────────────────
    @track sigState        = SIG_IDLE;
    @track signerName      = '';
    @track canvasEmpty     = true;
    @track signatureSaved  = false;
    @track savingSignature = false;
    @track savedSigThumb   = null;
    @track savedSigName    = '';
    @track sigGpsReady     = false;
    @track sigGpsLabel     = 'Obteniendo GPS...';

    _sigCoords       = null;
    _cleanBase64     = null;
    _drawing         = false;
    _lastX           = 0;
    _lastY           = 0;
    _canvasReady     = false;
    _previewRendered = false;

    // ── Form ──────────────────────────────────────────────────────────────────
    @track selectedFormType  = '';
    @track formQuestions     = [];
    @track observaciones     = '';
    @track savingRevision    = false;
    @track templatesMeta     = [];   // [{tipo, icono, questionCount, hasTemplate}]
    @track loadingTemplate   = false;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadSAInfo();
        this._loadTemplatesMeta();
    }

    renderedCallback() {
        if (this.currentStep === STEP_SIGNATURE) {
            if (this.sigState === SIG_SIGNING && !this._canvasReady) {
                this._initSignCanvas();
            }
            if (this.sigState === SIG_PREVIEW && !this._previewRendered) {
                this._renderSignPreview();
                this._previewRendered = true;
            }
        }
    }

    // ─── Getters – navigation ──────────────────────────────────────────────────

    get isLoading()      { return this.currentStep === STEP_LOADING; }
    get isOverview()     { return this.currentStep === STEP_OVERVIEW; }
    get isWizard()       { return [STEP_PHOTOS, STEP_SIGNATURE, STEP_FORM_SEL, STEP_FORM_FILL, STEP_DONE].includes(this.currentStep); }
    get isStepPhotos()   { return this.currentStep === STEP_PHOTOS; }
    get isStepSignature(){ return this.currentStep === STEP_SIGNATURE; }
    get isStepFormSelect(){ return this.currentStep === STEP_FORM_SEL; }
    get isStepFormFill() { return this.currentStep === STEP_FORM_FILL; }
    get isDone()         { return this.currentStep === STEP_DONE; }

    get wizardTitle() {
        const map = {
            [STEP_PHOTOS]:    'Paso 1 — Fotos',
            [STEP_SIGNATURE]: 'Paso 2 — Firma del Cliente',
            [STEP_FORM_SEL]:  'Paso 3 — Tipo de Reporte',
            [STEP_FORM_FILL]: 'Paso 4 — Formulario',
            [STEP_DONE]:      'Revisión Completada',
        };
        return map[this.currentStep] || '';
    }

    get canGoBack() {
        return [STEP_SIGNATURE, STEP_FORM_SEL, STEP_FORM_FILL].includes(this.currentStep);
    }

    get showWizardFooter() {
        return this.isWizard && !this.isDone;
    }

    get pip1Class() { return this._pipClass(STEP_PHOTOS); }
    get pip2Class() { return this._pipClass(STEP_SIGNATURE); }
    get pip3Class() { return this._pipClass(STEP_FORM_SEL); }
    get pip4Class() { return this._pipClass(STEP_FORM_FILL); }

    _pipClass(step) {
        const order = [STEP_PHOTOS, STEP_SIGNATURE, STEP_FORM_SEL, STEP_FORM_FILL, STEP_DONE];
        const cur   = order.indexOf(this.currentStep);
        const idx   = order.indexOf(step);
        if (idx < cur)  return 'step-pip step-pip--done';
        if (idx === cur) return 'step-pip step-pip--active';
        return 'step-pip';
    }

    // ─── Getters – overview ───────────────────────────────────────────────────

    get hasRevisions()   { return this.saInfo && this.saInfo.revisionesList && this.saInfo.revisionesList.length > 0; }
    get noRevisions()    { return !this.hasRevisions; }
    get nextRevNumber()  { return this.saInfo ? (this.saInfo.revisionesTotales || 0) + 1 : 1; }
    get progressStyle() {
        if (!this.saInfo || !this.saInfo.maxRevisiones) return 'width:0%';
        const pct = Math.min(100, Math.round((this.saInfo.revisionesCompletadas / this.saInfo.maxRevisiones) * 100));
        return `width:${pct}%`;
    }

    // ─── Getters – photos ─────────────────────────────────────────────────────

    get captureDisabled()  { return this.loadingGps || !this.gpsReady; }
    get gpsLabel()         { return this.coords ? `${this.coords.latitude}, ${this.coords.longitude}  ±${this.coords.accuracy}m` : ''; }
    get hasRevPhotos()     { return this.revisionPhotos && this.revisionPhotos.length > 0; }
    get revPhotoCount()    { return this.revisionPhotos ? this.revisionPhotos.length : 0; }
    get showPhotoModal()   { return this.selectedPhoto !== null; }

    // ─── Getters – signature ──────────────────────────────────────────────────

    get sigStateIdle()    { return this.sigState === SIG_IDLE; }
    get sigStateSigning() { return this.sigState === SIG_SIGNING; }
    get sigStatePreview() { return this.sigState === SIG_PREVIEW; }
    get sigNameEmpty()    { return !this.signerName || !this.signerName.trim(); }
    get canSkipSignature(){ return !this.signatureSaved && this.sigState === SIG_IDLE; }
    get sigGpsDotClass()  { return this.sigGpsReady ? 'gps-dot gps-dot--ok' : 'gps-dot gps-dot--loading'; }

    // ─── Getters – form ───────────────────────────────────────────────────────

    get noFormTypeSelected() { return !this.selectedFormType; }
    get loadingFormTypes()   { return this.templatesMeta.length === 0; }

    get formTypeOptions() {
        return this.templatesMeta.map(t => {
            const isSelected = t.tipo === this.selectedFormType;
            return {
                value:         t.tipo,
                label:         t.tipo,
                questionCount: t.hasTemplate ? t.questionCount + ' preguntas' : 'Formulario libre',
                cardClass:     isSelected ? 'form-type-card form-type-card--selected' : 'form-type-card',
                icon:          t.icono || 'utility:form',
                iconVariant:   isSelected ? 'inverse' : '',
            };
        });
    }

    // ─── Load data ────────────────────────────────────────────────────────────

    _loadSAInfo() {
        this.currentStep = STEP_LOADING;
        getServiceAppointmentInfo({ saId: this.recordId })
            .then(data => {
                this.saInfo = this._enrichRevList(data);
                this._woInfo = {
                    accountName:     data.accountName,
                    workOrderNumber: data.workOrderNumber,
                    techName:        data.techName,
                    techInitials:    data.techInitials,
                };
                this.currentStep = STEP_OVERVIEW;
            })
            .catch(err => {
                this._toast('Error', err.body?.message || 'No se pudo cargar la cita.', 'error');
                this.currentStep = STEP_OVERVIEW;
            });
    }

    _enrichRevList(data) {
        if (!data || !data.revisionesList) return data;
        return {
            ...data,
            revisionesList: data.revisionesList.map(r => ({
                ...r,
                cardClass:  r.isCompleted ? 'rev-card rev-card--done' : 'rev-card rev-card--pending',
                badgeClass: r.isCompleted ? 'rev-card__badge rev-card__badge--done' : 'rev-card__badge rev-card__badge--pending',
            }))
        };
    }

    _loadRevisionPhotos() {
        if (!this.revisionId) return;
        this.loadingRevPhotos = true;
        getRevisionPhotos({ revisionId: this.revisionId })
            .then(data => {
                this.revisionPhotos = data.map(p => ({
                    ...p,
                    thumbSrc: p.thumbBase64 ? `data:image/jpeg;base64,${p.thumbBase64}` : null,
                }));
            })
            .catch(() => {})
            .finally(() => { this.loadingRevPhotos = false; });
    }

    // ─── Overview handlers ────────────────────────────────────────────────────

    handleStartRevision() {
        const num = this.nextRevNumber;
        createRevision({ saId: this.recordId, revisionNumber: num })
            .then(id => {
                this.revisionId    = id;
                this.savedRevNumber = num;
                this.revisionPhotos = [];
                this.signatureSaved = false;
                this.savedSigName   = '';
                this.savedSigThumb  = null;
                this.selectedFormType = '';
                this.formQuestions    = [];
                this.observaciones    = '';
                this.photoReady       = false;
                this.sigState         = SIG_IDLE;
                this._loadSAInfo_silent();
                this._startGPS();
                this.currentStep = STEP_PHOTOS;
            })
            .catch(err => {
                this._toast('Error', err.body?.message || 'No se pudo crear la revisión.', 'error');
            });
    }

    _loadSAInfo_silent() {
        getServiceAppointmentInfo({ saId: this.recordId })
            .then(data => { this.saInfo = this._enrichRevList(data); })
            .catch(() => {});
    }

    handleRevisionClick(event) {
        const revId = event.currentTarget.dataset.id;
        const rev = this.saInfo.revisionesList.find(r => r.id === revId);
        if (!rev || rev.isCompleted) return;

        this.revisionId = rev.id;
        this.savedRevNumber = rev.numero;
        this.selectedFormType = rev.templateId || rev.tipo; // Prioridad al ID del Lookup
        this.revisionPhotos = [];
        this.signatureSaved = false;
        this.observaciones = '';
        
        this._loadRevisionState(revId);
        this._startGPS();
        this.currentStep = STEP_PHOTOS;
    }

    _loadRevisionState(revId) {
        this.loadingRevPhotos = true;
        getRevisionPhotos({ revisionId: revId })
            .then(data => {
                this.revisionPhotos = data.map(p => ({
                    ...p,
                    thumbSrc: `data:image/png;base64,${p.thumbBase64}`
                }));
            })
            .catch(() => {});

        getRevisionSignature({ revisionId: revId })
            .then(data => {
                if (data.thumbBase64) {
                    this.signatureSaved = true;
                    this.savedSigName = data.signerName;
                    this.savedSigThumb = `data:image/png;base64,${data.thumbBase64}`;
                }
            })
            .catch(() => {});
    }

    handleGenerateReport() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.open(`/apex/ServiceReviewPDF?id=${this.recordId}`, '_blank');
    }

    handleBackToOverview() {
        this._loadSAInfo();
    }

    // ─── Wizard navigation ────────────────────────────────────────────────────

    handleBack() {
        const prev = {
            [STEP_SIGNATURE]: STEP_PHOTOS,
            [STEP_FORM_SEL]:  STEP_SIGNATURE,
            [STEP_FORM_FILL]: STEP_FORM_SEL,
        };
        const target = prev[this.currentStep];
        if (target) {
            this.currentStep = target;
            if (target === STEP_SIGNATURE) {
                this._canvasReady     = false;
                this._previewRendered = false;
            }
        }
    }

    handleCancelWizard() {
        if (this.revisionId) {
            cancelRevision({ revisionId: this.revisionId })
                .catch(() => {});
            this.revisionId = null;
        }
        this._loadSAInfo();
    }

    handleNextFromPhotos() {
        this._requestSigGPS();
        this.currentStep = STEP_SIGNATURE;
    }

    handleNextFromSignature() {
        this.currentStep = STEP_FORM_SEL;
    }

    handleNextFromFormSelect() {
        if (!this.selectedFormType) return;
        this.loadingTemplate = true;
        getFormTemplate({ tipoReporte: this.selectedFormType })
            .then(preguntasJson => {
                let questions = [];
                try { questions = JSON.parse(preguntasJson || '[]'); } catch(e) {}
                this._buildFormQuestionsFromData(questions);
                this.currentStep = STEP_FORM_FILL;
            })
            .catch(() => {
                this._buildFormQuestionsFromData([]);
                this.currentStep = STEP_FORM_FILL;
            })
            .finally(() => { this.loadingTemplate = false; });
    }

    // ─── GPS ──────────────────────────────────────────────────────────────────

    _startGPS() {
        this.loadingGps = true;
        this.gpsReady   = false;
        this.gpsError   = '';

        try {
            const ls = getLocationService();
            if (ls && ls.isAvailable()) {
                ls.getCurrentPosition({ enableHighAccuracy: true })
                    .then(r => {
                        this.coords = {
                            latitude:  r.coords.latitude.toFixed(6),
                            longitude: r.coords.longitude.toFixed(6),
                            accuracy:  Math.round(r.coords.accuracy),
                        };
                        this.gpsReady   = true;
                        this.loadingGps = false;
                    })
                    .catch(() => this._fallbackGPS());
                return;
            }
        } catch (e) { /* fallback */ }
        this._fallbackGPS();
    }

    _fallbackGPS() {
        if (!navigator.geolocation) {
            this.loadingGps = false;
            this.gpsError   = 'GPS no disponible en este dispositivo.';
            return;
        }
        navigator.geolocation.getCurrentPosition(
            pos => {
                this.coords = {
                    latitude:  pos.coords.latitude.toFixed(6),
                    longitude: pos.coords.longitude.toFixed(6),
                    accuracy:  Math.round(pos.coords.accuracy),
                };
                this.gpsReady   = true;
                this.loadingGps = false;
            },
            err => {
                this.loadingGps = false;
                this.gpsError   = this._gpsErrMsg(err);
            },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }

    _gpsErrMsg(err) {
        if (err.code === err.PERMISSION_DENIED)    return 'Ubicación no disponible (revisa permisos).';
        if (err.code === err.POSITION_UNAVAILABLE) return 'Ubicación no disponible.';
        if (err.code === err.TIMEOUT)              return 'Tiempo agotado al obtener GPS.';
        return 'No se pudo obtener la ubicación.';
    }

    // ─── Photos ───────────────────────────────────────────────────────────────

    handleCaptureClick() {
        this.template.querySelector('[data-id="cameraInput"]').click();
    }

    handlePhotoSelected(event) {
        const file = event.target.files[0];
        if (!file) return;
        this._stampAndPreview(file);
    }

    handleRetakePhoto() {
        this.photoReady = false;
        this._pendingImg = null;
        const input = this.template.querySelector('[data-id="cameraInput"]');
        if (input) input.value = '';
    }

    handleSavePhoto() {
        if (!this.revisionId) return;
        this.savingPhoto = true;

        const canvas    = this.template.querySelector('[data-id="photoCanvas"]');
        const base64    = canvas.toDataURL('image/jpeg', 0.90).split(',')[1];
        const thumbB64  = this._makeThumbnail(canvas);
        const filename  = `GeoFoto_${this._fileTimestamp()}.jpg`;

        savePhoto({
            revisionId:  this.revisionId,
            base64,
            base64Thumb: thumbB64,
            filename,
            latitude:    this.coords ? parseFloat(this.coords.latitude)  : null,
            longitude:   this.coords ? parseFloat(this.coords.longitude) : null,
            accuracy:    this.coords ? this.coords.accuracy              : null,
        })
        .then(() => {
            this._toast('Foto guardada', 'Foto con coordenadas GPS guardada.', 'success');
            this.handleRetakePhoto();
            this._loadRevisionPhotos();
        })
        .catch(err => {
            this._toast('Error', err.body?.message || 'No se pudo guardar la foto.', 'error');
        })
        .finally(() => { this.savingPhoto = false; });
    }

    handlePhotoClick(event) {
        const id    = event.currentTarget.dataset.id;
        const photo = this.revisionPhotos.find(p => p.id === id);
        if (!photo) return;
        this.selectedPhoto    = { ...photo, fullSrc: photo.thumbSrc };
        this.confirmDeletePhoto = false;
        this.loadingFullPhoto = false;
    }

    handleClosePhotoModal()   { this.selectedPhoto = null; }
    handleDeletePhotoClick()  { this.confirmDeletePhoto = true; }
    handleDeletePhotoCancel() { this.confirmDeletePhoto = false; }

    handleDeletePhotoConfirm() {
        this.deletingPhoto = true;
        deletePhoto({ contentVersionId: this.selectedPhoto.id })
            .then(() => {
                this._toast('Eliminada', 'Foto eliminada.', 'success');
                this.selectedPhoto = null;
                this.confirmDeletePhoto = false;
                this._loadRevisionPhotos();
            })
            .catch(err => {
                this._toast('Error', err.body?.message || 'No se pudo eliminar.', 'error');
            })
            .finally(() => { this.deletingPhoto = false; });
    }

    // ─── Canvas foto ──────────────────────────────────────────────────────────

    _stampAndPreview(file) {
        const reader = new FileReader();
        reader.onload = e => {
            const img = new Image();
            img.onload = () => {
                this._pendingImg    = img;
                this.photoTimestamp = this._formatDate(new Date());
                this.photoReady     = true;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._drawToCanvas(img), 0);
            };
            img.src = e.target.result;
        };
        reader.readAsDataURL(file);
    }

    _drawToCanvas(img) {
        const canvas = this.template.querySelector('[data-id="photoCanvas"]');
        if (!canvas) return;
        const scale   = img.width > MAX_CANVAS_WIDTH ? MAX_CANVAS_WIDTH / img.width : 1;
        canvas.width  = img.width  * scale;
        canvas.height = img.height * scale;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        this._drawPhotoStamp(ctx, canvas.width, canvas.height);
    }

    _drawPhotoStamp(ctx, W, H) {
        const now  = new Date();
        const info = this._woInfo || {};
        const idx  = this.revisionPhotos.length + 1;
        const tech = info.techInitials && info.techName
            ? `[${info.techInitials}] ${info.techName}` : '';

        const lines = [
            this._formatDateSpanish(now),
            this.coords
                ? `${this._toDegMin(parseFloat(this.coords.latitude), true)}, ${this._toDegMin(parseFloat(this.coords.longitude), false)}`
                : '',
            info.accountName     || '',
            info.workOrderNumber ? `OT #${info.workOrderNumber}` : '',
            tech,
            `Foto ${idx}`,
        ].filter(l => l.trim() !== '');

        const FS   = Math.max(18, Math.round(W * 0.022));
        const LH   = Math.round(FS * 1.55);
        const PAD  = Math.round(FS * 0.7);
        ctx.font   = `bold ${FS}px Arial, sans-serif`;
        const maxW = lines.reduce((m, l) => Math.max(m, ctx.measureText(l).width), 0);
        const bW   = maxW + PAD * 2;
        const bH   = lines.length * LH + PAD;
        const x    = W - bW - PAD;
        const y    = H - bH - PAD;

        ctx.fillStyle = 'rgba(0,0,0,0.52)';
        ctx.beginPath();
        ctx.roundRect(x - PAD * 0.3, y - PAD * 0.3, bW + PAD * 0.6, bH + PAD * 0.6, 8);
        ctx.fill();
        ctx.fillStyle = '#FFD700';
        ctx.textAlign = 'right';
        lines.forEach((line, i) => { ctx.fillText(line, W - PAD, y + PAD + LH * (i + 1) - 4); });
        ctx.textAlign = 'left';
    }

    _makeThumbnail(canvas) {
        const MAX   = 320;
        const scale = Math.min(1, MAX / Math.max(canvas.width, canvas.height));
        const tw    = Math.round(canvas.width  * scale);
        const th    = Math.round(canvas.height * scale);
        const t     = document.createElement('canvas');
        t.width = tw; t.height = th;
        t.getContext('2d').drawImage(canvas, 0, 0, tw, th);
        return t.toDataURL('image/jpeg', 0.70).split(',')[1];
    }

    // ─── Signature ────────────────────────────────────────────────────────────

    _requestSigGPS() {
        this.sigGpsReady = false;
        this.sigGpsLabel = 'Obteniendo GPS...';
        this._sigCoords  = null;
        if (!navigator.geolocation) { this.sigGpsLabel = 'GPS no disponible'; return; }
        navigator.geolocation.getCurrentPosition(
            pos => {
                this._sigCoords  = {
                    latitude:  pos.coords.latitude.toFixed(6),
                    longitude: pos.coords.longitude.toFixed(6),
                    accuracy:  Math.round(pos.coords.accuracy),
                };
                this.sigGpsReady = true;
                this.sigGpsLabel = `${this._toDegMin(parseFloat(this._sigCoords.latitude), true)}, ${this._toDegMin(parseFloat(this._sigCoords.longitude), false)}  ±${this._sigCoords.accuracy}m`;
            },
            () => { this.sigGpsLabel = 'Ubicación no disponible'; },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }

    handleSignerNameChange(event) { this.signerName = event.target.value; }

    handleGoSign() {
        this._canvasReady     = false;
        this._previewRendered = false;
        this._cleanBase64     = null;
        this.canvasEmpty      = true;
        this.sigState         = SIG_SIGNING;
    }

    handleBackToIdle() {
        this.sigState     = SIG_IDLE;
        this._canvasReady = false;
    }

    handleClearSignature() {
        const canvas = this.template.querySelector('[data-id="signCanvas"]');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        this.canvasEmpty = true;
    }

    handleConfirmSign() {
        const canvas = this.template.querySelector('[data-id="signCanvas"]');
        if (canvas) this._cleanBase64 = canvas.toDataURL('image/png').split(',')[1];
        this._previewRendered = false;
        this.sigState = SIG_PREVIEW;
    }

    handleRetrySign() {
        this._canvasReady     = false;
        this._previewRendered = false;
        this._cleanBase64     = null;
        this.canvasEmpty      = true;
        this.sigState         = SIG_SIGNING;
    }

    handleResign() {
        this.signatureSaved = false;
        this.savedSigName   = '';
        this.savedSigThumb  = null;
        this.sigState       = SIG_IDLE;
        this._canvasReady   = false;
        this._previewRendered = false;
    }

    handleSaveSignature() {
        if (!this.revisionId) return;
        const preview = this.template.querySelector('[data-id="previewCanvas"]');
        if (!preview || !this._cleanBase64) return;

        this.savingSignature = true;
        const ts        = this._fileTimestamp();
        const safeName  = (this.signerName || 'Cliente').replace(/\s+/g, '_');
        const infoB64   = preview.toDataURL('image/png').split(',')[1];
        const thumbB64  = this._sigThumb(preview);

        saveSignature({
            revisionId:    this.revisionId,
            base64Clean:   this._cleanBase64,
            base64Info:    infoB64,
            base64Thumb:   thumbB64,
            filenameClean: `SignClean_${safeName}_${ts}.png`,
            filenameInfo:  `Firma_${safeName}_${ts}.png`,
            signerName:    this.signerName,
        })
        .then(() => {
            this._toast('Firma guardada', `Firma de ${this.signerName} registrada.`, 'success');
            this.signatureSaved = true;
            this.savedSigName   = this.signerName;
            this.savedSigThumb  = `data:image/png;base64,${thumbB64}`;
            this.sigState       = SIG_IDLE;
            this._canvasReady   = false;
        })
        .catch(err => {
            this._toast('Error', err.body?.message || 'No se pudo guardar la firma.', 'error');
        })
        .finally(() => { this.savingSignature = false; });
    }

    // ─── Sign canvas ──────────────────────────────────────────────────────────

    _initSignCanvas() {
        const canvas = this.template.querySelector('[data-id="signCanvas"]');
        if (!canvas) return;
        this._canvasReady = true;
        const dpr  = window.devicePixelRatio || 1;
        const rect = canvas.getBoundingClientRect();
        const w    = rect.width  || 360;
        const h    = rect.height || 220;
        canvas.width  = w * dpr;
        canvas.height = h * dpr;
        canvas.style.width  = w + 'px';
        canvas.style.height = h + 'px';
        const ctx = canvas.getContext('2d');
        ctx.scale(dpr, dpr);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, w, h);

        canvas.addEventListener('touchstart', e => { e.preventDefault(); this._startDraw(e.touches[0], canvas); }, { passive: false });
        canvas.addEventListener('touchmove',  e => { e.preventDefault(); this._drawLine(e.touches[0], canvas); },  { passive: false });
        canvas.addEventListener('touchend',   e => { e.preventDefault(); this._endDraw(); },                        { passive: false });
        canvas.addEventListener('mousedown',  e => this._startDraw(e, canvas));
        canvas.addEventListener('mousemove',  e => this._drawLine(e, canvas));
        canvas.addEventListener('mouseup',    () => this._endDraw());
        canvas.addEventListener('mouseleave', () => this._endDraw());
    }

    _getPos(ptr, canvas) {
        const rect = canvas.getBoundingClientRect();
        return { x: ptr.clientX - rect.left, y: ptr.clientY - rect.top };
    }

    _startDraw(ptr, canvas) { this._drawing = true; const p = this._getPos(ptr, canvas); this._lastX = p.x; this._lastY = p.y; }

    _drawLine(ptr, canvas) {
        if (!this._drawing) return;
        const ctx = canvas.getContext('2d');
        const p   = this._getPos(ptr, canvas);
        ctx.beginPath();
        ctx.moveTo(this._lastX, this._lastY);
        ctx.lineTo(p.x, p.y);
        ctx.strokeStyle = INK_COLOR;
        ctx.lineWidth   = INK_WIDTH;
        ctx.lineCap     = 'round';
        ctx.lineJoin    = 'round';
        ctx.stroke();
        this._lastX  = p.x;
        this._lastY  = p.y;
        this.canvasEmpty = false;
    }

    _endDraw() { this._drawing = false; }

    _renderSignPreview() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const preview = this.template.querySelector('[data-id="previewCanvas"]');
            if (!preview || !this._cleanBase64) return;
            const img = new Image();
            img.onload = () => {
                const sigW  = img.width;
                const sigH  = img.height;
                const info  = this._woInfo || {};
                const FONT  = Math.max(13, Math.round(sigW * 0.026));
                const LINE  = Math.round(FONT * 1.7);
                const PAD   = Math.round(FONT * 1.0);
                const rows  = this._sigRows(info);
                const stmpH = PAD + Math.round(LINE * 1.2) + LINE * rows.length + PAD;
                preview.width  = sigW;
                preview.height = sigH + stmpH;
                const ctx = preview.getContext('2d');
                ctx.drawImage(img, 0, 0, sigW, sigH);
                ctx.strokeStyle = '#cccccc'; ctx.lineWidth = 1;
                ctx.beginPath(); ctx.moveTo(0, sigH); ctx.lineTo(sigW, sigH); ctx.stroke();
                this._drawSigStamp(ctx, sigW, sigH, stmpH, FONT, LINE, PAD, rows, info);
            };
            img.src = 'data:image/png;base64,' + this._cleanBase64;
        }, 0);
    }

    _sigRows(info) {
        const coord = this._sigCoords
            ? `${this._toDegMin(parseFloat(this._sigCoords.latitude), true)}, ${this._toDegMin(parseFloat(this._sigCoords.longitude), false)}  ±${this._sigCoords.accuracy}m`
            : 'No disponible';
        const tech = info.techInitials && info.techName ? `[${info.techInitials}] ${info.techName}` : '';
        return [
            ['Firmante:', this.signerName],
            ['Fecha:',    this._formatDateSpanish(new Date())],
            ['GPS:',      coord],
            info.workOrderNumber ? ['OT:',      `#${info.workOrderNumber}`] : null,
            info.accountName     ? ['Cliente:', info.accountName]           : null,
            tech                 ? ['Técnico:', tech]                       : null,
        ].filter(r => r !== null);
    }

    _drawSigStamp(ctx, W, sigH, stmpH, FONT, LINE, PAD, rows, info) {
        const COL = Math.round(FONT * 5.5);
        ctx.fillStyle = STAMP_BG; ctx.fillRect(0, sigH, W, stmpH);
        ctx.fillStyle = STAMP_ACC; ctx.fillRect(0, sigH, W, 4);
        ctx.font = `bold ${Math.round(FONT * 0.9)}px Arial, sans-serif`;
        ctx.fillStyle = STAMP_ACC;
        ctx.fillText('FIRMA DIGITAL VERIFICADA', PAD, sigH + PAD + LINE * 0.75);
        rows.forEach((row, i) => {
            const yBase = sigH + PAD + LINE * (i + 1.75);
            ctx.font = `bold ${FONT}px Arial, sans-serif`; ctx.fillStyle = '#666666';
            ctx.fillText(row[0], PAD, yBase);
            ctx.font = `${FONT}px Arial, sans-serif`; ctx.fillStyle = '#111111';
            ctx.fillText(row[1], PAD + COL, yBase, W - PAD - COL);
        });
    }

    _sigThumb(canvas) {
        const MAX   = 320;
        const scale = Math.min(1, MAX / Math.max(canvas.width, canvas.height));
        const tw    = Math.round(canvas.width  * scale);
        const th    = Math.round(canvas.height * scale);
        const t     = document.createElement('canvas');
        t.width = tw; t.height = th;
        t.getContext('2d').drawImage(canvas, 0, 0, tw, th);
        return t.toDataURL('image/png', 0.70).split(',')[1];
    }

    // ─── Form ─────────────────────────────────────────────────────────────────

    handleSelectFormType(event) {
        this.selectedFormType = event.currentTarget.dataset.value;
    }

    _loadTemplatesMeta() {
        getFormTemplates()
            .then(data => { this.templatesMeta = data; })
            .catch(() => {});
    }

    _buildFormQuestionsFromData(questions) {
        if (questions.length === 0) {
            this.formQuestions = [{
                id: 'obs', label: 'Descripción del servicio', type: 'text',
                value: '', showDeficiencia: false, deficienciaText: '',
                isRadio: false, isNumber: false, isText: true, lwcOptions: [],
            }];
            return;
        }
        this.formQuestions = questions.map(q => ({
            ...q,
            value:           '',
            showDeficiencia: false,
            deficienciaText: q.def || '',
            isRadio:         q.type === 'radio',
            isNumber:        q.type === 'number',
            isText:          q.type === 'text',
            lwcOptions:      (q.options || []).map(o => ({ label: o, value: o })),
        }));
    }

    handleQuestionChange(event) {
        const qid   = event.target.dataset.qid;
        const value = event.detail.value !== undefined ? String(event.detail.value) : event.target.value;
        this.formQuestions = this.formQuestions.map(q => {
            if (q.id !== qid) return q;
            const showDef = q.defOn ? (value === q.defOn) : false;
            return { ...q, value, showDeficiencia: showDef };
        });
    }

    handleObsChange(event) {
        this.observaciones = event.target.value;
    }

    // ─── Save revision ────────────────────────────────────────────────────────

    handleSaveRevision() {
        if (!this.revisionId) return;
        this.savingRevision = true;

        const respuestas = this.formQuestions.map(q => ({
            id:          q.id,
            label:       q.label,
            respuesta:   q.value || '',
            deficiencia: q.showDeficiencia ? q.deficienciaText : null,
        }));

        const datosJSON = JSON.stringify({
            tipo:      this.selectedFormType,
            respuestas,
        });

        saveRevisionData({
            revisionId:      this.revisionId,
            tipoReporte:     this.selectedFormType,
            datosFormulario: datosJSON,
            observaciones:   this.observaciones,
        })
        .then(() => {
            this._loadSAInfo_silent();
            this.currentStep = STEP_DONE;
        })
        .catch(err => {
            this._toast('Error', err.body?.message || 'No se pudo guardar la revisión.', 'error');
        })
        .finally(() => { this.savingRevision = false; });
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    _toDegMin(decimal, isLat) {
        const dir  = isLat ? (decimal >= 0 ? 'N' : 'S') : (decimal >= 0 ? 'E' : 'W');
        const abs  = Math.abs(decimal);
        const deg  = Math.floor(abs);
        const min  = ((abs - deg) * 60).toFixed(3);
        return `${dir}${deg}° ${min}`;
    }

    _formatDate(date) {
        return new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
        }).format(date).replace(',', '');
    }

    _formatDateSpanish(date) {
        const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
        const p = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
        }).formatToParts(date).reduce((a, x) => { a[x.type] = x.value; return a; }, {});
        return `${parseInt(p.day,10)} ${months[parseInt(p.month,10)-1]} ${p.year} ${p.hour}:${p.minute}:${p.second}`;
    }

    _fileTimestamp() {
        const p = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
        }).formatToParts(new Date()).reduce((a, x) => { a[x.type] = x.value; return a; }, {});
        return `${p.year}${p.month}${p.day}_${p.hour}${p.minute}${p.second}`;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}