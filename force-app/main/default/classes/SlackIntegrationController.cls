public with sharing class SlackIntegrationController {
    
    private static final String BOT_TOKEN = System.Label.Slack_Bot_Token;
    private static final String API_URL = 'https://slack.com/api/';

    private static Map<String, String> userCache = new Map<String, String>();

    /**
     * Obtiene el mapeo de IDs de usuario a nombres reales.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getUserMap() {
        try {
            String body = performCallout('users.list', 'GET', null);
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            Map<String, String> userMap = new Map<String, String>();
            if ((Boolean)response.get('ok')) {
                List<Object> members = (List<Object>)response.get('members');
                for (Object obj : members) {
                    Map<String, Object> member = (Map<String, Object>)obj;
                    String id = (String)member.get('id');
                    String realName = (String)member.get('real_name');
                    userMap.put(id, realName != null ? realName : (String)member.get('name'));
                }
            }
            return userMap;
        } catch (Exception e) {
            return new Map<String, String>();
        }
    }

    /**
     * Obtiene la lista dinámica de canales públicos del workspace.
     */
    @AuraEnabled
    public static List<Map<String, String>> getChannels() {
        try {
            String body = performCallout('conversations.list', 'GET', null);
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            List<Map<String, String>> channelList = new List<Map<String, String>>();
            if ((Boolean)response.get('ok')) {
                List<Object> channels = (List<Object>)response.get('channels');
                for (Object obj : channels) {
                    Map<String, Object> ch = (Map<String, Object>)obj;
                    Map<String, String> channelMap = new Map<String, String>();
                    channelMap.put('id', (String)ch.get('id'));
                    channelMap.put('name', (String)ch.get('name'));
                    
                    // Extraemos el topic (tema) si existe
                    Map<String, Object> topicMap = (Map<String, Object>)ch.get('topic');
                    channelMap.put('topic', topicMap != null ? (String)topicMap.get('value') : '');
                    
                    channelList.add(channelMap);
                }
            }
            return channelList;
        } catch (Exception e) {
            throw new AuraHandledException('Error al listar canales: ' + e.getMessage());
        }
    }

    /**
     * Envía un mensaje con formato avanzado a Slack.
     * Intenta unirse al canal automáticamente si no es miembro.
     */
    /**
     * Recupera las respuestas de un hilo específico.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getThreadReplies(String channelId, String threadTs) {
        try {
            String body = performCallout('conversations.replies?channel=' + channelId + '&ts=' + threadTs, 'GET', null);
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            List<Map<String, Object>> messages = new List<Map<String, Object>>();
            if ((Boolean)response.get('ok')) {
                List<Object> slackMsgs = (List<Object>)response.get('messages');
                for (Object obj : slackMsgs) {
                    messages.add((Map<String, Object>)obj);
                }
            }
            return messages;
        } catch (Exception e) {
            throw new AuraHandledException('Error al cargar hilo: ' + e.getMessage());
        }
    }

    /**
     * Envía un mensaje a Slack, con soporte opcional para hilos.
     * Devuelve el timestamp del mensaje enviado.
     */
    @AuraEnabled
    public static String sendMessage(String channelId, String message, String phase, String recordId, String threadTs) {
        try {
            performCallout('conversations.join', 'POST', JSON.serialize(new Map<String, String>{'channel' => channelId}));

            String formattedMessage = '*🚀 Pyatz 360 - ' + phase + '*\n' +
                                    '> ' + message;
            
            // Si no es un hilo, agregamos el contexto del expediente
            if (String.isBlank(threadTs)) {
                formattedMessage += '\n*Expediente:* ' + URL.getOrgDomainUrl().toExternalForm() + '/' + recordId;
            }

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('channel', channelId);
            payload.put('text', formattedMessage);
            if (String.isNotBlank(threadTs)) {
                payload.put('thread_ts', threadTs);
            }

            String responseBody = performCallout('chat.postMessage', 'POST', JSON.serialize(payload));
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            if ((Boolean)response.get('ok')) {
                return (String)response.get('ts');
            } else {
                throw new AuraHandledException('Error de Slack: ' + response.get('error'));
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Recupera el historial de mensajes de un canal.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getChannelMessages(String channelId) {
        try {
            String body = performCallout('conversations.history?channel=' + channelId + '&limit=15', 'GET', null);
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            if (!(Boolean)response.get('ok')) {
                String error = (String)response.get('error');
                if (error == 'not_in_channel') {
                    // Si no estamos en el canal, intentamos unirnos y reintentar una vez
                    performCallout('conversations.join', 'POST', JSON.serialize(new Map<String, String>{'channel' => channelId}));
                    body = performCallout('conversations.history?channel=' + channelId + '&limit=15', 'GET', null);
                    response = (Map<String, Object>) JSON.deserializeUntyped(body);
                }
            }

            List<Map<String, Object>> messages = new List<Map<String, Object>>();
            if ((Boolean)response.get('ok')) {
                List<Object> slackMsgs = (List<Object>)response.get('messages');
                for (Object obj : slackMsgs) {
                    messages.add((Map<String, Object>)obj);
                }
            }
            return messages;
        } catch (Exception e) {
            throw new AuraHandledException('Error al cargar historial: ' + e.getMessage());
        }
    }

    /**
     * Crea un nuevo canal en Slack (ej. para un nuevo cliente).
     */
    @AuraEnabled
    public static String createChannel(String channelName) {
        try {
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('name', channelName.toLowerCase().replaceAll('[^a-z0-9_-]', '-'));

            String body = performCallout('conversations.create', 'POST', JSON.serialize(payload));
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            if ((Boolean)response.get('ok')) {
                Map<String, Object> channel = (Map<String, Object>)response.get('channel');
                return (String)channel.get('id');
            } else {
                throw new AuraHandledException('Slack: ' + response.get('error'));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al crear canal: ' + e.getMessage());
        }
    }

    /**
     * Fija un mensaje importante en el canal (Requiere scope pins:write).
     */
    @AuraEnabled
    public static void pinMessage(String channelId, String timestamp) {
        try {
            Map<String, String> payload = new Map<String, String>{
                'channel' => channelId,
                'timestamp' => timestamp
            };
            String responseBody = performCallout('pins.add', 'POST', JSON.serialize(payload));
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            if (!(Boolean)response.get('ok') && (String)response.get('error') != 'already_pinned') {
                throw new AuraHandledException('Error al fijar mensaje: ' + response.get('error'));
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Sube un archivo a un canal de Slack (Requiere scope files:write).
     */
    @AuraEnabled
    public static void uploadFile(String channelId, String fileName, String base64Data) {
        try {
            // 1. Obtener URL de subida
            Map<String, Object> urlPayload = new Map<String, Object>{
                'filename' => fileName,
                'length' => EncodingUtil.base64Decode(base64Data).size()
            };
            String urlResponse = performCallout('files.getUploadExternalUrl', 'GET', null + '?filename=' + fileName + '&length=' + urlPayload.get('length'));
            Map<String, Object> urlData = (Map<String, Object>) JSON.deserializeUntyped(urlResponse);
            
            if (!(Boolean)urlData.get('ok')) throw new AuraHandledException('Slack Upload URL Error: ' + urlData.get('error'));

            String uploadUrl = (String)urlData.get('upload_url');
            String fileId = (String)urlData.get('file_id');

            // 2. Subir el archivo real (Binario)
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(uploadUrl);
            req.setMethod('POST');
            req.setBodyAsBlob(EncodingUtil.base64Decode(base64Data));
            h.send(req);

            // 3. Completar la subida y compartir en el canal
            Map<String, Object> completePayload = new Map<String, Object>{
                'files' => new List<Map<String, String>>{ new Map<String, String>{ 'id' => fileId } },
                'channel_id' => channelId
            };
            performCallout('files.completeUploadExternal', 'POST', JSON.serialize(completePayload));

        } catch (Exception e) {
            throw new AuraHandledException('Error al subir archivo: ' + e.getMessage());
        }
    }

    /**
     * Helper para realizar las llamadas HTTP.
     */
    private static String performCallout(String endpoint, String method, String payload) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_URL + endpoint);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + BOT_TOKEN);
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        if (payload != null) req.setBody(payload);
        
        HttpResponse res = h.send(req);
        return res.getBody();
    }
}