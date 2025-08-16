public with sharing class TrainingMgmt_Controller {

    // ===== DTOs =====
    public class TrainingRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String trainerName;         // from Trainer__c (Text)
        @AuraEnabled public Decimal rating;             // Rating__c
        @AuraEnabled public String department;          // only for super users (and FLS-readable)
        @AuraEnabled public Boolean isConfidential;     // only for super users (and FLS-readable)
        @AuraEnabled public String externalCourseId;    // only for super users (and FLS-readable)
        @AuraEnabled public Boolean canEnroll;          // UI convenience
        @AuraEnabled public Boolean isSuperUser;        // has Manage_All_Trainings
    }

    public class GetTrainingsResult {
        @AuraEnabled public List<TrainingRowDTO> rows;
        @AuraEnabled public Boolean isSuperUser;
    }

    // ===== Query visible trainings (search + min rating) =====
    @AuraEnabled(cacheable=true)
    public static GetTrainingsResult getTrainings(String searchKey, Decimal minRating) {
        final Boolean isSuper = FeatureManagement.checkPermission('Manage_All_Trainings');

        // Build WHERE dynamically (no "1=1")
        List<String> filters = new List<String>();
        if (!String.isBlank(searchKey)) {
            String likeVal = '%' + searchKey.replace('%','\\%').replace('_','\\_') + '%';
            filters.add('Name LIKE \'' + String.escapeSingleQuotes(likeVal) + '\' ESCAPE \'\\\\\'');
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

        // FLS: strip non-readable fields from the result
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.READABLE, q);
        List<Training__c> safe = (List<Training__c>) dec.getRecords();

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
            dto.trainerName = (String)t.get('Trainer__c'); // text
            dto.rating = (Decimal)t.get('Rating__c');

            // Show these only if user is super AND field is FLS-readable
            dto.department       = (isSuper && deptReadable)  ? (String)t.get('Department__c')         : null;
            dto.isConfidential   = (isSuper && confReadable)  ? (Boolean)t.get('Is_Confidential__c')   : null;
            dto.externalCourseId = (isSuper && extIdReadable) ? (String)t.get('External_Course_Id__c') : null;

            dto.canEnroll  = canCreateEnrollment;  // controller already enforced training read
            dto.isSuperUser = isSuper;

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

        // Build enrollment; trigger will set OwnerId/Enrollment_Key__c
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
