import { LightningElement, api, track, wire } from 'lwc';
import getCalendarData from '@salesforce/apex/QuoteTechnicalController.getCalendarData';

export default class TechResourceCalendar extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track resources = [];
    @track appointments = [];
    @track currentDate = new Date();
    @track calendarDays = [];
    @track resourceRows = [];

    daysToShow = 14;

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
            
            this.appointments = data.appointments.map(app => ({...app, showPopover: false}));
            this.resources = this.processResources(data.resources);
            this.buildResourceRows();
        } catch (error) {
            console.error('Error fetching calendar:', error);
        } finally {
            this.isLoading = false;
        }
    }

    processResources(rawResources) {
        const processed = rawResources.map(res => {
            const todayStr = new Date().toISOString().split('T')[0];
            const todayApps = this.appointments.filter(a => a.ServiceResourceId === res.Id && a.SchedStartTime.startsWith(todayStr));
            const totalHours = todayApps.reduce((sum, a) => sum + (a.Duration || 0), 0);

            let statusColor = 'status-green';
            let statusLabel = 'Disponible';
            if (totalHours > 6) { statusColor = 'status-red'; statusLabel = 'Saturado'; }
            else if (totalHours > 3) { statusColor = 'status-yellow'; statusLabel = 'Ocupado'; }

            return {
                ...res,
                workloadHours: totalHours,
                statusColor: `availability-dot ${statusColor}`,
                statusLabel: statusLabel
            };
        });

        const unassignedRes = { 
            Id: 'UNASSIGNED', 
            Name: 'POR ASIGNAR', 
            ResourceType: 'Trabajo Pendiente',
            RelatedRecord: { SmallPhotoUrl: '' },
            statusColor: 'availability-dot status-gray',
            statusLabel: 'N/A'
        };

        return [unassignedRes, ...processed];
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
                        const startTime = new Date(app.SchedStartTime);
                        const time = startTime.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', hour12: true });
                        
                        let statusClass = 'app-card ';
                        if (app.Status === 'Completed') statusClass += 'status-done';
                        else if (app.Status === 'None' || app.Status === 'Scheduled') statusClass += 'status-pending';
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

    // HANDLERS PARA POPOVER
    handleShowPopover(event) {
        const appId = event.currentTarget.dataset.id;
        this.appointments = this.appointments.map(app => ({
            ...app,
            showPopover: app.Id === appId
        }));
        this.buildResourceRows();
    }

    handleHidePopover() {
        this.appointments = this.appointments.map(app => ({
            ...app,
            showPopover: false
        }));
        this.buildResourceRows();
    }

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
}