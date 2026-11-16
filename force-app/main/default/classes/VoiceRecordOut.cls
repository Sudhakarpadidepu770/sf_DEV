/** One customer-facing record, already translated into speakable values. Contains no record Ids. */
public with sharing class VoiceRecordOut {
    @InvocableVariable(label='Title') public String title;
    @InvocableVariable(label='Status (spoken)') public String status;
    @InvocableVariable(label='Next Step') public String nextStep;
    @InvocableVariable(label='Primary Date (spoken)') public String primaryDate;
    @InvocableVariable(label='Age (spoken)') public String age;
    @InvocableVariable(label='Details') public String details;
}