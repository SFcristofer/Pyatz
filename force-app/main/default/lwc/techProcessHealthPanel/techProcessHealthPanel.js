import { LightningElement, api } from 'lwc';

export default class TechProcessHealthPanel extends LightningElement {
    @api stages = [];
    @api healthJson = '{}';
    @api currentSubPhase = '';

    get healthData() {
        try {
            const history = JSON.parse(this.healthJson || '{}');
            
            return this.stages.map(stage => {
                return {
                    label: stage.label,
                    subStages: stage.subStages.map(sub => {
                        const status = history[sub.label] || 'Pendiente';
                        return {
                            label: sub.label,
                            shortLabel: this.getShortLabel(sub.label),
                            statusClass: this.getStatusClass(sub.label, status),
                            tooltip: `${sub.label}: ${status}`
                        };
                    })
                };
            });
        } catch (e) {
            console.error('Error parsing health JSON', e);
            return [];
        }
    }

    getStatusClass(label, status) {
        if (label === this.currentSubPhase) return 'dot dot-blue';
        
        const s = status.toLowerCase();
        if (['realizado', 'aceptado', 'confirmado', 'enhorabuena'].some(v => s.includes(v))) return 'dot dot-green';
        if (['en proceso', 'pendiente', 'ajuste'].some(v => s.includes(v))) return 'dot dot-yellow';
        if (['rechazado', 'falta información', 'mal'].some(v => s.includes(v))) return 'dot dot-red';
        
        return 'dot dot-gray';
    }

    getShortLabel(label) {
        const maps = {
            'Levantamiento': 'LEV',
            'Memoria': 'MEM',
            'Def. solución': 'SOL',
            'Presupuesto': 'PRE',
            'Envío cotización': 'ENV',
            'Seguimiento': 'SEG',
            'Autorización': 'AUT',
            'Calendario': 'CAL',
            'Contrato': 'CON',
            "Creación ODT's": 'ODT'
        };
        return maps[label] || label.substring(0, 3).toUpperCase();
    }
}