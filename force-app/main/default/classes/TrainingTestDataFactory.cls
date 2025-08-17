@IsTest
public class TrainingTestDataFactory {

    public class BizIds {
        public Id trainingSalesId;
        public Id trainingHrId;
        public List<Id> bulkTrainingIds;
    }

    /**
     * NOTE: Call this method from within System.runAs(adminUser)!
     * It sets explicit OwnerId values (Sales/HR). No manual shares are used.
     */
    public static BizIds createBusinessData(Id adminUserId, Id salesUserId, Id hrUserId) {
        BizIds out = new BizIds();

        // Two canonical trainings
        Training__c tSales = new Training__c(
            OwnerId = salesUserId,                 // Sales owns -> Sales can see (with OWD Private)
            Trainer__c = 'Alice',
            External_Course_Id__c = 'EXT-S-1',
            Rating__c = 4.20,
            Department__c = 'Sales',
            Is_Confidential__c = false
        );
        Training__c tHr = new Training__c(
            OwnerId = adminUserId,                 // Admin owns -> Sales cannot see
            Trainer__c = 'Bob',
            External_Course_Id__c = 'EXT-H-1',
            Rating__c = 3.70,
            Department__c = 'HR',
            Is_Confidential__c = false
        );
        insert new List<Training__c>{ tSales, tHr };
        out.trainingSalesId = tSales.Id;
        out.trainingHrId    = tHr.Id;

        // Bulk dataset: alternate ownership
        out.bulkTrainingIds = new List<Id>();
        List<Training__c> many = new List<Training__c>();
        for (Integer i = 0; i < 205; i++) {
            Boolean even = Math.mod(i, 2) == 0;
            many.add(new Training__c(
                OwnerId = (even ? salesUserId : hrUserId),
                Trainer__c = 'BulkT',
                External_Course_Id__c = 'BULK-' + i,
                Rating__c = (Decimal)(Math.mod(i, 5) + 1), // 1..5
                Department__c = (even ? 'Sales' : 'HR'),
                Is_Confidential__c = false
            ));
        }
        insert many;
        for (Training__c t : many) out.bulkTrainingIds.add(t.Id);

        return out;
    }
}
