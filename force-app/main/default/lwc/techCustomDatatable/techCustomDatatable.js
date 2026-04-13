import LightningDatatable from 'lightning/datatable';
import healthCellTemplate from './healthCellTemplate.html';

export default class TechCustomDatatable extends LightningDatatable {
    static customTypes = {
        processHealth: {
            template: healthCellTemplate,
            standardCellLayout: true,
            typeAttributes: ['value']
        }
    };
}