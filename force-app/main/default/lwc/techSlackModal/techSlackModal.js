import LightningModal from 'lightning/modal';
import { api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChannels from '@salesforce/apex/SlackIntegrationController.getChannels';
import sendMessage from '@salesforce/apex/SlackIntegrationController.sendMessage';
import getChannelMessages from '@salesforce/apex/SlackIntegrationController.getChannelMessages';
import getThreadReplies from '@salesforce/apex/SlackIntegrationController.getThreadReplies';
import createChannel from '@salesforce/apex/SlackIntegrationController.createChannel';
import getUserMap from '@salesforce/apex/SlackIntegrationController.getUserMap';

export default class TechSlackModal extends LightningModal {
    @api recordId;
    @api currentPhase;
    
    @track messageText = '';
    @track isSending = false;
    @track _channels = [];
    @track selectedChannelId = '';
    @track messages = [];
    @track isLoading = true;
    @track isChatLoading = false;
    
    @track selectedThreadTs = null;
    @track threadRootMsg = null;
    userMap = {};

    async connectedCallback() {
        await this.loadUserMap();
        this.loadChannels();
    }

    async loadUserMap() {
        try {
            this.userMap = await getUserMap();
        } catch (error) { console.error('Error cargando usuarios'); }
    }

    async loadChannels() {
        try {
            const result = await getChannels();
            if (result && result.length > 0) {
                this._channels = result;
                this.selectedChannelId = this._channels[0].id;
                this.loadChatHistory();
            } else {
                this.showToast('Atención', 'No se encontraron canales públicos donde el Bot esté invitado.', 'warning');
                this._channels = [];
            }
        } catch (error) {
            this.showToast('Error', 'No se pudieron cargar los canales', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadChatHistory() {
        if (!this.selectedChannelId) return;
        this.isChatLoading = true;
        this.selectedThreadTs = null;
        this.threadRootMsg = null;
        
        try {
            const history = await getChannelMessages({ channelId: this.selectedChannelId });
            this.messages = this.processSlackMessages(history);
        } catch (error) {
            console.error('Error cargando historial:', error);
            this.messages = [];
        } finally {
            this.isChatLoading = false;
        }
    }

    async loadThreadHistory(ts) {
        this.isChatLoading = true;
        try {
            const replies = await getThreadReplies({ channelId: this.selectedChannelId, threadTs: ts });
            this.messages = this.processSlackMessages(replies);
            // El primer mensaje es el raíz del hilo
            this.threadRootMsg = this.messages[0];
        } catch (error) {
            console.error('Error cargando hilo:', error);
        } finally {
            this.isChatLoading = false;
        }
    }

    processSlackMessages(history) {
        if (!history || !Array.isArray(history)) return [];
        return history.map(m => {
            let text = m.text || '';
            
            // 1. Traducimos menciones directas <@U123> a nombres
            text = text.replace(/<@([A-Z0-9]+)>/g, (match, id) => {
                return this.userMap[id] ? `@${this.userMap[id]}` : match;
            });

            // 2. Diccionario de Emojis extendido (basado en x.txt)
            const emojiMap = {
                ':mag_right:': '🔎',
                ':rocket:': '🚀',
                ':white_check_mark:': '✅',
                ':warning:': '⚠️',
                ':pushpin:': '📌',
                ':hammer_and_wrench:': '🛠️',
                ':briefcase:': '💼',
                ':calendar:': '📅',
                ':moneybag:': '💰',
                ':info:': 'ℹ️',
                ':bulb:': '💡'
            };
            Object.keys(emojiMap).forEach(key => {
                text = text.replace(new RegExp(key, 'g'), emojiMap[key]);
            });

            // 3. Formateo de Texto (Negritas, Bullets, URLs)
            text = text.replace(/\*(.*?)\*/g, '<strong>$1</strong>');
            text = text.replace(/• /g, '&bull; '); // Bullets de Slack
            
            // URLs clicleables (formato Slack <http...|label> o <http...>)
            text = text.replace(/<(https?:\/\/[^|>]+)\|([^>]+)>/g, '<a href="$1" target="_blank">$2</a>');
            text = text.replace(/<(https?:\/\/[^>]+)>/g, '<a href="$1" target="_blank">$1</a>');

            // 4. Traducimos Saltos de línea
            text = text.replace(/\n/g, '<br/>');

            // 5. Identificación de Mensajes de Sistema (Join, Topic, etc)
            let isSystem = m.subtype === 'channel_join' || m.subtype === 'channel_topic' || m.user === 'USLACKBOT';
            if (m.subtype === 'channel_topic') {
                text = `<em>definió el tema del canal: ${text}</em>`;
            } else if (m.subtype === 'channel_join') {
                text = `<em>se unió al canal</em>`;
            }

            return {
                id: m.ts || Math.random().toString(),
                ts: m.ts,
                text: text,
                user: this.userMap[m.user] || m.user || 'Sistema',
                time: m.ts ? new Date(parseFloat(m.ts) * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '',
                class: isSystem ? 'message system' : 'message user',
                replyCount: m.reply_count || 0,
                hasReplies: (m.reply_count > 0 && !this.selectedThreadTs),
                isThreadRoot: m.thread_ts === m.ts
            };
        }).reverse();
    }

    get channelTopic() {
        const active = this._channels.find(c => c.id === this.selectedChannelId);
        return active ? active.topic : '';
    }

    handleMessageClick(event) {
        const ts = event.currentTarget.dataset.ts;
        if (!ts || this.selectedThreadTs) return;
        
        this.selectedThreadTs = ts;
        this.loadThreadHistory(ts);
    }

    handleBackToChannel() {
        this.loadChatHistory();
    }

    handleChannelSelect(event) {
        this.selectedChannelId = event.currentTarget.dataset.id;
        this.loadChatHistory();
    }

    handleMessageChange(event) {
        this.messageText = event.detail.value;
    }

    async handleSend() {
        if (!this.messageText || !this.selectedChannelId) return;
        
        this.isSending = true;
        try {
            await sendMessage({
                message: this.messageText,
                phase: this.currentPhase,
                recordId: this.recordId,
                channelId: this.selectedChannelId,
                threadTs: this.selectedThreadTs
            });

            this.messageText = '';
            if (this.selectedThreadTs) {
                this.loadThreadHistory(this.selectedThreadTs);
            } else {
                this.loadChatHistory();
            }
            this.showToast('Éxito', 'Mensaje enviado a Slack', 'success');
        } catch (error) {
            this.showToast('Error en Slack', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isSending = false;
        }
    }

    async handleCreateChannel() {
        const name = prompt('Nombre del nuevo canal (ej: cliente-nuevo-proyecto):');
        if (!name) return;

        this.isLoading = true;
        try {
            const newId = await createChannel({ channelName: name });
            this.showToast('Éxito', 'Canal creado correctamente', 'success');
            this.loadChannels(); // Recargamos la lista
        } catch (error) {
            this.showToast('Error', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get channels() {
        return this._channels.map(ch => ({
            ...ch,
            class: ch.id === this.selectedChannelId ? 'channel-item selected' : 'channel-item'
        }));
    }

    get activeChannelName() {
        const active = this._channels.find(c => c.id === this.selectedChannelId);
        return active ? active.name : '...';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleCancel() {
        this.close('cancel');
    }
}