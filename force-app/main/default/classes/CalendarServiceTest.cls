@isTest
private class CalendarServiceTest {

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'Cal Test Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Cal Opp', AccountId = acc.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;
        Contact c = new Contact(FirstName = 'Test', LastName = 'Contact', Phone = '555-1234');
        insert c;
        Task t = new Task(Subject = 'Test Call', WhatId = opp.Id, WhoId = c.Id, Status = 'Open', TaskSubtype = 'Call');
        insert t;
        Event e = new Event(Subject = 'Test Event', WhatId = opp.Id, WhoId = c.Id,
            StartDateTime = Datetime.now(), EndDateTime = Datetime.now().addHours(1));
        insert e;
        EmailMessage em = new EmailMessage(Subject = 'Test Email', RelatedToId = opp.Id, ToAddress = 'test@example.com', Status = '3');
        insert em;

        Profile p = [SELECT Id FROM Profile LIMIT 1];
        User u = new User(Alias = 'stdu', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='standarduser_' + Math.random() + '@testorg.com');
        insert u;

        OperatingHours oh = new OperatingHours(Name = 'Test Hours', TimeZone = 'America/Los_Angeles');
        insert oh;
        TimeSlot ts = new TimeSlot(OperatingHoursId = oh.Id, DayOfWeek = 'Monday', Type = 'Normal', StartTime = Time.newInstance(9, 0, 0, 0), EndTime = Time.newInstance(17, 0, 0, 0));
        insert ts;

        ServiceResource sr = new ServiceResource(Name = 'Test Resource', RelatedRecordId = u.Id, IsActive = true, ResourceType = 'T');
        insert sr;
        ServiceTerritory st = new ServiceTerritory(Name = 'Test Territory', OperatingHoursId = oh.Id, IsActive = true);
        insert st;
        ServiceTerritoryMember stm = new ServiceTerritoryMember(ServiceResourceId = sr.Id, ServiceTerritoryId = st.Id, OperatingHoursId = oh.Id, EffectiveStartDate = Datetime.now().addDays(-1));
        insert stm;

        ServiceAppointment sa = new ServiceAppointment(ParentRecordId = opp.Id, SchedStartTime = Datetime.now().addDays(1), SchedEndTime = Datetime.now().addDays(1).addHours(1), Status = 'None', Subject = 'SA Test');
        insert sa;
        AssignedResource ar = new AssignedResource(ServiceAppointmentId = sa.Id, ServiceResourceId = sr.Id, EstimatedTravelTime = 10, ActualTravelTime = 15);
        insert ar;
        
        ServiceAppointment sa2 = new ServiceAppointment(ParentRecordId = opp.Id, SchedStartTime = Datetime.now().addDays(1), SchedEndTime = Datetime.now().addDays(1).addHours(1), Status = 'None', Subject = 'SA Test Unassigned');
        insert sa2;
    }

    @isTest
    static void testGetCalendarData() {
        String startDate = String.valueOf(Date.today().addDays(-1));
        String endDate = String.valueOf(Date.today().addDays(7));
        Test.startTest();
        Map<String, Object> result = CalendarService.getCalendarData(startDate, endDate);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('resources'));
        System.assert(result.containsKey('appointments'));
    }

    @isTest
    static void testGetCalendarData_invalidDate() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            CalendarService.getCalendarData('not-a-date', 'also-not');
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown);
    }

    @isTest
    static void testGetActionTimeline_null() {
        Test.startTest();
        List<Map<String, Object>> result = CalendarService.getActionTimeline(null);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetActionTimeline_withData() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Map<String, Object>> result = CalendarService.getActionTimeline(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(result.size() >= 2);
    }
}