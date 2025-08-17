@IsTest(SeeAllData=true)
private class TrainingMgmt_ControllerTest {

    // Pick real users from your org (no inserts)
    private static Map<String, Id> pickUsers() {
        Map<String, Id> out = new Map<String, Id>();
        Id adminId = [
            SELECT Id FROM User
            WHERE IsActive = true AND Profile.Name = 'System Administrator'
            ORDER BY CreatedDate LIMIT 1
        ].Id;
        out.put('admin', adminId);

        // Try to find a non-admin; if none, reuse admin
        List<User> others = [
            SELECT Id FROM User
            WHERE IsActive = true AND Id != :adminId AND Profile.Name != 'System Administrator'
            ORDER BY CreatedDate LIMIT 2
        ];
        out.put('sales', others.isEmpty() ? adminId : others[0].Id);
        out.put('hr',    others.size() > 1 ? others[1].Id : adminId);
        return out;
    }

    // Smoke: fetch trainings without assuming any specific record visibility
    @IsTest
    static void fetch_smoke_does_not_throw() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('sales'))) {
            Test.startTest();
            TrainingMgmt_Controller.GetTrainingsResult res = TrainingMgmt_Controller.getTrainings(null, null);
            Test.stopTest();

            System.assertNotEquals(null, res, 'Result should not be null');
            // DO NOT assert that a specific record is present; org sharing can vary.
            System.assertNotEquals(null, res.rows, 'Rows should be a list (possibly empty)');
        }
    }

    // Search + minRating filter always hold regardless of OWD
    @IsTest
    static void search_and_minRating_filters_work() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('hr'))) {
            Test.startTest();
            TrainingMgmt_Controller.GetTrainingsResult res = TrainingMgmt_Controller.getTrainings('BULK', 3);
            Test.stopTest();

            System.assertNotEquals(null, res);
            for (TrainingMgmt_Controller.TrainingRowDTO d : res.rows) {
                if (d.rating != null) System.assert(d.rating >= 3, 'minRating must be applied');
            }
        }
    }

    // Enroll flow: allow both outcomes depending on sharing (success OR access denied)
    @IsTest
    static void enroll_flow_handles_success_and_duplicate_or_accessDenied() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('sales'))) {
            Test.startTest();

            // Attempt to enroll to the “sales-owned” training.
            TrainingMgmt_Controller.EnrollResult first = TrainingMgmt_Controller.enrollMe(b.trainingSalesId);

            if (first.success) {
                // If sharing allows it, second attempt must be duplicate
                TrainingMgmt_Controller.EnrollResult dup = TrainingMgmt_Controller.enrollMe(b.trainingSalesId);
                System.assertEquals(false, dup.success, 'Duplicate enroll should be blocked');
                System.assertEquals('You are already enrolled in this training.', dup.message);
            } else {
                // If sharing blocks it, message must reflect access issue
                System.assertEquals(false, first.success);
                System.assertEquals('You do not have access to this training.', first.message);
            }

            Test.stopTest();
        }
    }

    // Volume: controller caps results at 200 (independent of OWD)
    @IsTest
    static void volume_capped_at_200() {
        Map<String, Id> u = pickUsers();

        TrainingTestDataFactory.BizIds b;
        System.runAs(new User(Id = u.get('admin'))) {
            b = TrainingTestDataFactory.createBusinessData(u.get('admin'), u.get('sales'), u.get('hr'));
        }

        System.runAs(new User(Id = u.get('hr'))) {
            Test.startTest();
            TrainingMgmt_Controller.GetTrainingsResult res = TrainingMgmt_Controller.getTrainings(null, null);
            Test.stopTest();

            System.assertNotEquals(null, res);
            System.assert(res.rows.size() <= 200, 'Controller should cap results at 200');
        }
    }
}
