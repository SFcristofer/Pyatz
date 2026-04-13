import { LightningElement, api } from 'lwc';

export default class TechDatatableHealthCell extends LightningElement {
    @api value; // Aquí llega el JSON string

    get defClass() { return this.getMacroStatus(['Levantamiento', 'Memoria']); }
    get costClass() { return this.getMacroStatus(['Def. solución', 'Presupuesto']); }
    get negClass() { return this.getMacroStatus(['Envío cotización', 'Seguimiento']); }
    get cieClass() { return this.getMacroStatus(['Autorización']); }

    getMacroStatus(subPhaseNames) {
        if (!this.value || this.value === '{}') return 'dot dot-gray';
        try {
            const history = JSON.parse(this.value);
            let hasRed = false;
            let hasYellow = false;
            let hasGreen = false;

            subPhaseNames.forEach(name => {
                const status = (history[name] || '').toLowerCase();
                if (['rechazado', 'falta información'].some(v => status.includes(v))) hasRed = true;
                else if (['en proceso', 'pendiente'].some(v => status.includes(v))) hasYellow = true;
                else if (['realizado', 'aceptado', 'confirmado'].some(v => status.includes(v))) hasGreen = true;
            });

            if (hasRed) return 'dot dot-red';
            if (hasYellow) return 'dot dot-yellow';
            if (hasGreen) return 'dot dot-green';
            return 'dot dot-gray';
        } catch (e) { return 'dot dot-gray'; }
    }
}