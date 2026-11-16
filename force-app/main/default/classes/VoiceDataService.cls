/**
 * Registry-driven retrieval. Each customer question ("intent") is one VoiceDataSources entry naming a standard
 * object, the field linking it to the verified Account, the fields to return and its status/date fields.
 * Adding a question = one registry entry (+ optional thin action class), not new query code.
 * Security layers:
 *  1. Customer comes from VoiceIdentityService (verified session) - never from LLM input.
 *  2. Query is scoped to that customer's lookup; the optional record hint is a bind variable.
 *  3. Object/field names come only from the code-reviewed VoiceDataSources registry and are validated against the schema.
 *  4. AccessLevel.USER_MODE enforces object permissions, FLS and sharing for the agent user.
 */
public with sharing class VoiceDataService {
    public class VoiceConfigException extends Exception {}

    private static final Integer HARD_ROW_CAP = 10;

    public static VoiceActionResponse fetch(String intentKey, String sessionId, String recordHint) {
        return query(intentKey, VoiceIdentityService.requireVerifiedAccount(sessionId), recordHint, false);
    }

    /**
     * Employee mode: the caller is a signed-in employee running the agent as themselves, so the account comes from
     * the employee's own selection and every query runs in user mode (their permissions and sharing apply).
     */
    public static VoiceActionResponse fetchForAccount(String intentKey, Id accountId, String recordHint) {
        if (accountId == null) {
            throw new VoiceConfigException('No customer selected');
        }
        return query(intentKey, accountId, recordHint, true);
    }

    private static VoiceActionResponse query(String intentKey, Id accountId, String recordHint, Boolean employeeMode) {
        VoiceDataSources.Source cfg = VoiceDataSources.get(intentKey);
        if (cfg == null || cfg.active != true) {
            throw new VoiceConfigException('Data source unavailable: ' + intentKey);
        }
        Schema.SObjectType st = Schema.getGlobalDescribe().get(cfg.objectName);
        if (st == null) {
            throw new VoiceConfigException('Unknown object ' + cfg.objectName);
        }
        Map<String, Schema.SObjectField> fmap = st.getDescribe().fields.getMap();

        List<String> fields = splitList(cfg.fields);
        Set<String> masked = new Set<String>();
        for (String m : splitList(cfg.maskedFields)) {
            masked.add(m.toLowerCase());
        }
        if (employeeMode == true) {
            masked.clear(); // staff may see full values
        }
        List<String> selectFields = new List<String>();
        Set<String> seen = new Set<String>();
        List<String> required = new List<String>(fields);
        required.add(cfg.ownerLookup);
        for (String opt : new List<String>{ cfg.statusField, cfg.dateField, cfg.orderField, cfg.identifierField }) {
            if (String.isNotBlank(opt)) {
                required.add(opt);
            }
        }
        for (String f : required) {
            if (!fmap.containsKey(f.toLowerCase())) {
                throw new VoiceConfigException('Unknown field ' + cfg.objectName + '.' + f);
            }
            if (seen.add(f.toLowerCase())) {
                selectFields.add(f);
            }
        }

        // Account is the customer: every data source links to the verified Account via its Owner Lookup Field.
        Id ownerId = accountId;

        String soql = 'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + cfg.objectName
            + ' WHERE ' + cfg.ownerLookup + ' = :ownerId';
        Map<String, Object> binds = new Map<String, Object>{ 'ownerId' => ownerId };
        if (String.isNotBlank(recordHint) && String.isNotBlank(cfg.identifierField)) {
            soql += ' AND ' + cfg.identifierField + ' = :hint';
            binds.put('hint', recordHint.trim());
        }
        if (String.isNotBlank(cfg.extraFilter)) {
            soql += ' AND (' + cfg.extraFilter + ')';
        }
        if (String.isNotBlank(cfg.orderField)) {
            soql += ' ORDER BY ' + cfg.orderField + ' DESC NULLS LAST';
        }
        Integer cap = cfg.maxRows == null ? 5 : Math.min(cfg.maxRows, HARD_ROW_CAP);
        soql += ' LIMIT ' + cap;

        List<SObject> rows = Database.queryWithBinds(soql, binds, (employeeMode != true && cfg.systemMode == true) ? AccessLevel.SYSTEM_MODE : AccessLevel.USER_MODE);

        Map<String, VoiceStatusPhrases.Phrase> phrases = employeeMode == true ? new Map<String, VoiceStatusPhrases.Phrase>() : VoiceStatusPhrases.load(intentKey);
        List<VoiceRecordOut> out = new List<VoiceRecordOut>();
        for (SObject r : rows) {
            out.add(toOut(r, fields, fmap, masked, cfg, phrases, employeeMode == true));
        }
        VoiceActionResponse resp = VoiceActionResponse.ok('Salesforce', out);
        if (employeeMode == true && !out.isEmpty()) {
            resp.agentGuidance = 'Text chat for an employee. Summarise concisely; use a short list when there are several records. Never show IDs.';
        }
        return resp;
    }

    private static VoiceRecordOut toOut(
        SObject r, List<String> fields, Map<String, Schema.SObjectField> fmap, Set<String> masked,
        VoiceDataSources.Source cfg, Map<String, VoiceStatusPhrases.Phrase> phrases, Boolean textMode
    ) {
        VoiceRecordOut o = new VoiceRecordOut();
        List<String> parts = new List<String>();
        for (String f : fields) {
            String spoken = toSpoken(fmap.get(f.toLowerCase()).getDescribe(), r.get(f), masked.contains(f.toLowerCase()), textMode);
            if (spoken == null) {
                continue;
            }
            if (o.title == null) {
                o.title = spoken;
            }
            parts.add(fmap.get(f.toLowerCase()).getDescribe().getLabel() + ': ' + spoken);
        }
        o.details = String.join(parts, '. ');

        if (String.isNotBlank(cfg.statusField) && r.get(cfg.statusField) != null) {
            String raw = String.valueOf(r.get(cfg.statusField));
            VoiceStatusPhrases.Phrase p = phrases.get(raw.toLowerCase());
            o.status = p != null ? p.text : (textMode ? raw : VoiceStatusPhrases.humanize(raw));
            o.nextStep = p != null ? p.nextStep : null;
        }
        if (String.isNotBlank(cfg.dateField)) {
            Object dv = r.get(cfg.dateField);
            if (dv instanceof Datetime) {
                o.primaryDate = textMode ? VoiceDateFormatter.text((Datetime) dv) : VoiceDateFormatter.speak((Datetime) dv);
                o.age = VoiceDateFormatter.speakAge((Datetime) dv);
            } else if (dv instanceof Date) {
                o.primaryDate = textMode ? VoiceDateFormatter.text((Date) dv) : VoiceDateFormatter.speak((Date) dv);
                o.age = VoiceDateFormatter.speakAge((Date) dv, Date.today());
            }
        }
        return o;
    }

    private static String toSpoken(Schema.DescribeFieldResult d, Object v, Boolean mask, Boolean textMode) {
        if (v == null) {
            return null;
        }
        if (mask) {
            String tail = String.valueOf(v).replaceAll('[^0-9A-Za-z]', '');
            tail = tail.right(4);
            List<String> chars = new List<String>();
            for (Integer i = 0; i < tail.length(); i++) {
                chars.add(tail.substring(i, i + 1));
            }
            return 'ending in ' + String.join(chars, ' ');
        }
        if (v instanceof Datetime) {
            return textMode ? VoiceDateFormatter.text((Datetime) v) : VoiceDateFormatter.speak((Datetime) v);
        }
        if (v instanceof Date) {
            return textMode ? VoiceDateFormatter.text((Date) v) : VoiceDateFormatter.speak((Date) v);
        }
        if (v instanceof Boolean) {
            return ((Boolean) v) ? 'yes' : 'no';
        }
        if (d.getType() == Schema.DisplayType.PICKLIST) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.getValue() == String.valueOf(v)) {
                    return pe.getLabel();
                }
            }
        }
        if (d.getType() == Schema.DisplayType.CURRENCY && v instanceof Decimal) {
            return ((Decimal) v).setScale(2).format() + ' ' + UserInfo.getDefaultCurrency();
        }
        return String.valueOf(v);
    }

    private static List<String> splitList(String csv) {
        List<String> out = new List<String>();
        if (String.isBlank(csv)) {
            return out;
        }
        for (String s : csv.split(',')) {
            if (String.isNotBlank(s)) {
                out.add(s.trim());
            }
        }
        return out;
    }
}