List<Attachment> atts = [SELECT Id, ParentId, Parent.Type, Name FROM Attachment ORDER BY CreatedDate DESC LIMIT 20];
for(Attachment a : atts) {
    System.debug('Attachment: ' + a.Name + ' | ParentType: ' + a.Parent.Type + ' | ParentId: ' + a.ParentId);
}
