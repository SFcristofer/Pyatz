import LightningModal from 'lightning/modal';
import { api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChannels from '@salesforce/apex/SlackIntegrationController.getChannels';
import sendMessage from '@salesforce/apex/SlackIntegrationController.sendMessage';
import getChannelMessages from '@salesforce/apex/SlackIntegrationController.getChannelMessages';
import getThreadReplies from '@salesforce/apex/SlackIntegrationController.getThreadReplies';
import createChannel from '@salesforce/apex/SlackIntegrationController.createChannel';
import getUserMap from '@salesforce/apex/SlackIntegrationController.getUserMap';
import pinMessage from '@salesforce/apex/SlackIntegrationController.pinMessage';
import uploadFile from '@salesforce/apex/SlackIntegrationController.uploadFile';

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
    _refreshInterval; // Variable para el temporizador

    async connectedCallback() {
        await this.loadUserMap();
        await this.loadChannels();
        this.startAutoRefresh(); // Iniciamos el auto-refresco
    }

    disconnectedCallback() {
        this.stopAutoRefresh(); // Detenemos el temporizador al cerrar el modal
    }

    startAutoRefresh() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._refreshInterval = setInterval(() => {
            this.silentRefresh();
        }, 5000); // Refresca cada 5 segundos
    }

    stopAutoRefresh() {
        if (this._refreshInterval) {
            clearInterval(this._refreshInterval);
        }
    }

    /**
     * TODO: Optimizar este mecanismo de Polling en la siguiente fase.
     * Se recomienda migrar a una arquitectura basada en eventos (Platform Events + Webhooks de Slack)
     * para reducir el consumo de límites de API de Salesforce y lograr un tiempo real genuino.
     */
    async silentRefresh() {
        // Solo refrescamos si hay un canal seleccionado y no estamos enviando nada
        if (!this.selectedChannelId || this.isSending || this.isChatLoading) return;

        try {
            let history;
            if (this.selectedThreadTs) {
                history = await getThreadReplies({ channelId: this.selectedChannelId, threadTs: this.selectedThreadTs });
            } else {
                history = await getChannelMessages({ channelId: this.selectedChannelId });
            }

            const newMessages = this.processSlackMessages(history);

            // Solo actualizamos si el número de mensajes o el contenido del último cambió
            if (JSON.stringify(newMessages) !== JSON.stringify(this.messages)) {
                const wasAtBottom = this.isAtBottom();
                this.messages = newMessages;
                if (wasAtBottom) this.scrollToBottom();
            }
        } catch (error) {
            console.warn('Error en refresco silencioso');
        }
    }

    isAtBottom() {
        const container = this.template.querySelector('.message-list');
        if (!container) return false;
        // Margen de error de 20px para detectar si el usuario está cerca del final
        return (container.scrollHeight - container.scrollTop - container.clientHeight) < 20;
    }

    async loadUserMap() {
        try {
            this.userMap = await getUserMap();
        } catch (error) { console.error('Error cargando usuarios'); }
    }

    async loadChannels() {
        this.isLoading = true;
        try {
            const result = await getChannels();
            if (result && result.length > 0) {
                this._channels = result;
                this.selectedChannelId = this._channels[0].id;
                await this.loadChatHistory();
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
            this.scrollToBottom();
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
            this.scrollToBottom();
        } catch (error) {
            console.error('Error cargando hilo:', error);
        } finally {
            this.isChatLoading = false;
        }
    }

    processSlackMessages(history) {
        if (!history || !Array.isArray(history)) return [];
        
        // Clonamos y ordenamos cronológicamente por timestamp (ts)
        const sortedHistory = [...history].sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));

        return sortedHistory.map(m => {
            let text = m.text || '';
            
            // ... (resto de la lógica de procesamiento igual) ...
            text = text.replace(/<@([A-Z0-9]+)>/g, (match, id) => {
                return this.userMap[id] ? `@${this.userMap[id]}` : match;
            });

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

            text = text.replace(/\*(.*?)\*/g, '<strong>$1</strong>');
            text = text.replace(/• /g, '&bull; ');
            text = text.replace(/<(https?:\/\/[^|>]+)\|([^>]+)>/g, '<a href="$1" target="_blank">$2</a>');
            text = text.replace(/<(https?:\/\/[^>]+)>/g, '<a href="$1" target="_blank">$1</a>');
            text = text.replace(/\n/g, '<br/>');

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
        }); // Eliminamos el .reverse() ya que usamos .sort()
    }

    scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const container = this.template.querySelector('.message-list');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        }, 100);
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

    openFilePicker() {
        this.template.querySelector('.file-input').click();
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        // Validar tamaño (máximo 4MB para evitar límites de heap en Apex)
        if (file.size > 4000000) {
            this.showToast('Archivo muy grande', 'El tamaño máximo permitido es de 4MB.', 'error');
            return;
        }

        this.isChatLoading = true;
        try {
            const reader = new FileReader();
            reader.onload = async () => {
                const base64 = reader.result.split(',')[1];
                await uploadFile({
                    channelId: this.selectedChannelId,
                    fileName: file.name,
                    base64Data: base64
                });
                this.showToast('Éxito', 'Archivo subido correctamente a Slack', 'success');
                this.loadChatHistory();
            };
            reader.readAsDataURL(file);
        } catch (error) {
            this.showToast('Error al subir', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isChatLoading = false;
        }
    }

    async handleSend() {
        if (!this.messageText || !this.selectedChannelId) return;
        
        this.isSending = true;
        try {
            const timestamp = await sendMessage({
                message: this.messageText,
                phase: this.currentPhase,
                recordId: this.recordId,
                channelId: this.selectedChannelId,
                threadTs: this.selectedThreadTs
            });

            // Lógica de Pin Automático: Si el mensaje contiene "Expediente" y no es un hilo
            if (this.messageText.toLowerCase().includes('expediente') && !this.selectedThreadTs) {
                try {
                    await pinMessage({ channelId: this.selectedChannelId, timestamp: timestamp });
                    console.log('Mensaje fijado correctamente');
                } catch (pinError) {
                    console.error('Error al fijar mensaje:', pinError);
                }
            }

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
            
            // Refrescamos la lista de canales inmediatamente
            await this.loadChannels();
            
            // Opcional: Seleccionamos automáticamente el nuevo canal creado
            this.selectedChannelId = newId;
            this.loadChatHistory();
            
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