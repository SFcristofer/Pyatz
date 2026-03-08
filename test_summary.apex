Id oppId = '006V900000Nz6KzIAJ';
List<Map<String, String>> result = QuoteTechnicalController.getLevantamientoSummary(oppId);
System.debug('--- INTEGRATION TEST START ---');
System.debug('Total items returned: ' + result.size());
for(Map<String, String> m : result) {
    System.debug('Record: ' + m);
}
System.debug('--- INTEGRATION TEST END ---');