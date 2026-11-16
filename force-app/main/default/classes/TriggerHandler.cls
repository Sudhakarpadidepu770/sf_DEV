public virtual class TriggerHandler {

    public void run() {

        if (Trigger.isBefore) {

            if (Trigger.isInsert) {
                beforeInsert();
            }
            else if (Trigger.isUpdate) {
                beforeUpdate();
            }
            else if (Trigger.isDelete) {
                beforeDelete();
            }

        }
        else if (Trigger.isAfter) {

            if (Trigger.isInsert) {
                afterInsert();
            }
            else if (Trigger.isUpdate) {
                afterUpdate();
            }
            else if (Trigger.isDelete) {
                afterDelete();
            }
            else if (Trigger.isUndelete) {
                afterUndelete();
            }
        }
    }

    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}

    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}
}