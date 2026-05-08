import { LightningElement, api, track, wire } from 'lwc';
import getInspectionData from '@salesforce/apex/SurveyService.getInspectionData';
import getInspectionQuestions from '@salesforce/apex/SurveyService.getInspectionQuestions';
import saveInspectionResult from '@salesforce/apex/SurveyService.saveInspectionResult';
import tagLatestPhotos from '@salesforce/apex/SurveyService.tagLatestPhotos';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TechMobileAuditor extends LightningElement {
    @api recordId; // Service Appointment ID

    @track isLoading = true;
    @track isSaving = false;
    @track currentStep = 1;

    // Datos de la Cita
    saNumber = '';
    reportTitle = 'Reporte Técnico';
    reportType = '';
    
    @track questions = [];
    
    @wire(getInspectionData, { saId: '$recordId' })
    wiredSA({ error, data }) {
        if (data) {
            console.log('--- Datos Recibidos en Móvil:', JSON.stringify(data));
            this.saNumber = data.saNumber || '';
            this.reportTitle = data.saSubject || 'Reporte Técnico';
            this.reportType = data.reportType;
            
            if (this.reportType) {
                this.loadQuestions();
            } else {
                this.isLoading = false;
                this.reportTitle = 'Sin Plantilla';
                // Si no hay tipo de reporte, no hay preguntas que cargar
                this.questions = [];
            }
        } else if (error) {
            console.error('Error cargando datos de la cita:', error);
            this.isLoading = false;
            this.reportTitle = 'Error de Conexión';
        }
    }

    loadQuestions() {
        getInspectionQuestions({ serviceType: this.reportType })
            .then(data => {
                this.questions = data.map(q => ({
                    ...q,
                    answer: '',
                    yesVariant: 'neutral',
                    noVariant: 'neutral',
                    showDeficiency: false
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
            });
    }

    handleAnswer(event) {
        const idx = event.target.dataset.index;
        const val = event.target.dataset.val;
        this.questions = this.questions.map((q, i) => {
            if (i == idx) {
                const isCorrect = (val === q.expected);
                return {
                    ...q,
                    answer: val,
                    yesVariant: val === 'Si' ? 'success' : 'neutral',
                    noVariant: val === 'No' ? 'destructive' : 'neutral',
                    showDeficiency: !isCorrect
                };
            }
            return q;
        });
    }

    async handleNext() {
        if (this.currentStep === 1) await this.tagPhotos('ANTES');
        if (this.currentStep === 3) await this.tagPhotos('DESPUES');
        if (this.currentStep < 4) this.currentStep++;
    }

    async tagPhotos(tag) {
        try {
            await tagLatestPhotos({ recordId: this.recordId, tag: tag });
        } catch (e) { console.error('Error etiquetando fotos:', e); }
    }

    handlePrev() { if (this.currentStep > 1) this.currentStep--; }

    handleSaveAll() {
        this.isSaving = true;
        const deficiencies = this.questions
            .filter(q => q.showDeficiency)
            .map(q => `[${this.reportType}] ${q.deficiency}`)
            .join('\n\n');

        saveInspectionResult({
            saId: this.recordId,
            payloadJson: JSON.stringify(this.questions),
            deficiencies: deficiencies
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Reporte técnico guardado correctamente.',
                variant: 'success'
            }));
            this.isSaving = false;
        })
        .catch(error => {
            this.isSaving = false;
        });
    }

    // Clases dinámicas para UI
    get isStepBefore() { return this.currentStep === 1; }
    get isStepChecklist() { return this.currentStep === 2; }
    get isStepAfter() { return this.currentStep === 3; }
    get isStepSignature() { return this.currentStep === 4; }

    get step1Class() { return `step ${this.currentStep >= 1 ? 'active' : ''}`; }
    get step2Class() { return `step ${this.currentStep >= 2 ? 'active' : ''}`; }
    get step3Class() { return `step ${this.currentStep >= 3 ? 'active' : ''}`; }
    get step4Class() { return `step ${this.currentStep >= 4 ? 'active' : ''}`; }
}