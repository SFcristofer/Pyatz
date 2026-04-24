import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';
import getActionTimeline from '@salesforce/apex/OperationsController.getActionTimeline';

export default class TechCalendarModal extends LightningModal {
    @api recordId;
    @track isLoading = false;
    @track events = [];
    @track weekDays = [];
    @track currentView = 'all';
    @track startDate = new Date();

    get filterOptions() {
        return [
            { label: 'Todo', value: 'all' },
            { label: 'Llamadas', value: 'call' },
            { label: 'Tareas', value: 'task' },
            { label: 'Eventos', value: 'event' }
        ];
    }

    connectedCallback() {
        this.buildWeek();
        this.loadData();
    }

    buildWeek() {
        const days = [];
        const start = new Date(this.startDate);
        // Ajustar al lunes de la semana actual
        const day = start.getDay();
        const diff = start.getDate() - day + (day === 0 ? -6 : 1);
        start.setDate(diff);

        const options = { weekday: 'short', day: 'numeric', month: 'short' };
        
        for (let i = 0; i < 7; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            const dateStr = d.toISOString().split('T')[0];
            days.push({
                date: dateStr,
                label: d.toLocaleDateString('es-MX', options),
                isToday: d.toDateString() === new Date().toDateString(),
                columnClass: d.toDateString() === new Date().toDateString() ? 'day-column day-column-today' : 'day-column',
                events: []
            });
        }
        this.weekDays = days;
    }

    async loadData() {
        this.isLoading = true;
        try {
            const data = await getActionTimeline({ opportunityId: this.recordId });
            this.events = data;
            this.mapEventsToDays();
        } catch (error) {
            console.error('Error loading data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    mapEventsToDays() {
        // Limpiar eventos previos en los días
        this.weekDays = this.weekDays.map(day => ({ ...day, events: [] }));

        this.events.forEach(event => {
            const eventDate = new Date(event.start).toISOString().split('T')[0];
            const dayIndex = this.weekDays.findIndex(d => d.date === eventDate);
            
            if (dayIndex !== -1) {
                // Aplicar filtro
                const matchFilter = this.currentView === 'all' || 
                                   (this.currentView === 'call' && event.type === 'Call') ||
                                   (this.currentView === 'task' && (event.type === 'Task' || event.type === 'Email')) ||
                                   (this.currentView === 'event' && event.type === 'Event');

                if (matchFilter) {
                    const formattedTime = new Date(event.start).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
                    this.weekDays[dayIndex].events.push({
                        ...event,
                        time: formattedTime
                    });
                }
            }
        });
        this.weekDays = [...this.weekDays];
    }

    handleFilterChange(event) {
        this.currentView = event.target.value;
        this.mapEventsToDays();
    }

    handlePrevWeek() {
        this.startDate.setDate(this.startDate.getDate() - 7);
        this.buildWeek();
        this.mapEventsToDays();
    }

    handleNextWeek() {
        this.startDate.setDate(this.startDate.getDate() + 7);
        this.buildWeek();
        this.mapEventsToDays();
    }

    handleToday() {
        this.startDate = new Date();
        this.buildWeek();
        this.mapEventsToDays();
    }

    handleClose() {
        this.close('okay');
    }
}