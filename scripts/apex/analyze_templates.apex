// Analizando el contenido de las plantillas de introducción
System.debug('--- INICIO ANÁLISIS DE PLANTILLAS ---');
for(EmailTemplate et : [SELECT Name, HtmlValue, Body FROM EmailTemplate WHERE Folder.Name = 'Pyatz - Introducciones']) {
    System.debug('TEMPLATE_NAME: ' + et.Name);
    System.debug('HTML_CONTENT: ' + et.HtmlValue);
    System.debug('BODY_CONTENT: ' + et.Body);
}
System.debug('--- FIN ANÁLISIS ---');