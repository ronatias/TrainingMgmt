public with sharing class TrainingMgmt_Controller {

    
    //Permission Set fallback for super access
    private static final Set<String> SUPER_PERMISSIONSETS = new Set<String>{ 'Manage_All_Trainings' };

    // Cache the result per transaction
    private static Boolean isSuperCache;

    // Returns true if the running user is assigned to any of the configured SUPER_PERMISSIONSETS
    private static Boolean hasSuperAccess() {
        if (isSuperCache != null) return isSuperCache;

        // Check permission set membership by API Name
        Integer cnt = [
            SELECT Count()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.Name IN :SUPER_PERMISSIONSETS
        ];
        isSuperCache = (cnt > 0);
        return isSuperCache;
    }
    // ===== DTOs =====
    public class TrainingRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String trainerName;         // from Trainer__c (Text)
        @AuraEnabled public Decimal rating;             // Rating__c
        @AuraEnabled public String department;          // sent when FLS allows (UI decides visibility)
        @AuraEnabled public Boolean isConfidential;     // sent when FLS allows (UI decides visibility)
        @AuraEnabled public String externalCourseId;    // sent when FLS allows (UI decides visibility)
        @AuraEnabled public Boolean canEnroll;          // UI convenience
        @AuraEnabled public Boolean isSuperUser;        // has super access (perm set or custom perm)
        @AuraEnabled public Boolean alreadyEnrolled;    // current user already enrolled?
    }

    public class GetTrainingsResult {
        @AuraEnabled public List<TrainingRowDTO> rows;
        @AuraEnabled public Boolean isSuperUser;
    }

    // ===== Query visible trainings (search + min rating) =====
    @AuraEnabled(cacheable=true)
    public static GetTrainingsResult getTrainings(String searchKey, Decimal minRating) {
        final Boolean isSuper = hasSuperAccess(); // NEW: respects Permission Set membership

        // Build WHERE dynamically
        List<String> filters = new List<String>();
        if (!String.isBlank(searchKey)) {
            //Escape single quotes; let % and _ act as wildcards for user-friendly search
            String likeVal = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            filters.add('Name LIKE \'' + likeVal + '\'');
        }
        if (minRating != null) {
            filters.add('Rating__c >= ' + String.valueOf(minRating));
        }

        String soql =
            'SELECT Id, Name, Trainer__c, External_Course_Id__c, Rating__c, ' +
            '       Department__c, Is_Confidential__c ' +
            'FROM Training__c';

        if (!filters.isEmpty()) {
            soql += ' WHERE ' + String.join(filters, ' AND ');
        }

        // WITH SECURITY_ENFORCED must be after WHERE and before ORDER/LIMIT
        soql += ' WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 200';

        List<Training__c> q = Database.query(soql);

        // FLS: strip non-readable fields from the result (any non-readable fields are nulled)
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, q);
        List<Training__c> safe = (List<Training__c>) dec.getRecords();

        // Figure out which of these trainings the running user is already enrolled in (bulk)
        Set<Id> trainingIds = new Set<Id>();
        for (Training__c t : safe) trainingIds.add(t.Id);

        Set<Id> already = new Set<Id>();
        if (!trainingIds.isEmpty() && Schema.sObjectType.Training_Enrollment__c.isAccessible()) {
            // with sharing + security enforced; user will see their own enrollments
            for (Training_Enrollment__c te : [
                SELECT Training__c
                FROM Training_Enrollment__c
                WHERE Employee__c = :UserInfo.getUserId()
                AND Training__c IN :trainingIds
                WITH SECURITY_ENFORCED
            ]) {
                if (te.Training__c != null) already.add(te.Training__c);
            }
        }

        Boolean canCreateEnrollment = Schema.sObjectType.Training_Enrollment__c.isCreateable();

        List<TrainingRowDTO> rows = new List<TrainingRowDTO>();
        for (Training__c t : safe) {
            TrainingRowDTO dto = new TrainingRowDTO();
            dto.id = t.Id;
            dto.name = t.Name;
            dto.trainerName = (String)t.get('Trainer__c'); // text
            dto.rating = (Decimal)t.get('Rating__c');

            // IMPORTANT: send fields when FLS allows (stripInaccessible already nulled non-readable ones).
            // The LWC will decide whether to show them based on isSuperUser.
            // Always map these (subject to FLS) — do NOT gate by isSuper here
            dto.department       = (String)t.get('Department__c');
            dto.isConfidential   = (Boolean)t.get('Is_Confidential__c');
            dto.externalCourseId = (String)t.get('External_Course_Id__c');

            dto.alreadyEnrolled = already.contains(t.Id);
            dto.canEnroll       = canCreateEnrollment && !dto.alreadyEnrolled;
            dto.isSuperUser     = isSuper;

            rows.add(dto);
        }

        GetTrainingsResult res = new GetTrainingsResult();
        res.rows = rows;
        res.isSuperUser = isSuper;
        return res;
    }

    // ===== Enroll current user in a training =====
    public class EnrollResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id enrollmentId;
    }

    @AuraEnabled
    public static EnrollResult enrollMe(Id trainingId) {
        EnrollResult out = new EnrollResult();

        // CRUD guard
        if (!Schema.sObjectType.Training_Enrollment__c.isCreateable()) {
            out.success = false;
            out.message = 'You do not have permission to enroll.';
            return out;
        }

        // Verify the training exists AND is readable to the running user
        Training__c tr;
        try {
            tr = [SELECT Id FROM Training__c WHERE Id = :trainingId WITH SECURITY_ENFORCED LIMIT 1];
        } catch (Exception e) {
            out.success = false;
            out.message = 'You do not have access to this training.';
            return out;
        }

        // Build enrollment; trigger will set OwnerId/Enrollment_Key__c; sharing/enforcement handled there
        Training_Enrollment__c te = new Training_Enrollment__c(
            Employee__c = UserInfo.getUserId(),
            Training__c = tr.Id,
            Status__c = 'Planned',
            Enrollment_Date__c = Date.today()
        );

        // FLS: strip non-creatable fields defensively
        List<Training_Enrollment__c> toInsert = new List<Training_Enrollment__c>{ te };
        SObjectAccessDecision decCreate = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
        List<Training_Enrollment__c> safeInsert = (List<Training_Enrollment__c>) decCreate.getRecords();

        //If everything got stripped due to FLS, bail gracefully
        if (safeInsert.isEmpty()) {
            out.success = false;
            out.message = 'You do not have permission to enroll.';
            return out;
        }

        try {
            insert safeInsert;  // unique Enrollment_Key__c prevents duplicates; trigger handles owner
            out.success = true;
            out.enrollmentId = safeInsert[0].Id;
            out.message = 'You have been enrolled.';
        } catch (DmlException ex) {
            String msg = ex.getMessage();
            if (msg != null && msg.toLowerCase().contains('duplicate')) {
                out.message = 'You are already enrolled in this training.';
            } else if (msg != null && msg.toLowerCase().contains('insufficient access')) {
                out.message = 'You do not have access to enroll in this training.';
            } else {
                out.message = 'Could not complete enrollment.';
            }
            out.success = false;
        }
        return out;
    }
}
