import { LightningElement, track } from 'lwc';

export default class QuoteTechnicalEditor extends LightningElement {
    @track clausulasValue = '';
    @track currentStep = '1';
    
    // Propiedades del Nuevo Paso 1
    @track estrategiaVenta = '';
    @track necesidadSeleccionada = '';
    @track numeroContrato = '';
    @track contratoManual = false;

    get estrategiaOptions() {
        return [
            { label: 'E1 - Póliza Anual', value: 'E1' },
            { label: 'E2 - Extraordinario', value: 'E2' },
            { label: 'E3 - Cliente Nuevo', value: 'E3' },
            { label: 'E4 - Retardantes', value: 'E4' },
            { label: 'E5 - Cedis', value: 'E5' }
        ];
    }

    get tipoOperacionOptions() {
        return [
            { label: 'Bomberazo (Emergencia)', value: 'bomberazo' },
            { label: 'Servicio Programado', value: 'programado' }
        ];
    }

    // Getters de visibilidad actualizados
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }

    // Columnas para el datatable profesional (Sedes)
    sedesColumns = [
        { label: 'Código', fieldName: 'codigo', type: 'text', initialWidth: 100 },
        { label: 'Nombre Sede', fieldName: 'nombre', type: 'text' },
        { label: 'Contacto', fieldName: 'contacto', type: 'text' },
        { label: 'Teléfono', fieldName: 'telefono', type: 'phone' },
        { label: 'Dirección', fieldName: 'direccion', type: 'text' },
        { label: 'Municipio', fieldName: 'municipio', type: 'text' },
        { label: 'Estado', fieldName: 'estado', type: 'text' }
    ];

    @track sedesData = [
        { id: '1', codigo: 'S-101', nombre: 'Liverpool Polanco', contacto: 'Mariana Silva', telefono: '5512345678', direccion: 'Av. Mariano Escobedo 425', municipio: 'Miguel Hidalgo', estado: 'CDMX' }
    ];
    
    // Columnas Paso 2: Servicios/Artículos
    serviciosColumns = [
        { label: 'Descripción', fieldName: 'descripcion', type: 'text' },
        { label: 'Cantidad', fieldName: 'cantidad', type: 'number' },
        { label: 'Sedes', fieldName: 'sedes', type: 'text' },
        { label: 'Importe Unitario', fieldName: 'importeUnitario', type: 'currency' },
        { label: 'Descuento', fieldName: 'descuento', type: 'percent' },
        { label: 'Impuesto', fieldName: 'impuesto', type: 'text' },
        { label: 'Total sin impuestos', fieldName: 'totalSinImpuestos', type: 'currency' },
        { label: 'Acciones', type: 'action', typeAttributes: { rowActions: [{ label: 'Eliminar', name: 'delete' }] } }
    ];

    // Columnas Paso 2: Totales
    totalesColumns = [
        { label: 'Impuestos', fieldName: 'impuestosNom', type: 'text' },
        { label: 'Base gravable', fieldName: 'base', type: 'currency' },
        { label: 'Impuesto', fieldName: 'valorImpuesto', type: 'currency' },
        { label: 'Retenciones', fieldName: 'retenciones', type: 'currency' },
        { label: 'Total', fieldName: 'total', type: 'currency' }
    ];

    @track serviciosData = [];
    @track totalesData = [];

    // Opciones para Línea de Negocio
    lineaNegocioOptions = [
        { label: 'Ambiental', value: 'Ambiental' },
        { label: 'Cedis', value: 'Cedis' },
        { label: 'ELCLA', value: 'ELCLA' },
        { label: 'eVITER', value: 'eVITER' },
        { label: 'GASTOS', value: 'GASTOS' },
        { label: 'PRESUPUESTOS', value: 'PRESUPUESTOS' },
        { label: 'RESTAURANTES DE FUEGO', value: 'RESTAURANTES DE FUEGO' },
        { label: 'SELLADORES', value: 'SELLADORES' }
    ];

    // Opciones para Plantillas
    templateOptions = [
        { label: 'Plantilla Estándar', value: 'standard' },
        { label: 'Plantilla Industrial', value: 'industrial' },
        { label: 'Plantilla Comercial', value: 'comercial' }
    ];

    @track showModal = false;
    @track isUnitario = true;
    @track isTotal = false;
    @track zonaInput = '';
    @track zonasAfectadas = [];
    @track showIndicaciones = false;

    @track modalTableData = [
        { id: '1', sede: 'Sede Principal', cantidad: 1, importeTotal: 0, totalSinImpuestos: 0, impuestos: 0 }
    ];

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleModalInputChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = parseFloat(event.target.value) || 0;

        this.modalTableData = this.modalTableData.map(row => {
            if (row.id === id) {
                let newRow = { ...row, [field]: value };
                
                if (this.isUnitario) {
                    // Si es modo unitario: Multiplicamos el Importe Total por la cantidad
                    newRow.totalSinImpuestos = newRow.importeTotal * newRow.cantidad;
                } else if (this.isTotal) {
                    // Si es modo total: Dividimos el Importe Total entre la cantidad
                    newRow.totalSinImpuestos = newRow.cantidad !== 0 ? newRow.importeTotal / newRow.cantidad : 0;
                }
                return newRow;
            }
            return row;
        });
    }

    handlePriceType(event) {
        const type = event.target.label;
        if (type === 'UNITARIO') {
            this.isUnitario = true;
            this.isTotal = false;
        } else {
            this.isUnitario = false;
            this.isTotal = true;
        }
        this.recalculateModalData();
    }

    recalculateModalData() {
        this.modalTableData = this.modalTableData.map(row => {
            let newRow = { ...row };
            if (this.isUnitario) {
                newRow.totalSinImpuestos = newRow.importeTotal * newRow.cantidad;
            } else if (this.isTotal) {
                newRow.totalSinImpuestos = newRow.cantidad !== 0 ? newRow.importeTotal / newRow.cantidad : 0;
            }
            return newRow;
        });
    }

    toggleIndicaciones() {
        this.showIndicaciones = !this.showIndicaciones;
    }

    handleZonaInput(event) {
        const value = event.target.value;
        if (value.endsWith(',')) {
            const newZona = value.slice(0, -1).trim();
            if (newZona && !this.zonasAfectadas.includes(newZona)) {
                this.zonasAfectadas = [...this.zonasAfectadas, newZona];
            }
            this.zonaInput = '';
        } else {
            this.zonaInput = value;
        }
    }

    removeZona(event) {
        const zonaToRemove = event.target.dataset.name;
        this.zonasAfectadas = this.zonasAfectadas.filter(z => z !== zonaToRemove);
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }

    get nextButtonLabel() {
        return this.currentStep === '4' ? 'Generar PDF y Finalizar' : 'Siguiente';
    }

    handleCancel() {
        if (this.currentStep === '1') {
            this.dispatchEvent(new CustomEvent('cancel'));
        } else {
            this.currentStep = (parseInt(this.currentStep) - 1).toString();
        }
    }

    handleNext() {
        if (this.currentStep === '4') {
            console.log('Finalizar');
        } else {
            this.currentStep = (parseInt(this.currentStep) + 1).toString();
        }
    }
}