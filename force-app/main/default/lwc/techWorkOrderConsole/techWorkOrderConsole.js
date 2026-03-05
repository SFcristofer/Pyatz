import { LightningElement, track, api } from 'lwc';

export default class TechWorkOrderConsole extends LightningElement {
    @api recordId; // ID del Contrato (Quote/Contract)
    
    @track contractFolio = '1731-2026';
    @track woNotes = '';
    @track startDate = '2026-02-13';
    @track endDate = '2027-02-12';

    // Mock Data para el diseño
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
                { id: 'tra1', name: 'AQS-INTIMA17', zonas: 'Zona de prueba' }
            ]
        }
    ];

    daysOfWeek = [
        { label: 'Lunes' }, { label: 'Martes' }, { label: 'Miércoles' },
        { label: 'Jueves' }, { label: 'Viernes' }, { label: 'Sábado' }, { label: 'Domingo' }
    ];

    tecnicosOptions = [
        { label: 'Técnico 1 - Juan Pérez', value: 't1' },
        { label: 'Técnico 2 - María López', value: 't2' }
    ];

    get remainingChars() {
        return 2048 - (this.woNotes ? this.woNotes.length : 0);
    }

    handleNoteChange(event) {
        this.woNotes = event.target.value;
    }

    handleBackToContract() {
        console.log('Navegando de vuelta al contrato...');
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleViewQuote() {
        console.log('Abriendo presupuesto...');
    }

    toggleAccordion(event) {
        const accordionBody = event.currentTarget.nextElementSibling;
        const icon = event.currentTarget.querySelector('lightning-icon[icon-name="utility:chevrondown"], lightning-icon[icon-name="utility:chevronright"]');
        
        if (accordionBody.style.display === 'none') {
            accordionBody.style.display = 'block';
            if (icon) icon.iconName = 'utility:chevrondown';
        } else {
            accordionBody.style.display = 'none';
            if (icon) icon.iconName = 'utility:chevronright';
        }
    }
}
