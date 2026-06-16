import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';
import getActionTimeline from '@salesforce/apex/OperationsController.getActionTimeline';
import completeTask from '@salesforce/apex/OperationsController.completeTask';
import rescheduleTaskTomorrow from '@salesforce/apex/OperationsController.rescheduleTaskTomorrow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

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

    getLocalDateString(dateObj) {
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
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
            const dateStr = this.getLocalDateString(d);
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

        const todayStr = this.getLocalDateString(new Date());

        this.events.forEach(event => {
            let eventDateStr = '';
            
            if (event.start && event.start.includes('T')) {
                // Es datetime (Evento o Email) - calcular en hora local
                eventDateStr = this.getLocalDateString(new Date(event.start));
            } else if (event.start) {
                // Es solo fecha (Tarea YYYY-MM-DD)
                eventDateStr = event.start;
            }

            // Mover tareas atrasadas a HOY para que el vendedor las vea
            if (event.isOverdue && !event.isCompleted) {
                eventDateStr = todayStr;
            }

            const dayIndex = this.weekDays.findIndex(d => d.date === eventDateStr);
            
            if (dayIndex !== -1) {
                // Aplicar filtro
                const matchFilter = this.currentView === 'all' || 
                                   (this.currentView === 'call' && event.type === 'Call') ||
                                   (this.currentView === 'task' && (event.type === 'Task' || event.type === 'Email')) ||
                                   (this.currentView === 'event' && event.type === 'Event');

                if (matchFilter) {
                    let formattedTime = '';
                    if (event.isEmail || (!event.isTaskRecord && !event.isEmail && event.start && event.start.includes('T'))) {
                        formattedTime = new Date(event.start).toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
                    }

                    // Definir clases CSS visuales
                    let cardClass = event.colorClass;
                    if (event.isCompleted) cardClass += ' is-completed';
                    if (event.isOverdue) cardClass += ' is-overdue';

                    // Formatear contacto
                    const contactDisplay = event.whoName ? `${event.whoName} ${event.whoPhone ? '📞 ' + event.whoPhone : ''}` : '';

                    this.weekDays[dayIndex].events.push({
                        ...event,
                        time: formattedTime,
                        cardClass: cardClass,
                        contactDisplay: contactDisplay,
                        showActions: event.isTaskRecord && !event.isCompleted
                    });
                }
            }
        });
        this.weekDays = [...this.weekDays];
    }

    async handleCompleteTask(event) {
        const taskId = event.currentTarget.dataset.id;
        try {
            this.isLoading = true;
            await completeTask({ taskId: taskId });
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Tarea completada', variant: 'success' }));
            this.loadData(); // Recargar agenda
        } catch (error) {
            console.error('Error al completar:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo completar la tarea.', variant: 'error' }));
            this.isLoading = false;
        }
    }

    async handleRescheduleTask(event) {
        const taskId = event.currentTarget.dataset.id;
        try {
            this.isLoading = true;
            await rescheduleTaskTomorrow({ taskId: taskId });
            this.dispatchEvent(new ShowToastEvent({ title: 'Éxito', message: 'Tarea reagendada para mañana', variant: 'success' }));
            this.loadData();
        } catch (error) {
            console.error('Error al reagendar:', error);
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'No se pudo reagendar la tarea.', variant: 'error' }));
            this.isLoading = false;
        }
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