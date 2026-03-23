List<Account> accs = [SELECT Id, Name FROM Account WHERE Name LIKE '%Pyatz%' LIMIT 5];
for(Account a : accs) {
    System.debug('Cuenta encontrada: ' + a.Name + ' ID: ' + a.Id);
}
if(accs.isEmpty()) {
    System.debug('No se encontró cuenta de Pyatz. Se recomienda crear una cuenta técnica "Pyatz Corporativo".');
}