public with sharing class TrainingMgmt_Controller {

    // ===== DTOs =====
    public class TrainingRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String trainerName;         // Text
        @AuraEnabled public Decimal rating;             // Number(16,2)
        @AuraEnabled public String department;          // super users only (and FLS)
        @AuraEnabled public Boolean isConfidential;     // super users only (and FLS)
        @AuraEnabled public String externalCourseId;    // super users only (and FLS)
        @AuraEnabled public Boolean canEnroll;          // UI convenience: user can create TE + not already enrolled
        @AuraEnabled public Boolean isSuperUser;        // has Manage_All_Trainings
        @AuraEnabled public Boolean alreadyEnrolled;    // NEW: user already enrolled to this training
    }

    public class GetTrainingsResult {
        @AuraEnabled public List<TrainingRowDTO> rows;
        @AuraEnabled public Boolean isSuperUser;
    }

    @AuraEnabled(cacheable=true)
    public static GetTrainingsResult getTrainings(String searchKey, Decimal minRating) {
        final Boolean isSuper = FeatureManagement.checkPermission('Manage_All_Trainings');

        // Build WHERE dynamically (no 1=1)
        List<String> filters = new List<String>();
        if (!String.isBlank(searchKey)) {
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
        soql += ' WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 200';

        List<Training__c> q = Database.query(soql);
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
                WHERE Employee__c = :UserInfo.getUserId() AND Training__c IN :trainingIds
                WITH SECURITY_ENFORCED
            ]) {
                if (te.Training__c != null) already.add(te.Training__c);
            }
        }

        // Per-field FLS checks for super-only fields (used alongside custom permission)
        Boolean deptReadable  = SecurityUtil.canReadField(Training__c.Department__c);
        Boolean confReadable  = SecurityUtil.canReadField(Training__c.Is_Confidential__c);
        Boolean extIdReadable = SecurityUtil.canReadField(Training__c.External_Course_Id__c);
        Boolean canCreateEnrollment = Schema.sObjectType.Training_Enrollment__c.isCreateable();

        List<TrainingRowDTO> rows = new List<TrainingRowDTO>();
        for (Training__c t : safe) {
            TrainingRowDTO dto = new TrainingRowDTO();
            dto.id = t.Id;
            dto.name = t.Name;
            dto.trainerName = (String)t.get('Trainer__c');
            dto.rating = (Decimal)t.get('Rating__c');

            dto.department       = (isSuper && deptReadable)  ? (String)t.get('Department__c')         : null;
            dto.isConfidential   = (isSuper && confReadable)  ? (Boolean)t.get('Is_Confidential__c')   : null;
            dto.externalCourseId = (isSuper && extIdReadable) ? (String)t.get('External_Course_Id__c') : null;

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

    // ===== Enroll current user in a training (unchanged) =====
    public class EnrollResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id enrollmentId;
    }

    @AuraEnabled
    public static EnrollResult enrollMe(Id trainingId) {
        EnrollResult out = new EnrollResult();

        if (!Schema.sObjectType.Training_Enrollment__c.isCreateable()) {
            out.success = false; out.message = 'You do not have permission to enroll.'; return out;
        }

        Training__c tr;
        try {
            tr = [SELECT Id FROM Training__c WHERE Id = :trainingId WITH SECURITY_ENFORCED LIMIT 1];
        } catch (Exception e) {
            out.success = false; out.message = 'You do not have access to this training.'; return out;
        }

        Training_Enrollment__c te = new Training_Enrollment__c(
            Employee__c = UserInfo.getUserId(),
            Training__c = tr.Id,
            Status__c = 'Planned',
            Enrollment_Date__c = Date.today()
        );

        List<Training_Enrollment__c> toInsert = new List<Training_Enrollment__c>{ te };
        SObjectAccessDecision decCreate = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
        List<Training_Enrollment__c> safeInsert = (List<Training_Enrollment__c>) decCreate.getRecords();

        try {
            insert safeInsert;
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
