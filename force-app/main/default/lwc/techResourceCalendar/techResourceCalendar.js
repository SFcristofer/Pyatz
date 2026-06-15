import { LightningElement, api, track, wire } from 'lwc';
import getCalendarData from '@salesforce/apex/OperationsController.getCalendarData';

export default class TechResourceCalendar extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track errorMsg;
    @track resources = [];
    @track appointments = [];
    @track currentDate = new Date();
    @track calendarDays = [];
    @track resourceRows = [];

    @track daysToShow = 7;
    @track currentView = '7';

    get weekButtonVariant() { return this.currentView === '7' ? 'brand' : 'neutral'; }
    get biweekButtonVariant() { return this.currentView === '14' ? 'brand' : 'neutral'; }
    get monthButtonVariant() { return this.currentView === '30' ? 'brand' : 'neutral'; }

    connectedCallback() {
        this.updateCalendarHeader();
        // Ligerísimo delay para asegurar que el componente está listo antes de invocar Apex imperativo.
        // Ayuda a evitar fallos en el first-render donde recordId u otros contextos no están listos.
        setTimeout(() => {
            this.fetchData();
        }, 50);
    }

    @api
    refresh() {
        this.fetchData();
    }

    setViewWeek() {
        this.currentView = '7';
        this.daysToShow = 7;
        this.updateCalendarHeader();
        this.fetchData();
    }

    setView15Days() {
        this.currentView = '14';
        this.daysToShow = 14;
        this.updateCalendarHeader();
        this.fetchData();
    }

    setViewMonth() {
        this.currentView = '30';
        this.daysToShow = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() + 1, 0).getDate();
        this.updateCalendarHeader();
        this.fetchData();
    }

    async fetchData() {
        this.isLoading = true;
        this.errorMsg = undefined;
        try {
            const data = await getCalendarData({ 
                recordId: this.recordId || null, 
                startDate: this.calendarDays[0].date,
                endDate: this.calendarDays[this.calendarDays.length - 1].date
            });
            
            if (data && data.appointments && data.resources) {
                this.appointments = data.appointments.map(app => ({...app, showPopover: false}));
                this.resources = this.processResources(data.resources);
                this.buildResourceRows();
            } else {
                this.errorMsg = 'No se recibió la estructura de datos esperada del servidor.';
            }
        } catch (error) {
            console.error('Error fetching calendar:', error);
            this.errorMsg = error.body && error.body.message ? error.body.message : 'Error al cargar el calendario.';
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
        
        // If view is month, snap to the 1st of the month for better UX
        if (this.currentView === '30') {
            start.setDate(1);
        }

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
                resource: res,
                days: rowDays
            };
        });
    }

    get currentMonthYear() {
        return this.currentDate.toLocaleDateString('es-MX', { month: 'long', year: 'numeric' }).toUpperCase();
    }

    handleShowPopover(event) {
        const appId = event.currentTarget.dataset.id;
        
        // Calcular la posición relativa al contenedor con scroll
        const rect = event.currentTarget.getBoundingClientRect();
        const container = this.template.querySelector('.calendar-scroll-container');
        
        let showBelow = false;
        if (container) {
            const containerRect = container.getBoundingClientRect();
            // Distancia de la tarjeta al borde superior visible del calendario
            const relativeTop = rect.top - containerRect.top;
            showBelow = relativeTop < 200; // Si está a menos de 200px del borde, mostrar abajo
        } else {
            showBelow = rect.top < 350; // Fallback
        }
        
        this.appointments = this.appointments.map(app => ({
            ...app,
            showPopover: app.Id === appId,
            popoverClass: showBelow ? 'modern-popover popover-bottom' : 'modern-popover popover-top'
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
        if (this.currentView === '30') {
            this.currentDate.setMonth(this.currentDate.getMonth() + 1);
            this.currentDate.setDate(1);
        } else {
            this.currentDate.setDate(this.currentDate.getDate() + this.daysToShow);
        }
        this.updateCalendarHeader();
        this.fetchData();
    }

    handlePrevMonth() {
        if (this.currentView === '30') {
            this.currentDate.setMonth(this.currentDate.getMonth() - 1);
            this.currentDate.setDate(1);
        } else {
            this.currentDate.setDate(this.currentDate.getDate() - this.daysToShow);
        }
        this.updateCalendarHeader();
        this.fetchData();
    }

    handleGoToToday() {
        this.currentDate = new Date();
        this.updateCalendarHeader();
        this.fetchData();
    }

    handleViewChange(event) {
        this.currentView = event.detail.value;
        if (this.currentView === '30') {
            this.daysToShow = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() + 1, 0).getDate(); // Get exact days in month
        } else {
            this.daysToShow = parseInt(this.currentView, 10);
        }
        this.updateCalendarHeader();
        this.fetchData();
    }

    get currentDateString() {
        return this.currentDate.toISOString().split('T')[0];
    }

    handleDateJump(event) {
        if (event.detail.value) {
            this.currentDate = new Date(event.detail.value + 'T00:00:00');
            this.updateCalendarHeader();
            this.fetchData();
        }
    }
}