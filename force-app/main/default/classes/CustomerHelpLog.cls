/**
 * Audit/troubleshooting log using the standard Task object (visible on the Account's activity timeline).
 * Subject always starts with "Customer Help:" so data sources can exclude these rows from customer answers.
 * Buffered so logging DML never precedes a callout in the same transaction.
 * NEVER log OTP codes, balances, or other customer values - outcome codes and exception text only.
 * Deeper conversation-level tracing: use Agentforce session tracing / Einstein audit & feedback.
 */
public without sharing class CustomerHelpLog {
    public static final String SUBJECT_PREFIX = 'Customer Help: ';
    @TestVisible private static List<Task> buffer = new List<Task>();

    public static void record(String action, String sessionId, Id accountId, String outcome, String detail) {
        String body = 'Session: ' + sessionId + (detail == null ? '' : '\n' + detail);
        buffer.add(new Task(
            Subject = (SUBJECT_PREFIX + action + ' - ' + outcome).left(255),
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today(),
            WhatId = accountId,
            Description = body.left(32000)
        ));
    }

    public static void flush() {
        if (buffer.isEmpty()) {
            return;
        }
        try {
            Database.insert(buffer, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CustomerHelpLog flush failed: ' + e.getMessage());
        } finally {
            buffer.clear();
        }
    }
}