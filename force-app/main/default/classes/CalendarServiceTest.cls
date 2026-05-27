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
        Task t = new Task(Subject = 'Test Call', WhatId = opp.Id, Status = 'Open', TaskSubtype = 'Call');
        insert t;
        Event e = new Event(Subject = 'Test Event', WhatId = opp.Id,
            StartDateTime = Datetime.now(), EndDateTime = Datetime.now().addHours(1));
        insert e;
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
