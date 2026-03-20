try {
    // Buscar en Contract estandar
    List<SObject> contracts = Database.query('SELECT Id, ContractNumber FROM Contract LIMIT 10');
    System.debug('OK: Encontrados ' + contracts.size() + ' registros en Contract.');
} catch(Exception e) {
    System.debug('ERR en Contract: ' + e.getMessage());
}

try {
    // Buscar en ServiceContract
    List<SObject> sContracts = Database.query('SELECT Id, ContractNumber FROM ServiceContract LIMIT 10');
    System.debug('OK: Encontrados ' + sContracts.size() + ' registros en ServiceContract.');
} catch(Exception e) {
    System.debug('ERR en ServiceContract: ' + e.getMessage());
}