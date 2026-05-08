import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAllTemplatesAdmin from '@salesforce/apex/FormTemplateController.getAllTemplatesAdmin';
import upsertTemplate      from '@salesforce/apex/FormTemplateController.upsertTemplate';
import deleteTemplate      from '@salesforce/apex/FormTemplateController.deleteTemplate';

const TYPE_OPTIONS = [
    { label: 'Opción múltiple (radio)', value: 'radio'  },
    { label: 'Número',                  value: 'number' },
    { label: 'Texto libre',             value: 'text'   },
];

const ICON_OPTIONS = [
    { label: 'utility:bucket',             value: 'utility:bucket'             },
    { label: 'utility:filter',             value: 'utility:filter'             },
    { label: 'utility:threedots_vertical', value: 'utility:threedots_vertical' },
    { label: 'utility:cases',              value: 'utility:cases'              },
    { label: 'utility:loop',               value: 'utility:loop'               },
    { label: 'utility:upload',             value: 'utility:upload'             },
    { label: 'utility:shield',             value: 'utility:shield'             },
    { label: 'utility:form',               value: 'utility:form'               },
    { label: 'utility:settings',           value: 'utility:settings'           },
    { label: 'utility:checklist',          value: 'utility:checklist'          },
];

export default class FormTemplateAdmin extends LightningElement {

    @track view        = 'list'; // 'list' | 'edit'
    @track templates   = [];
    @track loading     = false;
    @track saving      = false;
    @track confirmDeleteId = null;

    // Editor state
    @track editId      = null;
    @track editTipo    = '';
    @track editIcono   = 'utility:form';
    @track editOrden   = 1;
    @track editActivo  = true;
    @track editQuestions = [];
    @track _nextQNum   = 1;

    typeOptions = TYPE_OPTIONS;
    iconOptions = ICON_OPTIONS;

    connectedCallback() {
        this._loadTemplates();
    }

    // ─── List view ─────────────────────────────────────────────────────────────

    _loadTemplates() {
        this.loading = true;
        getAllTemplatesAdmin()
            .then(data => {
                this.templates = data.map(t => ({
                    ...t,
                    questionLabel: t.preguntas && t.preguntas !== '[]'
                        ? this._countQ(t.preguntas) + ' preguntas'
                        : 'Formulario libre',
                    rowClass: t.activo ? 'tpl-row' : 'tpl-row tpl-row--inactive',
                }));
            })
            .catch(err => this._toast('Error', err.body?.message || 'No se pudieron cargar las plantillas.', 'error'))
            .finally(() => { this.loading = false; });
    }

    handleNewTemplate() {
        this.editId        = null;
        this.editTipo      = '';
        this.editIcono     = 'utility:form';
        this.editOrden     = (this.templates.length || 0) + 1;
        this.editActivo    = true;
        this.editQuestions = [];
        this._nextQNum     = 1;
        this.view          = 'edit';
    }

    handleEditTemplate(event) {
        const id = event.currentTarget.dataset.id;
        const tpl = this.templates.find(t => t.id === id);
        if (!tpl) return;

        this.editId     = tpl.id;
        this.editTipo   = tpl.tipo;
        this.editIcono  = tpl.icono || 'utility:form';
        this.editOrden  = tpl.orden || 1;
        this.editActivo = tpl.activo !== false;

        let parsed = [];
        try { parsed = JSON.parse(tpl.preguntas || '[]'); } catch(e) {}
        this.editQuestions = parsed.map((q, i) => this._enrichQ(q, i));
        this._nextQNum = this.editQuestions.length + 1;
        this.view = 'edit';
    }

    handleDeleteClick(event) {
        this.confirmDeleteId = event.currentTarget.dataset.id;
    }

    handleDeleteConfirm() {
        const id = this.confirmDeleteId;
        this.confirmDeleteId = null;
        deleteTemplate({ templateId: id })
            .then(() => {
                this._toast('Eliminado', 'Plantilla eliminada.', 'success');
                this._loadTemplates();
            })
            .catch(err => this._toast('Error', err.body?.message || 'No se pudo eliminar.', 'error'));
    }

    handleDeleteCancel() { this.confirmDeleteId = null; }

    get hasTemplates() { return this.templates.length > 0; }
    get confirmTemplate() {
        return this.confirmDeleteId
            ? this.templates.find(t => t.id === this.confirmDeleteId)
            : null;
    }

    // ─── Edit view ─────────────────────────────────────────────────────────────

    handleCancelEdit() { this.view = 'list'; }

    handleTipoChange(event)   { this.editTipo   = event.target.value; }
    handleIconoChange(event)  { this.editIcono  = event.detail.value; }
    handleOrdenChange(event)  { this.editOrden  = parseInt(event.target.value, 10) || 1; }
    handleActivoChange(event) { this.editActivo = event.target.checked; }

    get isList() { return this.view === 'list'; }
    get isEdit() { return this.view === 'edit'; }
    get editTitle() { return this.editId ? `Editar: ${this.editTipo}` : 'Nueva plantilla'; }
    get isNewTemplate() { return !this.editId; }
    get hasQuestions() { return this.editQuestions.length > 0; }

    // ── Question actions ───────────────────────────────────────────────────────

    handleAddQuestion() {
        const id = 'q' + this._nextQNum++;
        this.editQuestions = [...this.editQuestions, this._enrichQ({
            id, label: '', type: 'radio', options: ['Sí', 'No'], defOn: '', def: '',
        }, this.editQuestions.length)];
        this._refreshMeta();
    }

    handleDeleteQuestion(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.editQuestions = this.editQuestions.filter((_, i) => i !== idx);
        this._refreshMeta();
    }

    handleMoveUp(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        if (idx === 0) return;
        const qs = [...this.editQuestions];
        [qs[idx - 1], qs[idx]] = [qs[idx], qs[idx - 1]];
        this.editQuestions = qs;
        this._refreshMeta();
    }

    handleMoveDown(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        if (idx >= this.editQuestions.length - 1) return;
        const qs = [...this.editQuestions];
        [qs[idx], qs[idx + 1]] = [qs[idx + 1], qs[idx]];
        this.editQuestions = qs;
        this._refreshMeta();
    }

    // ── Question field changes ─────────────────────────────────────────────────

    handleQLabelChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this._updateQ(idx, { label: event.target.value });
    }

    handleQTypeChange(event) {
        const idx  = parseInt(event.currentTarget.dataset.idx, 10);
        const type = event.detail.value;
        this._updateQ(idx, { type, defOn: '', def: '' });
    }

    handleQOptionsChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        const opts = event.target.value.split(',').map(s => s.trim()).filter(s => s);
        this._updateQ(idx, { options: opts, defOn: '' });
    }

    handleQDefOnChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this._updateQ(idx, { defOn: event.detail.value });
    }

    handleQDefChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this._updateQ(idx, { def: event.target.value });
    }

    // ── Save ──────────────────────────────────────────────────────────────────

    handleSaveTemplate() {
        if (!this.editTipo || !this.editTipo.trim()) {
            this._toast('Falta dato', 'El nombre del tipo de reporte es obligatorio.', 'warning');
            return;
        }

        const preguntas = JSON.stringify(
            this.editQuestions.map(q => {
                const out = { id: q.id, label: q.label, type: q.type };
                if (q.type === 'radio') {
                    out.options = q.options || [];
                    if (q.defOn) { out.defOn = q.defOn; out.def = q.def || ''; }
                }
                return out;
            })
        );

        this.saving = true;
        upsertTemplate({
            templateId: this.editId,
            tipo:       this.editTipo.trim(),
            preguntas,
            icono:      this.editIcono,
            orden:      this.editOrden,
            activo:     this.editActivo,
        })
        .then(() => {
            this._toast('Guardado', 'Plantilla guardada correctamente.', 'success');
            this.view = 'list';
            this._loadTemplates();
        })
        .catch(err => this._toast('Error', err.body?.message || 'No se pudo guardar.', 'error'))
        .finally(() => { this.saving = false; });
    }

    // ─── Private helpers ───────────────────────────────────────────────────────

    _enrichQ(q, idx) {
        const isRadio  = q.type === 'radio';
        const isNumber = q.type === 'number';
        const isText   = q.type === 'text';
        const opts     = Array.isArray(q.options) ? q.options : [];
        const defOnOpts = [{ label: '(ninguno)', value: '' },
            ...opts.map(o => ({ label: o, value: o }))];
        return {
            ...q,
            idx,
            num:        idx + 1,
            options:    opts,
            optionsStr: opts.join(', '),
            defOn:      q.defOn || '',
            def:        q.def   || '',
            isRadio, isNumber, isText,
            defOnOptions: defOnOpts,
            showDefOn: isRadio && opts.length > 0,
            showDef:   isRadio && !!(q.defOn),
            isFirst:   idx === 0,
            isLast:    false,
        };
    }

    _updateQ(idx, patch) {
        this.editQuestions = this.editQuestions.map((q, i) => {
            if (i !== idx) return q;
            const merged = { ...q, ...patch };
            return this._enrichQ(merged, i);
        });
        this._refreshMeta();
    }

    _refreshMeta() {
        const last = this.editQuestions.length - 1;
        this.editQuestions = this.editQuestions.map((q, i) => ({
            ...q,
            idx:    i,
            isFirst: i === 0,
            isLast:  i === last,
            showDef: q.isRadio && !!q.defOn,
        }));
    }

    _countQ(preguntasStr) {
        try { return JSON.parse(preguntasStr).length; } catch(e) { return 0; }
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}