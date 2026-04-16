Quote q = [SELECT Id, Markers_Data__c FROM Quote WHERE QuoteNumber = '00000104' LIMIT 1];
if (q.Markers_Data__c != null) {
    String decoded = EncodingUtil.urlDecode(EncodingUtil.base64Decode(q.Markers_Data__c).toString(), 'UTF-8');
    System.debug('--- JSON TÉCNICO REAL ---');
    System.debug(decoded);
    System.debug('-------------------------');
} else {
    System.debug('EL CAMPO Markers_Data__c ESTÁ VACÍO');
}
