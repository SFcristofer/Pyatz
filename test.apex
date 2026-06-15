Id templateId = '00XV9000001nbqfMAA';
Id quoteId = '0Q0V9000002FiUDKA0';
Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateId, null, quoteId);
String body = rendered.getHtmlBody();
if (body == null) body = rendered.getPlainTextBody();

// Extraer todos los bloques CDATA
String extractedContent = '';
Matcher m = Pattern.compile('(?si)<!\\[CDATA\\[(.*?)\\]\\]>').matcher(body);
while (m.find()) {
    extractedContent += m.group(1);
}

if (String.isNotBlank(extractedContent)) {
    body = extractedContent;
}

System.debug('EXTRACTED: ' + body);
