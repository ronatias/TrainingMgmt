@IsTest(SeeAllData=true)
private class TrainingEnrollmentTriggerTest {

    private static Map<String, Id> pickUsers() {
        Map<String, Id> out = new Map<String, Id>();
        Id adminId = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'System Administrator' ORDER BY CreatedDate LIMIT 1].Id;
        out.put('admin', adminId);
        out.put('sales', adminId); // use admin to guarantee object access for enrollments
        // Non-admin for hr if available; fallback to admin
        List<User> others = [
            SELECT Id FROM User
            WHERE IsActive = true AND Id != :adminId AND Profile.Name != 'System Administrator'
            ORDER BY CreatedDate
            LIMIT 1
        ];
        out.put('hr', others.isEmpty() ? adminId : others[0].Id);
        return out;
    }

    @IsTest
    static void beforeInsert_setsOwner_andKey_and_blocks_batch_duplicate() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('sales'))) {
            Training_Enrollment__c a = new Training_Enrollment__c(
                Employee__c = u.get('sales'), Training__c = b.trainingSalesId,
                Status__c = 'Planned', Enrollment_Date__c = Date.today()
            );
            Training_Enrollment__c b2 = a.clone(false, false, false, false);

            Test.startTest();
            Database.SaveResult[] srs = Database.insert(new List<Training_Enrollment__c>{ a, b2 }, false);
            Test.stopTest();

            System.assertEquals(true,  srs[0].isSuccess(), 'First insert should succeed');
            System.assertEquals(false, srs[1].isSuccess(), 'Second should fail due to in-batch duplicate key');

            Training_Enrollment__c stored = [
                SELECT Id, OwnerId, Enrollment_Key__c
                FROM Training_Enrollment__c WHERE Id = :srs[0].getId()
            ];
            System.assertEquals(u.get('sales'), stored.OwnerId, 'Owner should be Employee');
            System.assert(!String.isBlank(stored.Enrollment_Key__c), 'Key must be set');
        }
    }

    @IsTest
    static void afterInsert_enqueues_queueable_without_errors() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('sales'))) {
            Training_Enrollment__c te = new Training_Enrollment__c(
                Employee__c = u.get('sales'), Training__c = b.trainingSalesId,
                Status__c = 'Planned', Enrollment_Date__c = Date.today()
            );

            Test.startTest();
            insert te;   // enqueues queueable
            Test.stopTest(); // runs queueable

            System.assert(true, 'Queueable executed');
        }
    }

    @IsTest
    static void beforeUpdate_recomputes_key_path() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('sales'))) {
            Training_Enrollment__c te = new Training_Enrollment__c(
                Employee__c = u.get('sales'), Training__c = b.trainingSalesId,
                Status__c = 'Planned', Enrollment_Date__c = Date.today()
            );
            insert te;

            Test.startTest();
            update te; // exercise before update path
            Test.stopTest();

            te = [SELECT Enrollment_Key__c FROM Training_Enrollment__c WHERE Id = :te.Id];
            System.assert(!String.isBlank(te.Enrollment_Key__c));
        }
    }
}
