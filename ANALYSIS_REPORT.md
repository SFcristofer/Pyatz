# Reporte Exhaustivo del Proyecto Pyatz (Salesforce)

## 1. Arquitectura de Clases Apex

### QuoteContractPDFController
- **Métodos (@AuraEnabled)**: 1
- **Consultas SOQL**: 4
- **Llamadas Externas (Callouts)**: No
- **Métodos Detectados**: getQuoteLineItems...

### QuoteTechnicalController
- **Métodos (@AuraEnabled)**: 38
- **Consultas SOQL**: 56
- **Llamadas Externas (Callouts)**: No
- **Métodos Detectados**: getEmailTemplatesByFolders, saveStageTracking, getQuoteStats, getFilteredSedes, getProductPrices, saveSurveyData, processLevantamientos, renameUploadedFile, saveSolucion, getBusinessLineOptions...

### QuoteTechnicalPDFController
- **Métodos (@AuraEnabled)**: 0
- **Consultas SOQL**: 3
- **Llamadas Externas (Callouts)**: No
- **Métodos Detectados**: ...

### SlackIntegrationController
- **Métodos (@AuraEnabled)**: 8
- **Consultas SOQL**: 0
- **Llamadas Externas (Callouts)**: Sí
- **Métodos Detectados**: sendMessage, createChannel, getThreadReplies, getChannelMessages, pinMessage, uploadFile, performCallout, getChannels, getUserMap...

## 2. Componentes Lightning Web Components (LWC)

### techCommunicationHub
- **Dependencias Apex**: QuoteTechnicalController.getAvailableAttachments, QuoteTechnicalController.getEmailTemplatesByFolders, QuoteTechnicalController.getEmailEngagementDetails, QuoteTechnicalController.sendEmailWithAttachments, QuoteTechnicalController.renderTemplate
- **Módulos Importados**: @salesforce/apex/QuoteTechnicalController.getEmailTemplatesByFolders, lightning/platformShowToastEvent, @salesforce/apex/QuoteTechnicalController.getAvailableAttachments, lightning/navigation, @salesforce/apex/QuoteTechnicalController.getEmailEngagementDetails, @salesforce/apex/QuoteTechnicalController.sendEmailWithAttachments, lwc, @salesforce/apex/QuoteTechnicalController.renderTemplate

### techContractManager
- **Dependencias Apex**: QuoteTechnicalController.getInitialData, QuoteTechnicalController.getEmailTemplatesByFolder, QuoteTechnicalController.searchUsers, QuoteContractPDFController.getQuoteLineItems, QuoteTechnicalController.renderTemplate
- **Módulos Importados**: @salesforce/apex/QuoteTechnicalController.getEmailTemplatesByFolder, lightning/platformShowToastEvent, @salesforce/apex/QuoteContractPDFController.getQuoteLineItems, lightning/navigation, @salesforce/apex/QuoteTechnicalController.searchUsers, @salesforce/apex/QuoteTechnicalController.getInitialData, lwc, @salesforce/apex/QuoteTechnicalController.renderTemplate
- **Eventos Disparados**: cancel, workorders

### techDocumentManager
- **Dependencias Apex**: QuoteTechnicalController.renameUploadedFile, QuoteTechnicalController.deleteDocument, QuoteTechnicalController.getDocumentStates
- **Módulos Importados**: @salesforce/apex, lightning/platformShowToastEvent, lightning/navigation, @salesforce/apex/QuoteTechnicalController.renameUploadedFile, lightning/confirm, @salesforce/apex/QuoteTechnicalController.getDocumentStates, lwc, @salesforce/apex/QuoteTechnicalController.deleteDocument

### techLevantamientoManager
- **Dependencias Apex**: QuoteTechnicalController.getLevantamientoDetails, QuoteTechnicalController.saveSurveyData
- **Módulos Importados**: lwc, lightning/platformShowToastEvent, @salesforce/apex/QuoteTechnicalController.getLevantamientoDetails, @salesforce/apex/QuoteTechnicalController.saveSurveyData

### techMemoriaManager
- **Dependencias Apex**: QuoteTechnicalController.getLevantamientoDetails, QuoteTechnicalController.getSoluciones, QuoteTechnicalController.deleteSolucion, QuoteTechnicalController.saveSolucion
- **Módulos Importados**: @salesforce/apex/QuoteTechnicalController.getLevantamientoDetails, @salesforce/apex/QuoteTechnicalController.saveSolucion, lightning/platformShowToastEvent, @salesforce/apex/QuoteTechnicalController.getSoluciones, @salesforce/apex/QuoteTechnicalController.deleteSolucion, lwc

### techOnboardingChecklist
- **Módulos Importados**: lwc

### techOperations360
- **Dependencias Apex**: QuoteTechnicalController.getProcessHistory, QuoteTechnicalController.saveStageTracking, QuoteTechnicalController.getOpportunitiesList
- **Módulos Importados**: lightning/uiObjectInfoApi, @salesforce/schema/Opportunity.Subetapa__c, @salesforce/apex/QuoteTechnicalController.getOpportunitiesList, @salesforce/apex/QuoteTechnicalController.getProcessHistory, lightning/navigation, lightning/uiRecordApi, @salesforce/schema/Opportunity, @salesforce/apex/QuoteTechnicalController.saveStageTracking, @salesforce/schema/Opportunity.StageName, lwc, c/techSlackModal, @salesforce/schema/Opportunity.Id, @salesforce/schema/Opportunity.Estado_Subetapa__c

### techProcessSummary
- **Dependencias Apex**: QuoteTechnicalController.getProcessHistory, QuoteTechnicalController.getOpenOpportunities
- **Módulos Importados**: lwc, @salesforce/apex/QuoteTechnicalController.getProcessHistory, @salesforce/apex, @salesforce/apex/QuoteTechnicalController.getOpenOpportunities

### techQuoteEditor
- **Dependencias Apex**: QuoteTechnicalController.cloneQuote, QuoteTechnicalController.getInitialData, QuoteTechnicalController.searchParentAccounts, QuoteTechnicalController.searchNecesidades, QuoteTechnicalController.searchProducts, QuoteTechnicalController.getEmailTemplatesByFolder, QuoteTechnicalController.getFilteredSedes, QuoteTechnicalController.validatePLPassword, QuoteTechnicalController.renderTemplate, QuoteTechnicalController.getProductPrices, QuoteTechnicalController.getBusinessLineOptions, QuoteTechnicalController.saveTechnicalData
- **Módulos Importados**: @salesforce/apex/QuoteTechnicalController.getEmailTemplatesByFolder, @salesforce/apex/QuoteTechnicalController.getBusinessLineOptions, @salesforce/apex/QuoteTechnicalController.saveTechnicalData, @salesforce/apex/QuoteTechnicalController.searchNecesidades, lightning/platformShowToastEvent, lightning/navigation, @salesforce/apex/QuoteTechnicalController.getFilteredSedes, @salesforce/apex/QuoteTechnicalController.getInitialData, @salesforce/apex/QuoteTechnicalController.searchParentAccounts, @salesforce/apex/QuoteTechnicalController.validatePLPassword, @salesforce/apex/QuoteTechnicalController.searchProducts, @salesforce/apex/QuoteTechnicalController.getProductPrices, lwc, @salesforce/apex/QuoteTechnicalController.cloneQuote, @salesforce/apex/QuoteTechnicalController.renderTemplate
- **Eventos Disparados**: viewcontract, cancel, editquote

### techQuoteList
- **Dependencias Apex**: QuoteTechnicalController.cloneQuote, QuoteTechnicalController.getQuotesList, QuoteTechnicalController.getQuoteStats, QuoteTechnicalController.searchProspectos, QuoteTechnicalController.searchSedes
- **Módulos Importados**: @salesforce/apex/QuoteTechnicalController.getQuoteStats, lightning/platformShowToastEvent, @salesforce/apex/QuoteTechnicalController.searchSedes, lightning/navigation, @salesforce/apex/QuoteTechnicalController.searchProspectos, @salesforce/apex/QuoteTechnicalController.getQuotesList, lwc, @salesforce/apex/QuoteTechnicalController.cloneQuote
- **Eventos Disparados**: viewcontract, createnew, editquote

### techQuoteManager
- **Módulos Importados**: lwc

### techQuoteViewer

### techResourceCalendar
- **Dependencias Apex**: QuoteTechnicalController.getCalendarData
- **Módulos Importados**: lwc, @salesforce/apex/QuoteTechnicalController.getCalendarData

### techSlackModal
- **Dependencias Apex**: SlackIntegrationController.createChannel, SlackIntegrationController.pinMessage, SlackIntegrationController.getUserMap, SlackIntegrationController.sendMessage, SlackIntegrationController.getChannelMessages, SlackIntegrationController.uploadFile, SlackIntegrationController.getThreadReplies, SlackIntegrationController.getChannels
- **Módulos Importados**: @salesforce/apex/SlackIntegrationController.getUserMap, @salesforce/apex/SlackIntegrationController.uploadFile, @salesforce/apex/SlackIntegrationController.pinMessage, @salesforce/apex/SlackIntegrationController.getChannels, lightning/platformShowToastEvent, @salesforce/apex/SlackIntegrationController.createChannel, @salesforce/apex/SlackIntegrationController.getThreadReplies, @salesforce/apex/SlackIntegrationController.getChannelMessages, @salesforce/apex/SlackIntegrationController.sendMessage, lwc, lightning/modal

### techSolutionCosting
- **Dependencias Apex**: QuoteTechnicalController.getOpportunitySolutions, QuoteTechnicalController.saveSolucion
- **Módulos Importados**: lwc, lightning/platformShowToastEvent, @salesforce/apex/QuoteTechnicalController.saveSolucion, @salesforce/apex/QuoteTechnicalController.getOpportunitySolutions

### techSolutionDefiner

### techTacticalFollowUp
- **Dependencias Apex**: QuoteTechnicalController.saveNote, QuoteTechnicalController.getTacticalHistory
- **Módulos Importados**: @salesforce/apex, lightning/platformShowToastEvent, lightning/navigation, @salesforce/apex/QuoteTechnicalController.saveNote, @salesforce/apex/QuoteTechnicalController.getTacticalHistory, lwc

### techWorkOrderConsole
- **Módulos Importados**: lwc
- **Eventos Disparados**: back

## 3. Modelo de Datos (Objetos)

### Levantamiento_Tecnico__c
- **Campos Personalizados**: Area_Cocina_Banos__c, Azolves__c, Bidon_10L__c, Bidon_20L__c, Bidon_25L__c, Canastilla__c, Cantidad_Principal__c, Coladeras__c, Cuarto_Humado__c, Dias_Servicio_Censo__c, ENT__c, Equipos_ARM__c, Escamoche__c, Estado_Instalacion__c, Estado_Trampa__c, Fotografia__c, Frecuencia_Limpieza__c, Frecuencia__c, GM_Consideraciones_Especiales__c, GM_Contenedores_Sugeridos__c, GM_Cubiculos_Totales__c, GM_Dias_Servicio__c, GM_Frecuencia_Recoleccion__c, GM_Frecuencia_Uso__c, GM_Horario_Servicio__c, GM_Motivo_Necesidad__c, GM_Permisos_Acceso__c, GM_Permite_Levantamiento_Foto__c, GM_Presupuesto_Asignado__c, GM_Requiere_Capacitacion__c, GM_Sanitarios_Totales__c, GM_Usuarias_Externas__c, GM_Usuarias_Internas__c, Instalaciones__c, Mampara__c, Memoria_Descriptiva__c, Metros_Lineales__c, Mingitorios__c, Modelo_Grasas__c, Modelo_TG_Bio__c, Mueble__c, Nivel__c, Observaciones_Tecnicas__c, Oportunidad__c, Ovalines_Lavabo__c, Pared__c, Piso__c, Presupuesto__c, Residuos_Tarja__c, Ret_Salida__c, Sello__c, SP__c, ST_1__c, Tapon_Registro__c, Tarjas_Servicios__c, Tarja__c, Tinas_por_Tarja__c, Tipo_Servicio__c, Tornillo__c, Trampa_Grasa__c, Vactor_Alcance_Pyatz__c, Vactor_Ancho__c, Vactor_Descripcion__c, Vactor_Dificultad__c, Vactor_Distancia_Camion__c, Vactor_Largo__c, Vactor_Material__c, Vactor_Medida__c, Vactor_Permiso_Delegacion__c, Vactor_Permiso_Plaza__c, Vactor_Profundidad__c, Vactor_Servicio_Requerido__c, VE__c, VP__c, WC__c, Zona_Genero__c

### Location
- **Campos Personalizados**: AccountId, CloseDate, ConstructionEndDate, ConstructionStartDate, Description, DrivingDirections, ExternalReference, IsInventoryLocation, IsMobile, Location, LocationLevel, LocationType, LogoId, Name, OpenDate, OwnerId, ParentLocationId, PossessionDate, RemodelEndDate, RemodelStartDate, RootLocationId, TimeZone, VisitorAddressId

### Opportunity
- **Campos Personalizados**: Memoria_Descriptiva__c

### Product2
- **Campos Personalizados**: Linea__c

### Quote
- **Campos Personalizados**: Approval_Date__c, Business_Lines_Selected__c, Introduction_Text__c, Markers_Data__c, Memoria_Descriptiva__c, Selected_Plan_URL__c, Show_Introduction__c, Show_Warranty__c, Source_Quote__c, Technical_Sedes__c, Warranty_Text__c

### QuoteLineItem
- **Campos Personalizados**: Pyatz_Technical_Description__c

### Seguimiento_Etapas_Pyatz__c
- **Campos Personalizados**: Clave_Unica__c, Estado__c, Etapa__c, Oportunidad__c, Subetapa__c

### Solucion_Tecnica__c
- **Campos Personalizados**: Descripcion_Detallada__c, Levantamiento_Tecnico__c, Observaciones_Comerciales__c

## 4. Páginas Visualforce

### QuoteContractPDF.page
- **Controlador Standard**: Quote
- **Extensiones**: QuoteContractPDFController

### QuoteTechnicalPDF.page
- **Controlador Standard**: Quote
- **Extensiones**: QuoteTechnicalPDFController

## 5. Integraciones y Dependencias Externas

Basado en el análisis de Apex:
- **Slack API**: Se detectó integración nativa con Slack a través de `SlackIntegrationController` haciendo HTTP Callouts.
