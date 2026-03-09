System.debug('### DIAGNÓSTICO PYATZ ###'); 
System.debug('Tracking Field Accessible: ' + Schema.sObjectType.EmailMessage.fields.IsOpened.isAccessible()); 
List<EmailMessage> opened = [SELECT Id FROM EmailMessage WHERE IsOpened = true LIMIT 1]; 
System.debug('Has any email ever been opened in this Org: ' + !opened.isEmpty());
List<EmailMessage> recent = [SELECT Id, Subject, IsOpened, FirstOpenedDate FROM EmailMessage WHERE RelatedToId = '006V900000Nz6KzIAJ' LIMIT 5];
for(EmailMessage em : recent) {
    System.debug('Email: ' + em.Subject + ' | IsOpened: ' + em.IsOpened + ' | FirstOpen: ' + em.FirstOpenedDate);
}