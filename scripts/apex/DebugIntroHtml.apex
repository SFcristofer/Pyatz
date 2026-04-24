// Ejecuta en Developer Console > Debug > Open Execute Anonymous Window
// Reemplaza el ID con el de tu Quote de prueba (el que ves en la URL del PDF)
String quoteId = 'PEGA_QUOTE_ID_AQUI';

Quote q = [SELECT Introduction_Text__c FROM Quote WHERE Id = :quoteId LIMIT 1];
if (q.Introduction_Text__c != null) {
    // Muestra los primeros 500 caracteres para ver qué hay al inicio
    System.debug('=== INICIO DEL HTML ===');
    System.debug(q.Introduction_Text__c.left(500));
    System.debug('=== LONGITUD TOTAL: ' + q.Introduction_Text__c.length());
} else {
    System.debug('Introduction_Text__c está vacío');
}
