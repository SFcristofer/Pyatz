import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import saveGeoPhoto     from '@salesforce/apex/GeoPhotoController.saveGeoPhoto';
import getGeoPhotos     from '@salesforce/apex/GeoPhotoController.getGeoPhotos';
import deleteGeoPhoto   from '@salesforce/apex/GeoPhotoController.deleteGeoPhoto';
import getPhotoContent  from '@salesforce/apex/GeoPhotoController.getPhotoContent';
import getWorkOrderInfo from '@salesforce/apex/GeoPhotoController.getWorkOrderInfo';
import { getLocationService } from 'lightning/mobileCapabilities';
import ORG_TIMEZONE  from '@salesforce/i18n/timeZone';

// Configuración del watermark
const STAMP_FONT_SIZE   = 22;
const STAMP_PADDING     = 12;
const STAMP_BG_COLOR    = 'rgba(0, 0, 0, 0.60)';
const STAMP_TEXT_COLOR  = '#FFFFFF';
const STAMP_LINE_HEIGHT = 30;
const MAX_CANVAS_WIDTH  = 1280;

export default class GeoPhotoCapture extends LightningElement {

    @api recordId;
    @api objectApiName;

    @track loadingGps   = true;
    @track gpsReady     = false;
    @track gpsError     = '';
    @track photoReady   = false;
    @track saving       = false;
    @track photos        = [];
    @track loadingPhotos = false;
    @track selectedPhoto = null;
    @track deleting      = false;
    @track confirmDelete = false;
    @track loadingFullPhoto = false;

    coords         = null;
    photoTimestamp = '';
    _imageFile     = null;
    _pendingImg    = null;
    _woInfo        = {};

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._requestGps();
        this._loadGallery();
        this._loadWorkOrderInfo();
    }

    // ─── GPS ──────────────────────────────────────────────────────────────────

    _requestGps() {
        this.loadingGps = true;
        this.gpsReady   = false;
        this.gpsError   = '';

        // 1. Intentar con Mobile API (Field Service compatible)
        try {
            const locationService = getLocationService();

            if (locationService && locationService.isAvailable()) {
                locationService.getCurrentPosition({ enableHighAccuracy: true })
                    .then((result) => {
                        this.coords = {
                            latitude:  result.coords.latitude.toFixed(6),
                            longitude: result.coords.longitude.toFixed(6),
                            accuracy:  Math.round(result.coords.accuracy)
                        };
                        this.gpsReady   = true;
                        this.loadingGps = false;
                    })
                    .catch(() => {
                        // fallback a navegador
                        this._fallbackToBrowserGps();
                    });

                return;
            }
        } catch (e) {
            // fallback
        }

        // 2. Fallback (browser / desktop)
        this._fallbackToBrowserGps();
    }
    _fallbackToBrowserGps() {
        if (!navigator.geolocation) {
            this.loadingGps = false;
            this.gpsError   = 'GPS no disponible en este dispositivo.';
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                this.coords = {
                    latitude:  position.coords.latitude.toFixed(6),
                    longitude: position.coords.longitude.toFixed(6),
                    accuracy:  Math.round(position.coords.accuracy)
                };
                this.gpsReady   = true;
                this.loadingGps = false;
            },
            (error) => {
                this.loadingGps = false;
                this.gpsError   = this._gpsErrorMessage(error);
            },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }
    _gpsErrorMessage(error) {
        switch (error.code) {
            case error.PERMISSION_DENIED:
                return 'Ubicación no disponible (revisa configuración o permisos internos).';
            case error.POSITION_UNAVAILABLE:
                return 'Ubicación no disponible. Intenta en exteriores.';
            case error.TIMEOUT:
                return 'Tiempo agotado al obtener GPS.';
            default:
                return 'No se pudo obtener la ubicación.';
        }
    }

    // ─── Galería ──────────────────────────────────────────────────────────────

    _loadWorkOrderInfo() {
        if (!this.recordId) return;
        getWorkOrderInfo({ recordId: this.recordId })
            .then((data) => { this._woInfo = data || {}; })
            .catch(() => { this._woInfo = {}; });
    }

    _loadGallery() {
        if (!this.recordId) return;
        this.loadingPhotos = true;
        getGeoPhotos({ recordId: this.recordId })
            .then((data) => {
                this.photos = data.map(p => ({
                    ...p,
                    thumbSrc: p.thumbBase64 ? `data:image/jpeg;base64,${p.thumbBase64}` : null
                }));
            })
            .catch(() => {
                // Galería no crítica — falla silenciosa
            })
            .finally(() => {
                this.loadingPhotos = false;
            });
    }

    handlePhotoClick(event) {
        const id = event.currentTarget.dataset.id;
        const photo = this.photos.find(p => p.id === id);
        if (!photo) return;
        this.selectedPhoto     = { ...photo, fullSrc: null };
        this.loadingFullPhoto  = true;
        getPhotoContent({ contentVersionId: photo.id })
            .then(base64 => {
                this.selectedPhoto = { ...this.selectedPhoto, fullSrc: `data:image/jpeg;base64,${base64}` };
            })
            .catch(() => {
                this.selectedPhoto = { ...this.selectedPhoto, fullSrc: photo.thumbSrc };
            })
            .finally(() => { this.loadingFullPhoto = false; });
    }

    handleCloseModal() {
        this.selectedPhoto = null;
        this.confirmDelete = false;
    }

    handleDownload() {
        const src      = this.selectedPhoto && this.selectedPhoto.fullSrc;
        const filename = (this.selectedPhoto && this.selectedPhoto.title) || 'GeoFoto.jpg';
        if (!src || !src.includes('base64,')) return;

        const blob = this._base64ToBlob(src.split('base64,')[1]);

        // Web Share API — panel nativo Android (guardar en galería, WhatsApp, etc.)
        if (navigator.share) {
            const file       = new File([blob], filename, { type: 'image/jpeg' });
            const shareData  = { files: [file], title: filename };
            if (navigator.canShare && navigator.canShare(shareData)) {
                navigator.share(shareData).catch(() => this._blobDownload(blob, filename));
                return;
            }
        }
        this._blobDownload(blob, filename);
    }

    _base64ToBlob(base64) {
        const binary = atob(base64);
        const bytes  = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        return new Blob([bytes], { type: 'image/jpeg' });
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

    handleDeleteClick() {
        this.confirmDelete = true;
    }

    handleDeleteCancel() {
        this.confirmDelete = false;
    }

    handleDeleteConfirm() {
        this.deleting = true;
        deleteGeoPhoto({ contentVersionId: this.selectedPhoto.id })
            .then(() => {
                this._toast('Eliminada', 'La foto fue eliminada correctamente.', 'success');
                this.selectedPhoto = null;
                this.confirmDelete = false;
                this._loadGallery();
            })
            .catch((error) => {
                this._toast('Error', error.body?.message || 'No se pudo eliminar la foto.', 'error');
            })
            .finally(() => {
                this.deleting = false;
            });
    }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get gpsLabel() {
        if (!this.coords) return '';
        return `${this.coords.latitude}, ${this.coords.longitude}  ±${this.coords.accuracy}m`;
    }

    get captureDisabled() {
        return this.loadingGps || !this.gpsReady;
    }

    get saveLabel() {
        return this.saving ? 'Guardando...' : 'Guardar Foto';
    }

    get hasPhotos() {
        return this.photos && this.photos.length > 0;
    }

    get showModal() {
        return this.selectedPhoto !== null;
    }

    get deleteLabel() {
        return this.deleting ? 'Eliminando...' : 'Eliminar';
    }

    get photoCount() {
        return this.photos.length;
    }

    // ─── Handlers captura ─────────────────────────────────────────────────────

    handleCaptureClick() {
        this.template.querySelector('[data-id="cameraInput"]').click();
    }

    handlePhotoSelected(event) {
        const file = event.target.files[0];
        if (!file) return;
        this._imageFile = file;
        this._stampAndPreview(file);
    }

    handleRetake() {
        this.photoReady = false;
        this._imageFile = null;
        const input = this.template.querySelector('[data-id="cameraInput"]');
        if (input) input.value = '';
    }

    handleSave() {
        if (!this.recordId) {
            this._toast('Error', 'No se encontró el Id del registro.', 'error');
            return;
        }
        this._uploadPhoto();
    }

    // ─── Canvas ───────────────────────────────────────────────────────────────

    _stampAndPreview(file) {
        const reader = new FileReader();
        reader.onload = (e) => {
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
        this._drawStamp(ctx, canvas.width, canvas.height);
    }

    _drawStamp(ctx, canvasWidth, canvasHeight) {
        const now   = new Date();
        const info  = this._woInfo || {};
        const idx   = this.photos.length + 1;

        const techStamp = info.techInitials && info.techName
            ? `[${info.techInitials}] ${info.techName}`
            : '';

        const lines = [
            this._formatDateSpanish(now),
            `${this._toDegMin(parseFloat(this.coords.latitude), true)}, ${this._toDegMin(parseFloat(this.coords.longitude), false)}`,
            info.street      || '',
            info.city        || '',
            info.state       || '',
            info.accountName || '',
            info.companyName || '',
            info.workOrderNumber ? `#${info.workOrderNumber}` : '',
            techStamp,
            `Número de índice: ${idx}`
        ].filter(l => l.trim() !== '');

        const FONT_SIZE   = Math.max(18, Math.round(canvasWidth * 0.022));
        const LINE_H      = Math.round(FONT_SIZE * 1.55);
        const PAD         = Math.round(FONT_SIZE * 0.7);

        ctx.font = `bold ${FONT_SIZE}px Arial, sans-serif`;

        const maxW   = lines.reduce((m, l) => Math.max(m, ctx.measureText(l).width), 0);
        const blockW = maxW + PAD * 2;
        const blockH = lines.length * LINE_H + PAD;
        const x      = canvasWidth - blockW - PAD;          // anclado a la derecha
        const y      = canvasHeight - blockH - PAD;         // anclado abajo

        // Fondo semitransparente lado derecho
        ctx.fillStyle = 'rgba(0,0,0,0.52)';
        ctx.beginPath();
        ctx.roundRect(x - PAD * 0.3, y - PAD * 0.3, blockW + PAD * 0.6, blockH + PAD * 0.6, 8);
        ctx.fill();

        // Texto amarillo alineado a la derecha
        ctx.fillStyle = '#FFD700';
        ctx.textAlign = 'right';
        lines.forEach((line, i) => {
            ctx.fillText(line, canvasWidth - PAD, y + PAD + LINE_H * (i + 1) - 4);
        });
        ctx.textAlign = 'left'; // reset
    }

    // ─── Upload ───────────────────────────────────────────────────────────────

    _makeThumbnail(canvas) {
        const MAX_THUMB = 320;
        const scale     = Math.min(1, MAX_THUMB / Math.max(canvas.width, canvas.height));
        const tw        = Math.round(canvas.width  * scale);
        const th        = Math.round(canvas.height * scale);
        const thumb     = document.createElement('canvas');
        thumb.width     = tw;
        thumb.height    = th;
        thumb.getContext('2d').drawImage(canvas, 0, 0, tw, th);
        return thumb.toDataURL('image/jpeg', 0.70).split(',')[1];
    }

    _uploadPhoto() {
        this.saving = true;

        const canvas   = this.template.querySelector('[data-id="photoCanvas"]');
        const base64   = canvas.toDataURL('image/jpeg', 0.90).split(',')[1];
        const base64Thumb = this._makeThumbnail(canvas);
        const filename = `GeoFoto_${this._fileTimestamp()}.jpg`;

        saveGeoPhoto({
            recordId:     this.recordId,
            base64:       base64,
            base64Thumb:  base64Thumb,
            filename:     filename,
            latitude:     this.coords ? parseFloat(this.coords.latitude) : null,
            longitude:    this.coords ? parseFloat(this.coords.longitude) : null,
            accuracy:     this.coords ? this.coords.accuracy : null
        })
        .then(() => {
            this._toast('Éxito', 'Foto guardada con coordenadas GPS.', 'success');
            this.handleRetake();
            this._loadGallery();
            this.dispatchEvent(new CloseActionScreenEvent());
        })
        .catch((error) => {
            this._toast('Error', error.body?.message || 'No se pudo guardar la foto.', 'error');
        })
        .finally(() => {
            this.saving = false;
        });
    }

    // ─── Utilidades ───────────────────────────────────────────────────────────

    _formatDate(date) {
        const fmt = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit',
            hour12: false
        });
        return fmt.format(date).replace(',', '');
    }

    _formatDateSpanish(date) {
        const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
        const parts  = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit',
            hour12: false
        }).formatToParts(date).reduce((a, p) => { a[p.type] = p.value; return a; }, {});
        return `${parseInt(parts.day, 10)} ${months[parseInt(parts.month,10)-1]} ${parts.year} ${parts.hour}:${parts.minute}:${parts.second}`;
    }

    // Convierte decimal a grados° minutos.mmm  con prefijo N/S/E/W
    _toDegMin(decimal, isLat) {
        const dir     = isLat ? (decimal >= 0 ? 'N' : 'S') : (decimal >= 0 ? 'E' : 'W');
        const abs     = Math.abs(decimal);
        const degrees = Math.floor(abs);
        const minutes = ((abs - degrees) * 60).toFixed(3);
        return `${dir}${degrees}° ${minutes}`;
    }

    _fileTimestamp() {
        const fmt = new Intl.DateTimeFormat('en-CA', {
            timeZone: ORG_TIMEZONE,
            year: 'numeric', month: '2-digit', day: '2-digit',
            hour: '2-digit', minute: '2-digit', second: '2-digit',
            hour12: false
        });
        const p = fmt.formatToParts(new Date()).reduce((a, x) => { a[x.type] = x.value; return a; }, {});
        return `${p.year}${p.month}${p.day}_${p.hour}${p.minute}${p.second}`;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}