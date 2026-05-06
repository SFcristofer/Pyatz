import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import ORG_TIMEZONE          from '@salesforce/i18n/timeZone';
import saveSignaturePair     from '@salesforce/apex/ClientSignatureController.saveSignaturePair';
import getSignatures         from '@salesforce/apex/ClientSignatureController.getSignatures';
import getSignatureContent   from '@salesforce/apex/ClientSignatureController.getSignatureContent';
import deleteSignature       from '@salesforce/apex/ClientSignatureController.deleteSignature';
import getWorkOrderInfo      from '@salesforce/apex/GeoPhotoController.getWorkOrderInfo';

const STATE_IDLE    = 'idle';
const STATE_SIGNING = 'signing';
const STATE_PREVIEW = 'preview';

const INK_COLOR      = '#1a1a2e';
const INK_WIDTH      = 3;
const STAMP_BG       = '#f5f5f5';
const STAMP_ACCENT   = '#0176d3';
const STAMP_H_RATIO  = 0.32;

export default class ClientSignature extends LightningElement {

    @api recordId;
    @api objectApiName;

    @track state             = STATE_IDLE;
    @track signerName        = '';
    @track canvasEmpty       = true;
    @track saving            = false;
    @track loadingSignatures = false;
    @track signatures        = [];
    @track selectedSig       = null;
    @track confirmDelete     = false;
    @track deleting          = false;
    @track loadingFullSig    = false;
    @track gpsReady          = false;
    @track gpsLabel          = 'Obteniendo GPS...';

    _woInfo          = {};
    _coords          = null;
    _drawing         = false;
    _lastX           = 0;
    _lastY           = 0;
    _canvasReady     = false;
    _previewRendered = false;
    _cleanBase64     = null;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadGallery();
        this._loadWoInfo();
    }

    renderedCallback() {
        if (this.stateSigning && !this._canvasReady) {
            this._initSignCanvas();
        }
        if (this.statePreview && !this._previewRendered) {
            this._renderPreview();
            this._previewRendered = true;
        }
    }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get stateIdle()    { return this.state === STATE_IDLE; }
    get stateSigning() { return this.state === STATE_SIGNING; }
    get statePreview() { return this.state === STATE_PREVIEW; }

    get nameEmpty()      { return !this.signerName || !this.signerName.trim(); }
    get hasSignatures()  { return this.signatures && this.signatures.length > 0; }
    get signatureCount() { return this.signatures.length; }
    get showModal()           { return this.selectedSig !== null; }
    get saveLabel()           { return this.saving   ? 'Guardando...'  : 'Guardar Firma'; }
    get deleteLabel()         { return this.deleting ? 'Eliminando...' : 'Eliminar'; }
    get hasCleanVersion()     { return this.selectedSig && !!this.selectedSig.cleanDownloadUrl; }
    get selectedCleanUrl()    { return this.selectedSig ? this.selectedSig.cleanDownloadUrl : ''; }
    get selectedCleanId()     { return this.selectedSig ? this.selectedSig.cleanId : ''; }

    get gpsStatusClass() {
        return this.gpsReady ? 'gps-pill gps-pill--ok' : 'gps-pill gps-pill--loading';
    }

    // ─── Datos ────────────────────────────────────────────────────────────────

    _loadWoInfo() {
        if (!this.recordId) return;
        getWorkOrderInfo({ recordId: this.recordId })
            .then(data => { this._woInfo = data || {}; })
            .catch(() => { this._woInfo = {}; });
    }

    _loadGallery() {
        if (!this.recordId) return;
        this.loadingSignatures = true;
        getSignatures({ recordId: this.recordId })
            .then(data => {
                this.signatures = data.map(s => ({
                    ...s,
                    thumbSrc: s.thumbBase64 ? `data:image/png;base64,${s.thumbBase64}` : null
                }));
            })
            .catch(() => {})
            .finally(() => { this.loadingSignatures = false; });
    }

    _requestGps() {
        this.gpsReady = false;
        this.gpsLabel = 'Obteniendo GPS...';
        this._coords  = null;

        if (!navigator.geolocation) {
            this.gpsLabel = 'GPS no disponible';
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                this._coords  = {
                    latitude:  pos.coords.latitude.toFixed(6),
                    longitude: pos.coords.longitude.toFixed(6),
                    accuracy:  Math.round(pos.coords.accuracy)
                };
                this.gpsReady = true;
                this.gpsLabel = `${this._toDegMin(parseFloat(this._coords.latitude), true)}, ${this._toDegMin(parseFloat(this._coords.longitude), false)}  ±${this._coords.accuracy}m`;
            },
            () => { this.gpsLabel = 'Ubicación no disponible'; },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }

    // ─── Navegación ───────────────────────────────────────────────────────────

    handleNameChange(event) { this.signerName = event.target.value; }

    handleGoSign() {
        this._canvasReady     = false;
        this._previewRendered = false;
        this._cleanBase64     = null;
        this.canvasEmpty      = true;
        this._requestGps();
        this.state = STATE_SIGNING;
    }

    handleBackToIdle() {
        this.state        = STATE_IDLE;
        this._canvasReady = false;
    }

    handleClear() {
        const canvas = this.template.querySelector('[data-id="signCanvas"]');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        this.canvasEmpty = true;
    }

    handleConfirmSign() {
        // Capturar imagen limpia ANTES de cambiar de estado
        const signCanvas = this.template.querySelector('[data-id="signCanvas"]');
        if (signCanvas) {
            this._cleanBase64 = signCanvas.toDataURL('image/png').split(',')[1];
        }
        this._previewRendered = false;
        this.state = STATE_PREVIEW;
    }

    handleRetry() {
        this._canvasReady     = false;
        this._previewRendered = false;
        this._cleanBase64     = null;
        this.canvasEmpty      = true;
        this.state = STATE_SIGNING;
    }

    // ─── Canvas de firma ──────────────────────────────────────────────────────

    _initSignCanvas() {
        const canvas = this.template.querySelector('[data-id="signCanvas"]');
        if (!canvas) return;
        this._canvasReady = true;

        const dpr  = window.devicePixelRatio || 1;
        const rect = canvas.getBoundingClientRect();
        const w    = rect.width  || 360;
        const h    = rect.height || 260;

        canvas.width  = w * dpr;
        canvas.height = h * dpr;
        canvas.style.width  = w + 'px';
        canvas.style.height = h + 'px';

        const ctx = canvas.getContext('2d');
        ctx.scale(dpr, dpr);
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, w, h);

        canvas.addEventListener('touchstart', (e) => { e.preventDefault(); this._startDraw(e.touches[0], canvas); }, { passive: false });
        canvas.addEventListener('touchmove',  (e) => { e.preventDefault(); this._draw(e.touches[0], canvas); },      { passive: false });
        canvas.addEventListener('touchend',   (e) => { e.preventDefault(); this._endDraw(); },                        { passive: false });
        canvas.addEventListener('mousedown',  (e) => this._startDraw(e, canvas));
        canvas.addEventListener('mousemove',  (e) => this._draw(e, canvas));
        canvas.addEventListener('mouseup',    () => this._endDraw());
        canvas.addEventListener('mouseleave', () => this._endDraw());
    }

    _getPos(pointer, canvas) {
        const rect = canvas.getBoundingClientRect();
        return { x: pointer.clientX - rect.left, y: pointer.clientY - rect.top };
    }

    _startDraw(pointer, canvas) {
        this._drawing = true;
        const pos = this._getPos(pointer, canvas);
        this._lastX = pos.x;
        this._lastY = pos.y;
    }

    _draw(pointer, canvas) {
        if (!this._drawing) return;
        const ctx = canvas.getContext('2d');
        const pos = this._getPos(pointer, canvas);

        ctx.beginPath();
        ctx.moveTo(this._lastX, this._lastY);
        ctx.lineTo(pos.x, pos.y);
        ctx.strokeStyle = INK_COLOR;
        ctx.lineWidth   = INK_WIDTH;
        ctx.lineCap     = 'round';
        ctx.lineJoin    = 'round';
        ctx.stroke();

        this._lastX      = pos.x;
        this._lastY      = pos.y;
        this.canvasEmpty = false;
    }

    _endDraw() { this._drawing = false; }

    // ─── Preview con bloque de información ───────────────────────────────────

    _renderPreview() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const preview = this.template.querySelector('[data-id="previewCanvas"]');
            if (!preview || !this._cleanBase64) return;

            const img = new Image();
            img.onload = () => {
                const sigW = img.width;
                const sigH = img.height;

                // Calcular altura del stamp según número real de filas
                const info      = this._woInfo || {};
                const FONT      = Math.max(13, Math.round(sigW * 0.026));
                const LINE_H    = Math.round(FONT * 1.7);
                const PAD       = Math.round(FONT * 1.0);
                const rowCount  = this._getStampRows(info).length;
                const stampH    = PAD + Math.round(LINE_H * 1.2) + LINE_H * rowCount + PAD;

                preview.width  = sigW;
                preview.height = sigH + stampH;

                const ctx = preview.getContext('2d');

                // 1. Firma limpia
                ctx.drawImage(img, 0, 0, sigW, sigH);

                // 2. Línea divisora
                ctx.strokeStyle = '#cccccc';
                ctx.lineWidth   = 1;
                ctx.beginPath();
                ctx.moveTo(0, sigH);
                ctx.lineTo(sigW, sigH);
                ctx.stroke();

                // 3. Bloque de información
                this._drawStamp(ctx, sigW, sigH, stampH, FONT, LINE_H, PAD);
            };
            img.src = 'data:image/png;base64,' + this._cleanBase64;
        }, 0);
    }

    _getStampRows(info) {
        const coordText = this._coords
            ? `${this._toDegMin(parseFloat(this._coords.latitude), true)}, ${this._toDegMin(parseFloat(this._coords.longitude), false)}  ±${this._coords.accuracy}m`
            : 'No disponible';

        const techLabel = info.techInitials && info.techName
            ? `[${info.techInitials}] ${info.techName}`
            : '';

        return [
            ['Firmante:',  this.signerName],
            ['Fecha:',     this._formatDateSpanish(new Date())],
            ['GPS:',       coordText],
            info.workOrderNumber ? ['Orden:',    `#${info.workOrderNumber}`] : null,
            info.accountName     ? ['Cliente:',  info.accountName]           : null,
            info.companyName     ? ['Empresa:',  info.companyName]           : null,
            techLabel            ? ['Técnico:',  techLabel]                  : null
        ].filter(r => r !== null);
    }

    _drawStamp(ctx, w, sigH, stampH, FONT, LINE_H, PAD) {
        const info = this._woInfo || {};
        const COL  = Math.round(FONT * 5.5);

        // Fondo
        ctx.fillStyle = STAMP_BG;
        ctx.fillRect(0, sigH, w, stampH);

        // Barra de acento superior
        ctx.fillStyle = STAMP_ACCENT;
        ctx.fillRect(0, sigH, w, 4);

        // Encabezado
        ctx.font      = `bold ${Math.round(FONT * 0.9)}px Arial, sans-serif`;
        ctx.fillStyle = STAMP_ACCENT;
        ctx.fillText('FIRMA DIGITAL VERIFICADA', PAD, sigH + PAD + LINE_H * 0.75);

        // Filas
        const rows = this._getStampRows(info);
        rows.forEach((row, i) => {
            const yBase = sigH + PAD + LINE_H * (i + 1.75);

            ctx.font      = `bold ${FONT}px Arial, sans-serif`;
            ctx.fillStyle = '#666666';
            ctx.fillText(row[0], PAD, yBase);

            ctx.font      = `${FONT}px Arial, sans-serif`;
            ctx.fillStyle = '#111111';
            ctx.fillText(row[1], PAD + COL, yBase, w - PAD - COL);
        });
    }

    // ─── Guardar par de imágenes ──────────────────────────────────────────────

    handleSave() {
        if (!this.recordId) {
            this._toast('Error', 'No se encontró el Id del registro.', 'error');
            return;
        }
        const preview = this.template.querySelector('[data-id="previewCanvas"]');
        if (!preview || !this._cleanBase64) {
            this._toast('Error', 'No se pudo generar la imagen.', 'error');
            return;
        }

        this.saving = true;
        const ts          = this._fileTimestamp();
        const safeName    = this.signerName.replace(/\s+/g, '_');
        const infoBase64  = preview.toDataURL('image/png').split(',')[1];
        const thumbBase64 = this._makeThumb(preview);

        saveSignaturePair({
            recordId:      this.recordId,
            base64Clean:   this._cleanBase64,
            base64Info:    infoBase64,
            base64Thumb:   thumbBase64,
            filenameClean: `SignClean_${safeName}_${ts}.png`,
            filenameInfo:  `Firma_${safeName}_${ts}.png`,
            signerName:    this.signerName
        })
        .then(() => {
            this._toast('Firma guardada', `Firma de ${this.signerName} registrada correctamente.`, 'success');
            this.state        = STATE_IDLE;
            this.signerName   = '';
            this._canvasReady = false;
            this._cleanBase64 = null;
            this._loadGallery();
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch(err => {
            this._toast('Error', err.body?.message || 'No se pudo guardar la firma.', 'error');
        })
        .finally(() => { this.saving = false; });
    }

    // ─── Modal ────────────────────────────────────────────────────────────────

    handleSigClick(event) {
        const id  = event.currentTarget.dataset.id;
        const sig = this.signatures.find(s => s.id === id);
        if (!sig) return;
        this.selectedSig      = { ...sig, fullSrc: null };
        this.confirmDelete    = false;
        this.loadingFullSig   = true;
        getSignatureContent({ contentVersionId: sig.id })
            .then(base64 => {
                this.selectedSig = { ...this.selectedSig, fullSrc: `data:image/png;base64,${base64}` };
            })
            .catch(() => {
                this.selectedSig = { ...this.selectedSig, fullSrc: sig.thumbSrc };
            })
            .finally(() => { this.loadingFullSig = false; });
    }

    handleDownload() {
        const src      = this.selectedSig && this.selectedSig.fullSrc;
        const filename = (this.selectedSig && this.selectedSig.title) || 'Firma.png';
        if (!src || !src.includes('base64,')) return;

        const blob = this._base64ToBlob(src.split('base64,')[1], 'image/png');

        if (navigator.share) {
            const file      = new File([blob], filename, { type: 'image/png' });
            const shareData = { files: [file], title: filename };
            if (navigator.canShare && navigator.canShare(shareData)) {
                navigator.share(shareData).catch(() => this._blobDownload(blob, filename));
                return;
            }
        }
        this._blobDownload(blob, filename);
    }

    _base64ToBlob(base64, type = 'image/png') {
        const binary = atob(base64);
        const bytes  = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        return new Blob([bytes], { type });
    }

    _blobDownload(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a   = document.createElement('a');
        a.href     = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => URL.revokeObjectURL(url), 100);
    }

    handleCloseModal()   { this.selectedSig = null; this.confirmDelete = false; }
    handleDeleteClick()  { this.confirmDelete = true; }
    handleDeleteCancel() { this.confirmDelete = false; }

    handleDeleteConfirm() {
        this.deleting = true;
        deleteSignature({
            contentVersionId: this.selectedSig.id,
            cleanVersionId:   this.selectedSig.cleanId || ''
        })
            .then(() => {
                this._toast('Eliminada', 'La firma fue eliminada.', 'success');
                this.selectedSig   = null;
                this.confirmDelete = false;
                this._loadGallery();
            })
            .catch(err => {
                this._toast('Error', err.body?.message || 'No se pudo eliminar.', 'error');
            })
            .finally(() => { this.deleting = false; });
    }

    // ─── Utilidades ───────────────────────────────────────────────────────────

    _makeThumb(canvas) {
        const MAX   = 320;
        const scale = Math.min(1, MAX / Math.max(canvas.width, canvas.height));
        const tw    = Math.round(canvas.width  * scale);
        const th    = Math.round(canvas.height * scale);
        const thumb = document.createElement('canvas');
        thumb.width  = tw;
        thumb.height = th;
        thumb.getContext('2d').drawImage(canvas, 0, 0, tw, th);
        return thumb.toDataURL('image/png', 0.70).split(',')[1];
    }

    _toDegMin(decimal, isLat) {
        const dir     = isLat ? (decimal >= 0 ? 'N' : 'S') : (decimal >= 0 ? 'E' : 'W');
        const abs     = Math.abs(decimal);
        const degrees = Math.floor(abs);
        const minutes = ((abs - degrees) * 60).toFixed(3);
        return `${dir}${degrees}° ${minutes}`;
    }

    _formatDateSpanish(date) {
        const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
        const p = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit',
            hour12: false
        }).formatToParts(date).reduce((a, x) => { a[x.type] = x.value; return a; }, {});
        return `${parseInt(p.day,10)} ${months[parseInt(p.month,10)-1]} ${p.year} ${p.hour}:${p.minute}:${p.second}`;
    }

    _fileTimestamp() {
        const p = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit',
            hour12: false
        }).formatToParts(new Date()).reduce((a, x) => { a[x.type] = x.value; return a; }, {});
        return `${p.year}${p.month}${p.day}_${p.hour}${p.minute}${p.second}`;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}