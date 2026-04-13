for(ServiceResource sr : [SELECT Name, (SELECT ServiceTerritoryId, ServiceTerritory.Name FROM ServiceTerritoryMembers WHERE IsActive=true) FROM ServiceResource WHERE IsActive=true]) {
    String terrs = '';
    for(ServiceTerritoryMember stm : sr.ServiceTerritoryMembers) terrs += stm.ServiceTerritory.Name + ' (' + stm.ServiceTerritoryId + '), ';
    System.debug('DIAGNOSTICO: Tecnico: ' + sr.Name + ' - Territorios: ' + terrs);
}
for(ServiceTerritory st : [SELECT Name, Id FROM ServiceTerritory WHERE IsActive=true]) {
    System.debug('DIAGNOSTICO: Territorio Activo: ' + st.Name + ' (' + st.Id + ')');
}