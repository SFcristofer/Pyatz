import { LightningElement, api, track } from 'lwc';

export default class TechOnboardingChecklist extends LightningElement {
    @api recordId;

    options = [
        { label: 'Si', value: 'Si' },
        { label: 'No', value: 'No' }
    ];

    @track leftColumn = [
        { name: 'ine', label: 'INE', value: '' },
        { name: 'curp', label: 'CURP', value: '' },
        { name: 'csf', label: 'Const. Situación Fiscal', value: '' },
        { name: 'imss', label: 'Alta IMSS', value: '' },
        { name: 'vigencia', label: 'Vigencia de derechos', value: '' }
    ];

    @track rightColumn = [
        { name: 'dc3_alturas', label: 'DC-3 Alturas NOM-009-STPS-2011', value: '' },
        { name: 'dc3_confinados', label: 'DC-3 Confinados', value: '' },
        { name: 'dc3_quimicos', label: 'DC-3 Quimicos', value: '' },
        { name: 'dc3_ext1', label: 'DC-3 ???', value: '' },
        { name: 'dc3_ext2', label: 'DC-3 ????', value: '' }
    ];
}