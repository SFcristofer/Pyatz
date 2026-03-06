import { LightningElement, track, api } from 'lwc';

export default class TechWorkOrderConsole extends LightningElement {
    @api recordId;
    @track contractFolio = '1731-2026';
    @track woNotes = '';
    @track startDate = '2026-02-13';
    @track endDate = '2027-02-12';
    @track showSchedulingSection = false;

    @track contractData = {
        cliente: 'ROBERTO DEPRUEBA',
        lineaNegocio: 'Ambiental',
        sedes: 'DECORACIONES POLANCO',
        fechaInicio: '13-feb-2026',
        fechaPrimerTratamiento: '13-feb-2026',
        tratamientos: 'AQS-INTIMA17, AQS-SENSE',
        fechaFin: '12-feb-2027',
        fechaLimiteServicios: '12-feb-2027'
    };

    @track sedesList = [
        {
            id: 'sede1',
            name: 'DECORACIONES POLANCO',
            tratamientos: [
                { id: 'tra1', name: 'AQS-INTIMA17', zonas: 'Tipo Reporte: Trampa Grasa' }
            ]
        }
    ];

    // TODO: Esta lista debe generarse dinámicamente durante el mapeo.
    // LÓGICA: El número de filas debe ser igual a la 'Cantidad' (Quantity) definida en el QuoteLineItem (Tratamiento).
    @track schedulingRows = [
        { label: '1º Fecha', date: '2026-02-13' },
        { label: '2º Fecha', date: '2026-03-13' },
        { label: '3º Fecha', date: '2026-04-13' }
    ];

    daysOfWeek = [
        { label: 'Lunes' }, { label: 'Martes' }, { label: 'Miércoles' },
        { label: 'Jueves' }, { label: 'Viernes' }, { label: 'Sábado' }, { label: 'Domingo' }
    ];

    tecnicosOptions = [
        { label: 'Técnico 1 - Juan Pérez', value: 't1' },
        { label: 'Técnico 2 - María López', value: 't2' }
    ];

    get timelineTags() {
        return [
            { id: 1, label: '1º Fecha: 13/02', style: 'left: 5%; bottom: 15px;' },
            { id: 2, label: '2º Fecha: 13/03', style: 'left: 25%; bottom: 35px;' }, // Apilado
            { id: 3, label: '3º Fecha: 13/04', style: 'left: 45%; bottom: 15px;' },
            { id: 4, label: '4º Fecha: 13/05', style: 'left: 65%; bottom: 35px;' }  // Apilado
        ];
    }

    get remainingChars() {
        return 2048 - (this.woNotes ? this.woNotes.length : 0);
    }

    handleNoteChange(event) {
        this.woNotes = event.target.value;
    }

    handleBackToContract() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleViewQuote() {
        console.log('Abriendo presupuesto...');
    }

    handleAddCandidateDates() {
        this.showSchedulingSection = !this.showSchedulingSection;
    }

    toggleAccordion(event) {
        const accordionBody = event.currentTarget.nextElementSibling;
        accordionBody.style.display = accordionBody.style.display === 'none' ? 'block' : 'none';
    }
}
