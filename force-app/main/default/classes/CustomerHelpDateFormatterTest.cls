@IsTest
private class CustomerHelpDateFormatterTest {
    private static final Date TODAY = Date.newInstance(2026, 9, 19);

    @IsTest
    static void speaksNaturalDates() {
        System.assertEquals('September fifteenth', CustomerHelpDateFormatter.speak(Date.newInstance(2026, 9, 15), TODAY));
        System.assertEquals('yesterday', CustomerHelpDateFormatter.speak(Date.newInstance(2026, 9, 18), TODAY));
        System.assertEquals('today', CustomerHelpDateFormatter.speak(TODAY, TODAY));
        System.assertEquals('tomorrow', CustomerHelpDateFormatter.speak(Date.newInstance(2026, 9, 20), TODAY));
        System.assertEquals('March twenty third, 2025', CustomerHelpDateFormatter.speak(Date.newInstance(2025, 3, 23), TODAY));
        System.assertEquals(null, CustomerHelpDateFormatter.speak((Date) null, TODAY));
    }

    @IsTest
    static void speaksAge() {
        System.assertEquals('less than a day', CustomerHelpDateFormatter.speakAge(TODAY, TODAY));
        System.assertEquals('1 day', CustomerHelpDateFormatter.speakAge(Date.newInstance(2026, 9, 18), TODAY));
        System.assertEquals('4 days', CustomerHelpDateFormatter.speakAge(Date.newInstance(2026, 9, 15), TODAY));
        System.assertEquals('3 weeks', CustomerHelpDateFormatter.speakAge(Date.newInstance(2026, 8, 28), TODAY));
        System.assertEquals('3 months', CustomerHelpDateFormatter.speakAge(Date.newInstance(2026, 6, 10), TODAY));
        System.assertEquals(null, CustomerHelpDateFormatter.speakAge(Date.newInstance(2026, 10, 1), TODAY));
    }

    @IsTest
    static void datetimeNeverLooksLikeIso() {
        String s = CustomerHelpDateFormatter.speakWithTime(Datetime.now().addDays(-40));
        System.assert(!s.contains('T') || !s.contains('Z'), 'no ISO output');
        System.assert(s.contains(' at '));
    }
}