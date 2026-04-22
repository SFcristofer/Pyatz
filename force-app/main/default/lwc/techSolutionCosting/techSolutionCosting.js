import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpportunitySolutions from '@salesforce/apex/SurveyController.getOpportunitySolutions';
import saveSolucion from '@salesforce/apex/SurveyController.saveSolucion';

export default class TechSolutionCosting extends LightningElement {
    @api recordId; // Opportunity ID
    @track groupedSolutions = [];
    @track selectedSolId = null;
    @track selectedSolName = '';
    @track techDesc = '';
    @track commObs = '';
    @track isSaving = false;

    connectedCallback() {
        this.loadSolutions();
    }

    loadSolutions() {
        getOpportunitySolutions({ oppId: this.recordId })
            .then(result => {
                this.groupedSolutions = result.map(group => ({
                    ...group,
                    solutions: group.solutions.map(sol => ({
                        ...sol,
                        className: sol.id === this.selectedSolId ? 'sol-card active-sol' : 'sol-card'
                    }))
                }));
            })
            .catch(error => console.error('Error load solutions:', error));
    }

    handleSolSelect(event) {
        const solId = event.currentTarget.dataset.id;
        this.selectedSolId = solId;
        
        // Buscar datos de la solución seleccionada
        this.groupedSolutions.forEach(group => {
            group.solutions.forEach(sol => {
                sol.className = sol.id === solId ? 'sol-card active-sol' : 'sol-card';
                if (sol.id === solId) {
                    this.selectedSolName = sol.name;
                    this.techDesc = sol.techDesc;
                    this.commObs = sol.commObs || '';
                }
            });
        });
        this.groupedSolutions = [...this.groupedSolutions];
    }

    handleObsChange(event) {
        this.commObs = event.target.value;
    }

    handleSave() {
        if (!this.selectedSolId) return;
        this.isSaving = true;
        
        saveSolucion({
            levantamientoId: null, // No necesario para actualización
            solucionId: this.selectedSolId,
            nombre: this.selectedSolName,
            descripcion: this.techDesc, // Mantenemos la original
            observaciones: this.commObs
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Éxito',
                message: 'Observaciones de costeo guardadas correctamente.',
                variant: 'success'
            }));
            this.loadSolutions();
        })
        .catch(error => console.error('Error save:', error))
        .finally(() => this.isSaving = false);
    }

    get isEditorDisabled() {
        return !this.selectedSolId;
    }

    get panelTitle() {
        return this.selectedSolId ? `Configurando: ${this.selectedSolName}` : 'Seleccione una solución para configurar';
    }
}