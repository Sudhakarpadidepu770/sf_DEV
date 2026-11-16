/**
 * Maps raw status values (e.g. "Working", "Negotiation/Review") to customer-friendly phrases, per data source.
 * Unmapped values fall back to the humanised raw value - add the phrase here when you meet a new status.
 */
public with sharing class CustomerHelpStatusPhrases {
    public class Phrase {
        public String text;
        public String nextStep;
    }

    private static final Map<String, Map<String, Phrase>> REGISTRY = build();

    /** Keyed by lower-cased raw status value. */
    public static Map<String, Phrase> load(String sourceKey) {
        Map<String, Phrase> found = REGISTRY.get(sourceKey);
        return found == null ? new Map<String, Phrase>() : found;
    }

    public static String humanize(String raw) {
        return raw == null ? null : raw.replace('_', ' ').toLowerCase();
    }

    private static Map<String, Map<String, Phrase>> build() {
        Map<String, Map<String, Phrase>> m = new Map<String, Map<String, Phrase>>();
        for (String key : new List<String>{ 'Open_Cases', 'Service_Request' }) {
            add(m, key, 'New', 'received and waiting to be picked up', 'A representative will review it soon.');
            add(m, key, 'Working', 'being worked on by our team', 'We will update you when there is progress.');
            add(m, key, 'Escalated', 'with a senior specialist', 'A specialist is reviewing it.');
            add(m, key, 'On Hold', 'on hold while we wait for more information', 'We may contact you for more details.');
            add(m, key, 'Closed', 'resolved and closed', null);
        }
        add(m, 'Account_Information', 'Active', 'active', null);
        add(m, 'Account_Information', 'Dormant', 'currently inactive', 'A representative can help reactivate it.');
        add(m, 'Account_Information', 'Suspended', 'temporarily suspended', 'A representative can explain why.');
        add(m, 'Account_Information', 'Closed', 'closed', null);
        String app = 'Application_Status';
        add(m, app, 'Prospecting', 'received and waiting to be reviewed', 'Our team will start reviewing it shortly.');
        add(m, app, 'Qualification', 'currently being processed', 'We will notify you when there is an update.');
        add(m, app, 'Needs Analysis', 'currently being processed', 'We will notify you when there is an update.');
        add(m, app, 'Value Proposition', 'currently being processed', 'We will notify you when there is an update.');
        add(m, app, 'Proposal/Price Quote', 'in its final review', 'You will receive next steps soon.');
        add(m, app, 'Negotiation/Review', 'in its final review', 'You will receive next steps soon.');
        add(m, app, 'Closed Won', 'approved', 'You will receive next steps by message.');
        add(m, app, 'Closed Lost', 'not approved', 'A representative can explain the decision.');
        add(m, 'Required_Documents', 'Not Started', 'still needed', 'Please send it as soon as you can.');
        add(m, 'Required_Documents', 'In Progress', 'being followed up', null);
        return m;
    }

    private static void add(Map<String, Map<String, Phrase>> m, String key, String status, String text, String next) {
        if (!m.containsKey(key)) {
            m.put(key, new Map<String, Phrase>());
        }
        Phrase p = new Phrase();
        p.text = text;
        p.nextStep = next;
        m.get(key).put(status.toLowerCase(), p);
    }
}