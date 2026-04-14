Quote q = [SELECT Id, Name, Account.Name, Opportunity.Name, CreatedDate FROM Quote ORDER BY CreatedDate DESC LIMIT 1];
System.debug('--- DETALLES DEL PRESUPUESTO ---');
System.debug('NOMBRE: ' + q.Name);
System.debug('CLIENTE: ' + (q.Account.Name != null ? q.Account.Name : 'SIN CUENTA VINCULADA'));
System.debug('OPORTUNIDAD: ' + (q.Opportunity.Name != null ? q.Opportunity.Name : 'SIN OPORTUNIDAD VINCULADA'));
System.debug('FECHA CREACIÓN: ' + q.CreatedDate);
System.debug('-------------------------------');
