public class EnrollmentChatterPublisher {
    /**
     * Collect Planned enrollments and enqueue a single Queueable.
     */
    public static void enqueueForPlannedEnrollments(List<Training_Enrollment__c> newList) {
        Set<Id> ids = new Set<Id>();
        for (Training_Enrollment__c te : newList) {
            // Only on INSERT & Status = 'Planned'
            if (te.Status__c == 'Planned' && te.Training__c != null && te.Employee__c != null) {
                ids.add(te.Id);
            }
        }
        if (!ids.isEmpty()) {
            System.enqueueJob(new EnrollmentChatterJob(new List<Id>(ids)));
        }
    }
}
