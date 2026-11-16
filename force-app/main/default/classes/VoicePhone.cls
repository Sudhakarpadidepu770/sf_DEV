/**
 * Phone normalisation: reduces any format to the last 10 digits so caller ID and Account.Phone can be compared.
 * Last-10 heuristic; extend for countries with other number lengths.
 */
public with sharing class VoicePhone {
    public static String normalize(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String digits = raw.replaceAll('[^0-9]', '');
        return digits.length() > 10 ? digits.substring(digits.length() - 10) : digits;
    }
}