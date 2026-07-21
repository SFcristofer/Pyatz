for(Schema.PicklistEntry p : ControlPointVisit__c.Result__c.getDescribe().getPicklistValues()) {
    System.debug('PICKLIST: ' + p.getValue());
}
