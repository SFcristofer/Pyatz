// Corrección de permisos de imágenes para PDF usando IsPublic
List<Document> docs = [SELECT Id, Name, IsPublic FROM Document WHERE Id IN ('015V9000005wj9xIAA', '015V9000005wjDBIAY', '015V90000068RcHIAU', '015V90000068RdtIAE')];
for(Document d : docs) {
    d.IsPublic = true;
    System.debug('ACTUALIZANDO_DOC: ' + d.Name + ' | ID: ' + d.Id);
}
update docs;
System.debug('DISPONIBILIDAD_PUBLICA_ACTUALIZADA');