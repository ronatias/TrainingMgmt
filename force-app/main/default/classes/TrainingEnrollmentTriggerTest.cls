@IsTest(SeeAllData=true)
private class TrainingEnrollmentTriggerTest {
  private static Map<String, Id> pickUsers() {
    Map<String, Id> out = new Map<String, Id>();
    Id adminId = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
      ORDER BY CreatedDate
      LIMIT 1
    ]
    .Id;
    out.put('admin', adminId);
    out.put('sales', adminId);
    List<User> others = [
      SELECT Id
      FROM User
      WHERE
        IsActive = TRUE
        AND Id != :adminId
        AND Profile.Name != 'System Administrator'
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
      b = TrainingTestDataFactory.createBusinessData(
        u.get('admin'),
        u.get('sales'),
        u.get('hr')
      );
    }

    System.runAs(new User(Id = u.get('sales'))) {
      Training_Enrollment__c a = new Training_Enrollment__c(
        Employee__c = u.get('sales'),
        Training__c = b.trainingSalesId,
        Status__c = 'Planned',
        Enrollment_Date__c = Date.today()
      );
      Training_Enrollment__c b2 = a.clone(false, false, false, false);

      Test.startTest();
      Database.SaveResult[] srs = Database.insert(
        new List<Training_Enrollment__c>{ a, b2 },
        false
      );
      Test.stopTest();

      System.assertEquals(
        true,
        srs[0].isSuccess(),
        'First insert should succeed'
      );
      System.assertEquals(
        false,
        srs[1].isSuccess(),
        'Second should fail due to in-batch duplicate key'
      );

      Training_Enrollment__c stored = [
        SELECT Id, OwnerId, Enrollment_Key__c
        FROM Training_Enrollment__c
        WHERE Id = :srs[0].getId()
      ];
      System.assertEquals(
        u.get('sales'),
        stored.OwnerId,
        'Owner should be Employee'
      );
      System.assert(
        !String.isBlank(stored.Enrollment_Key__c),
        'Key must be set'
      );
    }
  }

  @IsTest
  static void afterInsert_enqueues_queueable_without_errors() {
    Map<String, Id> u = pickUsers();

    TrainingTestDataFactory.BizIds b;
    System.runAs(new User(Id = u.get('admin'))) {
      b = TrainingTestDataFactory.createBusinessData(
        u.get('admin'),
        u.get('sales'),
        u.get('hr')
      );
    }

    System.runAs(new User(Id = u.get('sales'))) {
      Training_Enrollment__c te = new Training_Enrollment__c(
        Employee__c = u.get('sales'),
        Training__c = b.trainingSalesId,
        Status__c = 'Planned',
        Enrollment_Date__c = Date.today()
      );

      Test.startTest();
      insert te; // enqueues queueable
      Test.stopTest(); // runs queueable

      System.assert(true, 'Queueable executed');
    }
  }

  @IsTest
  static void beforeUpdate_recomputes_key_path() {
    Map<String, Id> u = pickUsers();

    TrainingTestDataFactory.BizIds b;
    System.runAs(new User(Id = u.get('admin'))) {
      b = TrainingTestDataFactory.createBusinessData(
        u.get('admin'),
        u.get('sales'),
        u.get('hr')
      );
    }

    System.runAs(new User(Id = u.get('sales'))) {
      Training_Enrollment__c te = new Training_Enrollment__c(
        Employee__c = u.get('sales'),
        Training__c = b.trainingSalesId,
        Status__c = 'Planned',
        Enrollment_Date__c = Date.today()
      );
      insert te;

      Test.startTest();
      update te; // exercise before update path
      Test.stopTest();

      te = [
        SELECT Enrollment_Key__c
        FROM Training_Enrollment__c
        WHERE Id = :te.Id
      ];
      System.assert(!String.isBlank(te.Enrollment_Key__c));
    }
  }

  @IsTest
  static void beforeInsert_nullFieldErrors_areRaised() {
    Map<String, Id> u = pickUsers();

    // Prepare training records visible to admin
    TrainingTestDataFactory.BizIds b;
    System.runAs(new User(Id = u.get('admin'))) {
      b = TrainingTestDataFactory.createBusinessData(
        u.get('admin'),
        u.get('sales'),
        u.get('hr')
      );
    }

    System.runAs(new User(Id = u.get('admin'))) {
      // Case 1: Employee__c is null -> "Employee is required."
      Training_Enrollment__c e1 = new Training_Enrollment__c(
        Employee__c = null,
        Training__c = b.trainingSalesId,
        Status__c = 'Planned',
        Enrollment_Date__c = Date.today()
      );

      // Case 2: Training__c is null -> "Training is required."
      Training_Enrollment__c e2 = new Training_Enrollment__c(
        Employee__c = u.get('sales'),
        Training__c = null,
        Status__c = 'Planned',
        Enrollment_Date__c = Date.today()
      );

      Test.startTest();
      Database.SaveResult[] srs = Database.insert(
        new List<Training_Enrollment__c>{ e1, e2 },
        false
      );
      Test.stopTest();

      System.assertEquals(
        false,
        srs[0].isSuccess(),
        'Missing Employee__c should fail'
      );
      System.assert(srs[0].getErrors().size() > 0);
      System.assert(
        srs[0].getErrors()[0]
          .getMessage()
          .toLowerCase()
          .contains('employee is required'),
        'Expected "Employee is required." addError'
      );

      System.assertEquals(
        false,
        srs[1].isSuccess(),
        'Missing Training__c should fail'
      );
      System.assert(srs[1].getErrors().size() > 0);
      System.assert(
        srs[1].getErrors()[0]
          .getMessage()
          .toLowerCase()
          .contains('training is required'),
        'Expected "Training is required." addError'
      );
    }
  }

  @IsTest
  static void beforeUpdate_nullFieldErrors_and_ownerAlignment() {
    Map<String, Id> u = pickUsers();

    // Create base data (as admin to set Ownership on Trainings)
    TrainingTestDataFactory.BizIds b;
    System.runAs(new User(Id = u.get('admin'))) {
      b = TrainingTestDataFactory.createBusinessData(
        u.get('admin'),
        u.get('sales'),
        u.get('hr')
      );
    }

    // Insert ONE valid enrollment (as "sales") to avoid duplicate key rows
    Id enrollmentId;
    System.runAs(new User(Id = u.get('sales'))) {
      Training_Enrollment__c te = new Training_Enrollment__c(
        Employee__c = u.get('sales'),
        Training__c = b.trainingSalesId,
        Status__c = 'Planned',
        Enrollment_Date__c = Date.today()
      );
      insert te;
      enrollmentId = te.Id;
    }

    // Perform three updates in ONE start/stop block (no nested startTest)
    System.runAs(new User(Id = u.get('admin'))) {
      Test.startTest();

      // A) Set Employee__c to null -> expect "Employee cannot be blank." and NO DB change
      Database.SaveResult sr1 = Database.update(
        new Training_Enrollment__c(Id = enrollmentId, Employee__c = null),
        false
      );

      // B) Set Training__c to null (keep Employee__c valid) -> expect "Training cannot be blank." and NO DB change
      Database.SaveResult sr2 = Database.update(
        new Training_Enrollment__c(
          Id = enrollmentId,
          Employee__c = u.get('sales'),
          Training__c = null
        ),
        false
      );

      // C) Change Employee__c to HR -> should succeed and realign OwnerId = Employee__c
      update new Training_Enrollment__c(
        Id = enrollmentId,
        Employee__c = u.get('hr')
      );

      Test.stopTest();

      System.assertEquals(
        false,
        sr1.isSuccess(),
        'Null Employee__c on update should fail'
      );
      System.assert(sr1.getErrors().size() > 0);
      System.assert(
        sr1.getErrors()[0]
          .getMessage()
          .toLowerCase()
          .contains('employee cannot be blank'),
        'Expected "Employee cannot be blank." addError'
      );

      System.assertEquals(
        false,
        sr2.isSuccess(),
        'Null Training__c on update should fail'
      );
      System.assert(sr2.getErrors().size() > 0);
      System.assert(
        sr2.getErrors()[0]
          .getMessage()
          .toLowerCase()
          .contains('training cannot be blank'),
        'Expected "Training cannot be blank." addError'
      );

      Training_Enrollment__c afterAlign = [
        SELECT Id, OwnerId, Employee__c
        FROM Training_Enrollment__c
        WHERE Id = :enrollmentId
      ];
      System.assertEquals(
        u.get('hr'),
        afterAlign.Employee__c,
        'Employee__c should be updated'
      );
      System.assertEquals(
        u.get('hr'),
        afterAlign.OwnerId,
        'OwnerId should realign to Employee__c'
      );
    }
  }
}
