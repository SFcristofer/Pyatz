Map<Id, String> templateUpdates = new Map<Id, String>{
    'a16V9000000xVm9IAE' => '1',
    'a16V9000000xVmAIAU' => '2',
    'a16V9000000xVmBIAU' => '3',
    'a16V9000000xVmCIAU' => '4',
    'a16V9000000xVmDIAU' => '5',
    'a16V9000000xVmEIAU' => '6',
    'a16V9000000xVmFIAU' => '7',
    'a16V9000000xVmGIAU' => '8',
    'a16V9000000xVmHIAU' => '9',
    'a16V9000000xVmJIAU' => '11',
    'a16V9000000xVmKIAU' => '12',
    'a16V9000000xVmLIAU' => '13',
    'a16V9000000xVmMIAU' => '14',
    'a16V9000000xVmNIAU' => '15',
    'a16V9000000xVmOIAU' => '16'
};

List<Form_Template__c> templatesToUpdate = new List<Form_Template__c>();
for(Id tId : templateUpdates.keySet()) {
    templatesToUpdate.add(new Form_Template__c(Id = tId, Tipo_Reporte__c = templateUpdates.get(tId)));
}
update templatesToUpdate;
System.debug('Actualizados ' + templatesToUpdate.size() + ' registros.');
