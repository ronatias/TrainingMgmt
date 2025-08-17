TrainingMgmt — Deployment & Setup Guide

This guide walks you through deploying the Training Management package and setting it up so users can access the app and enroll in trainings.

Contents

Deploy the package via Workbench

Assign permission sets

Expose the Training tabs

Add and use the LWC

Preflight & troubleshooting

1. Deploy the package via Workbench

What you need

The file: TrainingMgmt_deployable.zip (single package, package.xml at the ZIP root)

Admin access to the target org

Steps

Go to https://workbench.developerforce.com.

Choose Environment (Production or Sandbox) and pick a recent API Version (e.g., 64.0), accept the terms, click Login with Salesforce.

Top menu: migration → Deploy.

Choose File → select TrainingMgmt_deployable.zip.

Check these options:

✅ Single Package

✅ Rollback On Error

(Optional) Check Only if you want to validate first without changing the org.

Test Level:

Sandbox: NoTestRun is fine.

Production: Use RunLocalTests (Salesforce requirement when deploying Apex).

Click Deploy (or Validate if using Check Only), then Refresh the results until complete.

If you see an error “No package.xml found,” make sure the ZIP has package.xml at the ZIP root (not inside a folder).
If you see “FlexiPage not found,” deploy again including flexipages/Training_Explorer.flexipage-meta.xml, or remove the Training_Explorer tab from the package.

2. Assign permission sets

This package includes two permission sets:

Training_App_Access
Grants access to the custom objects, LWC component, and related tabs.
👉 Assign this to all users who should use the Training Explorer and enroll.

Manage_All_Trainings
Grants elevated visibility in the LWC (super user mode): can see all training fields, including Department; broader access for management/ops.
👉 Assign this in addition to users who need super-user capabilities.

Assignment (Setup)

Go to Setup → Permission Sets.

Open Training_App_Access → Manage Assignments → Add Assignments → select users → Assign.

(Optional) Open Manage_All_Trainings → assign to your super users.

✔️ Each end user must have at least Training_App_Access.
✔️ Give Manage_All_Trainings only to users who need elevated visibility in the explorer.

3. Expose the Training tabs

The package includes object tabs:

Training (for Training\_\_c)

Training Enrollments (for Training_Enrollment\_\_c)

(Optional) Training Explorer (Lightning App Page tab hosting the LWC)

Add tabs to an app

Go to Setup → App Manager.

Find your desired Lightning app (e.g., Sales), click the ▼, Edit.

Navigation Items → move Training, Training Enrollments, and Training Explorer (if included) into Selected Items.

Save.

Tab visibility can also be controlled by Profiles/Permission Sets. The provided permission sets already set reasonable tab access. If a user still can’t see a tab, verify tab visibility in their Profile or Assigned Permission Sets.

4. Add and use the LWC

You have two options to surface the LWC c:trainingMgmtExplorer:

A) Use the included App Page (recommended)

If your package includes FlexiPage: Training_Explorer and the Training Explorer tab:

Just open the app and click Training Explorer in the navigation.

Users with Training_App_Access will see the list, search, filter, and “Enroll Me” button.

Users who also have Manage_All_Trainings will see extra fields (e.g., Department) and broader data.

B) Add the LWC to a page yourself

Go to any Lightning App Page (or create a new one via App Builder).

Drag TrainingMgmtExplorer from the Custom – Managed components list onto the page.

Save and Activate the page for the desired app and profiles.

Using the LWC

Search by name and/or set Min rating, click Apply.

Click Enroll Me to create a Training_Enrollment\_\_c for the logged-in user.

On success, you’ll see a toast message and the button flips to Enrolled (disabled).

If you don’t have access to enroll or a duplicate is detected, a friendly error toast appears.

Preflight & troubleshooting

Preflight checklist

Chatter is enabled (the trigger creates Chatter posts on planned enrollments):
Setup → Chatter → Enable.

OWD recommended: Training**c = Private, Training_Enrollment**c = Private.

Sharing: Department-based sharing on Training**c, Owner-based rule for Training_Enrollment**c → HR role receives read access as required.

Role reference: The sharing rule references role SVPHumanResources (DeveloperName). Confirm it exists or refactor to a Public Group.

Common issues

“No package.xml found” → Rebuild ZIP with package.xml at root and check Single Package in Workbench.

“FlexiPage not found” → Include flexipages/Training_Explorer.flexipage-meta.xml or remove the Training Explorer tab until you add the page.

User can’t see tabs → Ensure Training_App_Access is assigned and tabs are added to the app’s navigation. Check profile tab visibility if needed.

Duplicate enrollment error → The app prevents duplicates via a unique Enrollment_Key\_\_c (expected). User will see “You are already enrolled in this training.”

Super user fields not visible → Confirm the user also has Manage_All_Trainings assigned, and that FLS grants read access to the fields.
