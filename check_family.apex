for(Schema.PicklistEntry f : Product2.Family.getDescribe().getPicklistValues()) { 
    System.debug('VALOR_ENCONTRADO: ' + f.getLabel() + ' - Activo: ' + f.isActive()); 
}