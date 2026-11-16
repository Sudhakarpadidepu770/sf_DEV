/**
 * Turns Salesforce Date/Datetime values into text that sounds natural through TTS.
 * Never returns ISO timestamps. Uses the running user's time zone (set the agent user's zone to your business zone).
 */
public with sharing class VoiceDateFormatter {
    private static final List<String> MONTHS = new List<String>{
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    };
    private static final List<String> ORDINALS = new List<String>{
        '', 'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth',
        'eleventh', 'twelfth', 'thirteenth', 'fourteenth', 'fifteenth', 'sixteenth', 'seventeenth',
        'eighteenth', 'nineteenth', 'twentieth', 'twenty first', 'twenty second', 'twenty third',
        'twenty fourth', 'twenty fifth', 'twenty sixth', 'twenty seventh', 'twenty eighth',
        'twenty ninth', 'thirtieth', 'thirty first'
    };

    /** Plain written dates for text chat (employee agent): "Sep 15, 2026". */
    public static String text(Date d) {
        return d == null ? null : Datetime.newInstanceGmt(d, Time.newInstance(0, 0, 0, 0)).formatGmt('MMM d, yyyy');
    }

    public static String text(Datetime dt) {
        return dt == null ? null : dt.format('MMM d, yyyy h:mm a', tz());
    }

    public static String speak(Date d) {
        return speak(d, localToday());
    }

    public static String speak(Date d, Date today) {
        if (d == null) {
            return null;
        }
        Integer daysAgo = d.daysBetween(today);
        if (daysAgo == 0) {
            return 'today';
        }
        if (daysAgo == 1) {
            return 'yesterday';
        }
        if (daysAgo == -1) {
            return 'tomorrow';
        }
        String s = MONTHS[d.month()] + ' ' + ORDINALS[d.day()];
        return d.year() == today.year() ? s : s + ', ' + d.year();
    }

    public static String speak(Datetime dt) {
        return dt == null ? null : speak(localDate(dt), localToday());
    }

    public static String speakWithTime(Datetime dt) {
        if (dt == null) {
            return null;
        }
        return speak(dt) + ' at ' + dt.format('h:mm a', tz());
    }

    /** "How long has it been pending?" -> "3 days". */
    public static String speakAge(Datetime dt) {
        return dt == null ? null : speakAge(localDate(dt), localToday());
    }

    public static String speakAge(Date d, Date today) {
        if (d == null) {
            return null;
        }
        Integer days = d.daysBetween(today);
        if (days < 0) {
            return null;
        }
        if (days == 0) {
            return 'less than a day';
        }
        if (days == 1) {
            return '1 day';
        }
        if (days < 14) {
            return days + ' days';
        }
        if (days < 60) {
            return (days / 7) + ' weeks';
        }
        return (days / 30) + ' months';
    }

    private static String tz() {
        return UserInfo.getTimeZone().getID();
    }

    private static Date localDate(Datetime dt) {
        return Date.valueOf(dt.format('yyyy-MM-dd', tz()));
    }

    private static Date localToday() {
        return localDate(Datetime.now());
    }
}