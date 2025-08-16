public class EnrollmentChatterJob implements Queueable {

    private final List<Id> enrollmentIds;

    public EnrollmentChatterJob(List<Id> ids) {
        // FIX: deepClone() is for sObject lists only; use copy-ctor for List<Id>
        this.enrollmentIds = (ids == null) ? new List<Id>() : new List<Id>(ids);
    }

    public void execute(QueueableContext ctx) {
        // Guard: Creator must be allowed to create FeedItem
        if (!SecurityUtil.canCreateFeedItem()) {
            return; // respect object-level security
        }

        // 1) Pull enrollments (bulk)
        List<Training_Enrollment__c> enrollments = [
            SELECT Id, Employee__c, Employee__r.Name, Training__c, Enrollment_Date__c
            FROM Training_Enrollment__c
            WHERE Id IN :enrollmentIds
        ];
        if (enrollments.isEmpty()) return;

        // 2) Ensure running user has READ on the related Training__c
        Set<Id> trainingIds = new Set<Id>();
        for (Training_Enrollment__c te : enrollments) {
            if (te.Training__c != null) trainingIds.add(te.Training__c);
        }
        if (trainingIds.isEmpty()) return;

        Map<Id, Training__c> readableTrainings = new Map<Id, Training__c>([
            SELECT Id
            FROM Training__c
            WHERE Id IN :trainingIds
            WITH SECURITY_ENFORCED
        ]);
        if (readableTrainings.isEmpty()) return;

        // 3) Build FeedItems (no DML in loops)
        List<FeedItem> posts = new List<FeedItem>();
        Boolean canSetBody   = SecurityUtil.canCreateField(FeedItem.Body);
        Boolean canSetParent = SecurityUtil.canCreateField(FeedItem.ParentId);

        for (Training_Enrollment__c te : enrollments) {
            if (!readableTrainings.containsKey(te.Training__c)) continue;

            String empName = (te.Employee__r != null && String.isNotBlank(te.Employee__r.Name))
                ? te.Employee__r.Name : 'Employee';
            String dateStr = (te.Enrollment_Date__c != null)
                ? te.Enrollment_Date__c.format() : Date.today().format();

            FeedItem fi = new FeedItem();
            if (canSetParent) fi.ParentId = te.Training__c;
            if (canSetBody)   fi.Body     = empName + ' enrolled in this training on ' + dateStr;
            posts.add(fi);
        }

        if (!posts.isEmpty()) {
            Database.insert(posts, /*allOrNone*/ false);
        }
    }
}
