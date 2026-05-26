Account a = [SELECT Id, (SELECT Id FROM Contacts) FROM Account WHERE Id IN (SELECT AccountId FROM Contact) LIMIT 1];
System.debug(JSON.serialize(a));
