/**
 * Customer verification for voice sessions - standard platform features only.
 *
 * Trust model:
 *  - Caller ID is only a *hint* to find the Account whose Phone matches; it never authenticates.
 *  - Authentication = one-time code sent to the Phone number ON FILE for that Account.
 *  - Every data action re-derives the Account from the verified session (requireVerifiedAccount).
 *    The LLM never supplies a customer identifier.
 *
 * State lives in Platform Cache (org partition local.VoiceSession) with TTLs, so no custom object is needed and
 * expired state disappears on its own. If the cache is unavailable or evicted the session simply is not
 * verified (fails closed) and the customer verifies again.
 *
 * Runs without sharing: it must find the Account by phone regardless of the agent user's sharing; it returns
 * only an Id that stays server-side.
 */
public without sharing class VoiceIdentityService {
    public class VoiceAuthException extends Exception {}

    public static final Integer MAX_ATTEMPTS = 3;
    public static final Integer CODE_TTL_SECONDS = 300;      // Platform Cache minimum TTL is 300 s
    public static final Integer VERIFIED_TTL_SECONDS = 900;
    public static final Integer MAX_SENDS_PER_HOUR = 3;
    private static final String PARTITION = 'local.VoiceSession';

    @TestVisible private static String capturedCode;

    public class StartResult {
        public Boolean accepted = true;
        public Boolean rateLimited = false;
    }

    public class CheckResult {
        public Boolean verified = false;
        public Boolean locked = false;
        public Integer attemptsLeft = 0;
        public String customerName;
    }

    private class Pending {
        String accountId;
        String salt;
        String hash;
        Long expiresAtMs;
        Integer attempts = 0;
    }

    private class SendWindow {
        Long startMs;
        Integer count = 0;
    }

    /** Always "accepted" unless rate limited, so the response cannot be used to probe which numbers exist. */
    public static StartResult start(String sessionId, String phone) {
        StartResult r = new StartResult();
        if (String.isBlank(sessionId)) {
            throw new VoiceAuthException('Missing session id');
        }
        String norm = VoicePhone.normalize(phone);
        if (norm == null || norm.length() < 7) {
            VoiceLog.record('VerifyStart', sessionId, null, 'INVALID_PHONE', null);
            return r;
        }
        Account acct = findAccountByPhone(norm);
        if (acct == null) {
            VoiceLog.record('VerifyStart', sessionId, null, 'NO_UNIQUE_MATCH', null);
            return r;
        }

        Long now = Datetime.now().getTime();
        String windowKey = key('snd', acct.Id);
        Object rawWindow = cache().get(windowKey);
        SendWindow w = rawWindow == null ? null : (SendWindow) JSON.deserialize((String) rawWindow, SendWindow.class);
        if (w == null || now - w.startMs > 3600000L) {
            w = new SendWindow();
            w.startMs = now;
        }
        if (w.count >= MAX_SENDS_PER_HOUR) {
            r.rateLimited = true;
            VoiceLog.record('VerifyStart', sessionId, acct.Id, 'RATE_LIMITED', null);
            return r;
        }
        w.count++;
        cache().put(windowKey, JSON.serialize(w), 3600);

        String code = String.valueOf(Math.abs(Math.mod(Crypto.getRandomInteger(), 1000000))).leftPad(6, '0');
        Pending p = new Pending();
        p.accountId = acct.Id;
        p.salt = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        p.hash = hash(p.salt, sessionId, code);
        p.expiresAtMs = now + CODE_TTL_SECONDS * 1000L;
        cache().put(key('pnd', sessionId), JSON.serialize(p), CODE_TTL_SECONDS); // replaces any earlier pending code

        System.enqueueJob(new VoiceOtpSender(acct.Phone, code));
        if (Test.isRunningTest()) {
            capturedCode = code;
        }
        VoiceLog.record('VerifyStart', sessionId, acct.Id, 'CODE_SENT', null);
        return r;
    }

    public static CheckResult check(String sessionId, String spokenCode) {
        CheckResult r = new CheckResult();
        // STT may return "123 456" or "1-2-3-4-5-6"; keep digits only.
        String code = spokenCode == null ? '' : spokenCode.replaceAll('[^0-9]', '');
        String pendingKey = key('pnd', sessionId);
        Object raw = cache().get(pendingKey);
        if (raw == null) {
            return r;
        }
        Pending p = (Pending) JSON.deserialize((String) raw, Pending.class);
        Long now = Datetime.now().getTime();
        if (p.expiresAtMs < now) {
            cache().remove(pendingKey);
            VoiceLog.record('VerifyCheck', sessionId, p.accountId, 'EXPIRED', null);
            return r;
        }
        p.attempts++;
        if (hash(p.salt, sessionId, code) == p.hash) {
            cache().remove(pendingKey);
            storeVerified(sessionId, p.accountId);
            r.verified = true;
            List<Account> a = [SELECT Name FROM Account WHERE Id = :p.accountId LIMIT 1];
            r.customerName = a.isEmpty() ? null : a[0].Name;
            VoiceLog.record('VerifyCheck', sessionId, p.accountId, 'VERIFIED', null);
        } else if (p.attempts >= MAX_ATTEMPTS) {
            cache().remove(pendingKey);
            r.locked = true;
            VoiceLog.record('VerifyCheck', sessionId, p.accountId, 'LOCKED', null);
        } else {
            Integer remaining = Math.max(300, (Integer) ((p.expiresAtMs - now) / 1000)); // real expiry enforced via expiresAtMs
            cache().put(pendingKey, JSON.serialize(p), remaining);
            VoiceLog.record('VerifyCheck', sessionId, p.accountId, 'BAD_CODE', null);
        }
        r.attemptsLeft = Math.max(0, MAX_ATTEMPTS - p.attempts);
        return r;
    }

    /** The only way data actions learn who the customer is. Throws if the session is not verified. */
    public static Id requireVerifiedAccount(String sessionId) {
        if (String.isBlank(sessionId)) {
            throw new VoiceAuthException('Missing session id');
        }
        Object v = cache().get(key('ver', sessionId));
        if (v == null) {
            throw new VoiceAuthException('Session is not verified');
        }
        return Id.valueOf((String) v);
    }

    /**
     * NO-OTP MODE: identifies the caller by caller ID alone. Anyone who can present a registered phone number
     * (including a spoofed caller ID) is treated as that customer. Use VoiceIdentityService.start/check (OTP) instead
     * where that risk is not acceptable.
     */
    public static CheckResult identifyByCallerId(String sessionId, String phone) {
        CheckResult r = new CheckResult();
        if (String.isBlank(sessionId)) {
            throw new VoiceAuthException('Missing session id');
        }
        String norm = VoicePhone.normalize(phone);
        Account acct = (norm == null || norm.length() < 7) ? null : findAccountByPhone(norm);
        if (acct == null) {
            VoiceLog.record('IdentifyCaller', sessionId, null, 'NO_UNIQUE_MATCH', null);
            return r;
        }
        storeVerified(sessionId, acct.Id);
        r.verified = true;
        r.customerName = acct.Name;
        VoiceLog.record('IdentifyCaller', sessionId, acct.Id, 'IDENTIFIED_BY_CALLER_ID', null);
        return r;
    }

    @TestVisible
    private static void storeVerified(String sessionId, Id accountId) {
        cache().put(key('ver', sessionId), String.valueOf(accountId), VERIFIED_TTL_SECONDS);
    }

    /**
     * SOSL phone search ignores formatting; fall back to a wildcard SOQL on Phone (also what runs in tests).
     * Accepted only when exactly one Account's normalised phone equals the caller's number.
     */
    private static Account findAccountByPhone(String norm) {
        List<Account> candidates = new List<Account>();
        List<List<SObject>> found = [FIND :norm IN PHONE FIELDS RETURNING Account(Id, Name, Phone LIMIT 5)];
        for (SObject s : found[0]) {
            candidates.add((Account) s);
        }
        if (candidates.isEmpty() && norm.length() == 10) {
            String pattern = '%' + norm.substring(0, 3) + '%' + norm.substring(3, 6) + '%' + norm.substring(6);
            candidates = [SELECT Id, Name, Phone FROM Account WHERE Phone LIKE :pattern LIMIT 5];
        }
        List<Account> exact = new List<Account>();
        for (Account a : candidates) {
            if (VoicePhone.normalize(a.Phone) == norm) {
                exact.add(a);
            }
        }
        return exact.size() == 1 ? exact[0] : null;
    }

    private static Cache.OrgPartition cache() {
        return Cache.Org.getPartition(PARTITION);
    }

    /** Platform Cache keys must be alphanumeric. */
    private static String key(String prefix, String id) {
        return prefix + String.valueOf(id).replaceAll('[^A-Za-z0-9]', '');
    }

    private static String hash(String salt, String sessionId, String code) {
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(salt + '|' + sessionId + '|' + code))
        );
    }
}