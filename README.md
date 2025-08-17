# 🧭 TrainingMgmt — **Deployment & Setup Guide**

This guide walks you through deploying the **Training Management** package and setting it up so users can access the app and enroll in trainings.

---

## 📚 Contents

- [🚀 Deploy the package via Workbench](#-deploy-the-package-via-workbench)
- [🔐 Assign permission sets](#-assign-permission-sets)
- [🧩 Expose the Training tabs](#-expose-the-training-tabs)
- [🧑‍💻 Add and use the LWC](#-add-and-use-the-lwc)
- [🩺 Preflight & troubleshooting](#-preflight--troubleshooting)

---

## 🚀 Deploy the package via Workbench

**What you need**

- The file: **`TrainingMgmt_deployable.zip`** _(single package, `package.xml`)_
- **Admin** access to the target org

**Steps**

1. Go to **https://workbench.developerforce.com**.
2. Choose **Environment** (Production or Sandbox) and pick a recent **API Version** (e.g., **64.0**), accept the terms, click **Login with Salesforce**.
3. Top menu: **migration → Deploy**.
4. **Choose File** → select `TrainingMgmt_deployable.zip`.
5. Check these options:
   - ✅ **Single Package**
   - ✅ **Rollback On Error**
   - ☐ _(Optional)_ **Check Only** — validate without changing the org.
6. **Test Level**:
   - **Sandbox**: **NoTestRun** is fine.
   - **Production**: **RunLocalTests** _(required when deploying Apex)_.
7. Click **Deploy** _(or **Validate** if using Check Only)_, then **Refresh** the results until complete.

> **❗ If you see** “**No package.xml found**”: make sure the ZIP has `package.xml` at the ZIP **root** (not inside a folder).  
> **❗ If you see** “**FlexiPage not found**”: include `flexipages/Training_Explorer.flexipage-meta.xml` or remove the **Training_Explorer** tab from the package and deploy again.

---

## 🔐 Assign permission sets

This package includes two permission sets:

- **`Training_App_Access`**  
  **Grants access** to the custom objects, LWC component, and related tabs.  
  👉 **Assign this to all users** who should use the Training Explorer and enroll.

- **`Manage_All_Trainings`**  
  **Elevated visibility** in the LWC (super user mode): can see all training fields (incl. **Department**); broader management/ops view.  
  👉 **Assign in addition** to users who need super-user capabilities.

**Assignment (Setup)**

1. Setup → **Permission Sets**.
2. Open **Training_App_Access** → **Manage Assignments** → **Add Assignments** → select users → **Assign**.
3. _(Optional)_ Open **Manage_All_Trainings** → assign to your super users.

**✅ Requirements**

- **Every end user must have at least `Training_App_Access`.**
- Give **`Manage_All_Trainings`** only to users who need elevated visibility.

---

## 🧩 Expose the Training tabs

The package includes object tabs:

- **Training** _(for `Training__c`)_
- **Training Enrollments** _(for `Training_Enrollment__c`)_
- _(Optional)_ **Training Explorer** _(Lightning App Page tab hosting the LWC)_

**Add tabs to an app**

1. Setup → **App Manager**.
2. Find your Lightning app (e.g., **Sales**), click the **▼**, **Edit**.
3. **Navigation Items** → move **Training**, **Training Enrollments**, and **Training Explorer** (if included) into **Selected Items**.
4. **Save**.

> **ℹ️ Note:** Tab visibility can also be controlled by **Profiles/Permission Sets**. The provided permission sets set reasonable tab access. If a user still can’t see a tab, verify tab visibility in their **Profile** or **Assigned Permission Sets** and **Reset navigation** in the app (nav bar ✏️ → _Restore Default Navigation_).

---

## 🧑‍💻 Add and use the LWC

You have two options to surface the LWC **`c:trainingMgmtExplorer`**:

### A) Use the included App Page _(recommended)_

If your package includes the FlexiPage **`Training_Explorer`** and the **Training Explorer** tab:

- Open the app and click **Training Explorer** in the navigation.
- Users with **Training_App_Access** see the list, search, filter, and **Enroll Me** button.
- Users who also have **Manage_All_Trainings** see extra fields (e.g., **Department**) and broader data.

### B) Add the LWC to a page yourself

1. Go to any **Lightning App Page** (or create a new one via **App Builder**).
2. Drag **`TrainingMgmtExplorer`** from **Custom – Managed** components onto the page.
3. **Save** and **Activate** the page for the desired app and profiles.

**Using the LWC**

- **Search** by name and/or set **Min rating**, click **Apply**.
- Click **Enroll Me** to create a `Training_Enrollment__c` for the logged-in user.
- On success, a **toast** appears and the button flips to **Enrolled** (disabled).
- If you don’t have access to enroll or a duplicate is detected, a **friendly error toast** appears.

---

## 🩺 Preflight & troubleshooting

### ✅ Preflight checklist

- **Chatter** is enabled (the trigger creates Chatter posts on planned enrollments):  
  Setup → **Chatter** → **Enable**.
- **OWD** recommended:
  - `Training__c` = **Private**
  - `Training_Enrollment__c` = **Private**
- **Sharing**:
  - Department-based sharing on `Training__c`
  - Owner-based rule for `Training_Enrollment__c` → **HR role** receives **Read** access (as required).
- **Role reference**: The sharing rule references role **`SVPHumanResources`** (DeveloperName). Confirm it exists in your org or refactor to a **Public Group**.

### 🛠 Common issues

- **“No package.xml found”**  
  → Rebuild ZIP with `package.xml` at **root** and check **Single Package** in Workbench.

- **“FlexiPage not found”**  
  → Include `flexipages/Training_Explorer.flexipage-meta.xml` or remove the **Training Explorer** tab until you add the page.

- **User can’t see tabs**  
  → Ensure **`Training_App_Access`** is assigned and tabs are added to the app’s **Navigation Items**.  
  → Check **Profile** tab visibility if needed and **Reset navigation** in the app.

- **Error loading trainings — _Insufficient permissions: secure query included inaccessible field_**  
  → The running user **must have FLS Read** on these `Training__c` fields:  
  **`Trainer__c`**, **`External_Course_Id__c`**, **`Rating__c`**, **`Department__c`**, **`Is_Confidential__c`**.  
  Grant via **`Training_App_Access`** (Object + Field permissions).  
  _(Note: `Manage_All_Trainings` is a super-UX flag; it does **not** grant FLS.)_

- **Duplicate enrollment error**  
  → The app prevents duplicates via a unique **`Enrollment_Key__c`** (expected).  
  User will see **“You are already enrolled in this training.”**

---

### 🧪 Quick verification (optional)

- **Apex Class Access**: Ensure the permission set grants access to **`TrainingMgmt_Controller`** (Permission Set → **Apex Class Access**).
- **FLS spot check** (Execute Anonymous):
  ```apex
  List<String> fields = new List<String>{
      'Trainer__c','External_Course_Id__c','Rating__c','Department__c','Is_Confidential__c'
  };
  Map<String, Schema.SObjectField> fm = Training__c.SObjectType.getDescribe().fields.getMap();
  for (String f : fields) {
      System.debug(f + ' readable? ' + fm.get(f).getDescribe().isAccessible());
  }
  ```
