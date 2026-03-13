import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCalendarData from '@salesforce/apex/QuoteTechnicalController.getCalendarData';

export default class TechResourceCalendar extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track resources = [];
    @track appointments = [];
    @track currentDate = new Date();
    @track calendarDays = [];
    @track resourceRows = [];

    // Opciones de visualización
    daysToShow = 14; // Ver dos semanas por defecto

    connectedCallback() {
        this.updateCalendarHeader();
        this.fetchData();
    }

    @api
    refresh() {
        this.fetchData();
    }

    async fetchData() {
        this.isLoading = true;
        try {
            const data = await getCalendarData({ 
                recordId: this.recordId, 
                startDate: this.calendarDays[0].date,
                endDate: this.calendarDays[this.calendarDays.length - 1].date
            });
            this.resources = data.resources;
            this.appointments = data.appointments;
            this.buildResourceRows();
        } catch (error) {
            console.error('Error fetching calendar:', error);
        } finally {
            this.isLoading = false;
        }
    }

    updateCalendarHeader() {
        const start = new Date(this.currentDate);
        const days = [];
        const weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

        for (let i = 0; i < this.daysToShow; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            const isToday = d.toDateString() === new Date().toDateString();
            
            days.push({
                date: d.toISOString().split('T')[0],
                dayNumber: d.getDate(),
                weekday: weekdays[d.getDay()],
                headerClass: isToday ? 'grid-header-cell day-cell today' : 'grid-header-cell day-cell'
            });
        }
        this.calendarDays = days;
    }

    buildResourceRows() {
        this.resourceRows = this.resources.map(res => {
            const rowDays = this.calendarDays.map(day => {
                const dayApps = this.appointments
                    .filter(app => app.ServiceResourceId === res.Id && app.SchedStartTime.startsWith(day.date))
                    .map(app => {
                        const time = new Date(app.SchedStartTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                        let statusClass = 'app-entry ';
                        if (app.Status === 'Completed') statusClass += 'status-done';
                        else if (app.Status === 'Scheduled') statusClass += 'status-pending';
                        else statusClass += 'status-alert';

                        return {
                            ...app,
                            formattedTime: time,
                            cssClass: statusClass
                        };
                    });

                return {
                    date: day.date,
                    appointments: dayApps
                };
            });

            return {
                resourceId: res.Id,
                resourceName: res.Name,
                days: rowDays
            };
        });
    }

    get currentMonthYear() {
        return this.currentDate.toLocaleDateString('es-MX', { month: 'long', year: 'numeric' }).toUpperCase();
    }

    get appointmentStatsLabel() {
        return `${this.appointments.length} Citas en este periodo`;
    }

    // HANDLERS
    handleNextMonth() {
        this.currentDate.setDate(this.currentDate.getDate() + 7);
        this.updateCalendarHeader();
        this.fetchData();
    }

    handlePrevMonth() {
        this.currentDate.setDate(this.currentDate.getDate() - 7);
        this.updateCalendarHeader();
        this.fetchData();
    }

    handleGoToToday() {
        this.currentDate = new Date();
        this.updateCalendarHeader();
        this.fetchData();
    }

    handleAppClick(event) {
        event.stopPropagation();
        const appId = event.currentTarget.dataset.id;
        console.log('Abrir cita:', appId);
        // Aquí podríamos disparar un evento para que el 360 abra el detalle
    }

    handleCellClick(event) {
        const resId = event.currentTarget.dataset.res;
        const date = event.currentTarget.dataset.date;
        console.log('Nueva cita para:', resId, 'en fecha:', date);
    }
}