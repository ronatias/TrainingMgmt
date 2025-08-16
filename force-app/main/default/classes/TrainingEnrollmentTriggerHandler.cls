public class TrainingEnrollmentTriggerHandler {

    /** 
     * BEFORE INSERT:
     * - Enforce OwnerId = Employee__c
     * - Build Enrollment_Key__c = Employee__c + '-' + Training__c
     * - Basic required-field guardrails (fast fail)
     */
    public static void beforeInsert(List<Training_Enrollment__c> newList) {
        for (Training_Enrollment__c te : newList) {
            if (te.Employee__c == null) {
                te.addError('Employee is required.');
                continue;
            }
            if (te.Training__c == null) {
                te.addError('Training is required.');
                continue;
            }

            // Keep Owner in sync with Employee (assignment allowed in BEFORE)
            te.OwnerId = te.Employee__c;

            // DB-level uniqueness (Enrollment_Key__c must be Unique, case-insensitive)
            te.Enrollment_Key__c = te.Employee__c + '-' + te.Training__c;
        }
    }

    /**
     * BEFORE UPDATE:
     * - Keep OwnerId synced with Employee__c
     * - Rebuild Enrollment_Key__c if Employee/Training changed (or key blank)
     */
    public static void beforeUpdate(List<Training_Enrollment__c> newList, Map<Id, Training_Enrollment__c> oldMap) {
        for (Training_Enrollment__c te : newList) {
            Training_Enrollment__c oldRec = oldMap.get(te.Id);

            if (te.Employee__c == null) {
                te.addError('Employee cannot be blank.');
                continue;
            }
            if (te.Training__c == null) {
                te.addError('Training cannot be blank.');
                continue;
            }

            if (te.Employee__c != oldRec.Employee__c || te.OwnerId != te.Employee__c) {
                te.OwnerId = te.Employee__c;
            }

            if (te.Employee__c != oldRec.Employee__c ||
                te.Training__c != oldRec.Training__c ||
                String.isBlank(te.Enrollment_Key__c)) {

                te.Enrollment_Key__c = te.Employee__c + '-' + te.Training__c;
            }
        }
    }

    /**
     * AFTER INSERT:
     * - Queue Chatter posts only for new enrollments with Status__c = 'Planned'
     * - Async job will enforce security & do DML in bulk
     */
    public static void afterInsert(List<Training_Enrollment__c> newList) {
        EnrollmentChatterPublisher.enqueueForPlannedEnrollments(newList);
    }
}
