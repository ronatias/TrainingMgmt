trigger TrainingEnrollmentTrigger on Training_Enrollment__c (
    before insert, before update,
    after insert
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            TrainingEnrollmentTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            TrainingEnrollmentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TrainingEnrollmentTriggerHandler.afterInsert(Trigger.new);
        }
    }
}