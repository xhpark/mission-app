# Flutter Development Document Review

Reviewed on: 2026-04-18
Workspace: `D:\proj\mission_app`

## Overall Judgment

The document set is rich enough to start Flutter development, but it is not yet clean enough to use as-is without confusion.

The main problem is not missing scope. The main problem is that multiple versions of UI/API/schema documents coexist, and some older documents are still referenced by newer ones. That creates a real risk that Flutter, Functions, and Firestore will drift apart during implementation.

## Recommended Source-of-Truth Order

Use these as the primary implementation baseline:

1. `UI_DETAIL_SPEC_v5.docx`
2. `API_FULL_SPEC_v3.docx`
3. `Firestore_Complete_Schema_v3.docx`
4. `08_Flutter_Project_Structure_State_Design_v1.docx`
5. `09_ADMIN_MANUAL_v1.docx`
6. `Automation_Script_Spec_v3.docx`

Treat these as secondary/reference only:

1. `01_PRD_v3.docx`
2. `02_USER_FLOW_UI_SPEC_v3.docx`
3. `03_INFORMATION_ARCHITECTURE_v3.docx`
4. `05_FEATURE_SPEC_v3.docx`
5. `Mission_App_FINAL_v3.docx`
6. `Mission_App_FULL_SPEC_v3.docx`

Treat these as superseded and risky to implement from directly:

1. `06_UI_DETAIL_SPEC_wireframe_v4.docx`
2. `07_API_SPEC_v1.docx`
3. `04_DATABASE_SCHEMA_v3.docx`
4. `10_AUTOMATION_PLAN_v2.docx`

## Critical Issues Before Flutter Development

### 1. Authentication policy is not fully settled

- `07_API_SPEC_v1.docx` describes "phone authentication or admin-approved simplified authentication".
- Current Flutter app uses anonymous sign-in in [login_screen.dart](D:/proj/mission_app/lib/features/auth/presentation/screens/login_screen.dart) and [auth_controller.dart](D:/proj/mission_app/lib/features/auth/presentation/controllers/auth_controller.dart).
- If anonymous auth is temporary, the docs should explicitly say so. If it is the real production policy, the API docs and admin manual need to be updated to match.

Why this matters:
Flutter navigation, onboarding, admin approval flow, and Firebase security rules will all depend on this choice.

### 2. Firestore collection naming is inconsistent with the current backend implementation

- The schema docs consistently describe:
  - `/content_sets/{contentSetId}/sentences/{sentenceId}`
  - `/content_sets/{contentSetId}/words/{wordId}`
- Current Cloud Functions read from:
  - ``content_sets/{contentSetId}/items``
  in [functions/src/index.ts](D:/proj/mission_app/functions/src/index.ts)

Why this matters:
If Flutter starts implementing against `sentences` while Functions read `items`, the app will appear broken even when each side is "correct" according to a different document.

### 3. UI v5 is newer, but still depends on older references

- `UI_DETAIL_SPEC_v5.docx` explicitly says it redefines the latest policy.
- But it still references `06_UI_DETAIL_SPEC v4`, `07_API_SPEC`, and `08_Flutter` as inputs.
- `08_Flutter_Project_Structure_State_Design_v1.docx` itself is also based on `06_UI_DETAIL_SPEC v4`.

Why this matters:
The latest UI document is not fully detached from the older specification chain. That makes "latest" ambiguous for screen states, transitions, and route ownership.

### 4. Content quantity policy and seed data do not match

- The product policy is stable across summary docs:
  - Daily: 15 sentences
  - Mission: 10 sentences
- Current seeded content in [functions/src/content_sets.ts](D:/proj/mission_app/functions/src/content_sets.ts) contains only 3 items per content set.

Why this matters:
Progress bars, completion logic, resume behavior, reports, and admin QA cannot be trusted unless the code clearly marks this as sample data or the docs define a separate development fixture policy.

### 5. The Flutter structure document is directionally good, but not yet synchronized with the current repo

- `08_Flutter_Project_Structure_State_Design_v1.docx` recommends a broader route map and more complete feature segmentation.
- Current router in [app_router.dart](D:/proj/mission_app/lib/app/router/app_router.dart) only exposes:
  - `/bootstrap`
  - `/login`
  - `/select`
  - `/sentence-learning`
- Several folders/screens named in the spec are not implemented yet, and some utility files described in the document are also absent.

Why this matters:
The document is useful for direction, but not yet accurate enough to be treated as a literal reflection of the codebase.

## Document-by-Document Review

### `01_PRD_v3.docx`

Status: Useful for product intent, not enough for direct Flutter implementation.

- Good: clarifies the fixed-app / changing-contentSet model.
- Risk: too short and too abstract to drive widget states or data contracts.

### `02_USER_FLOW_UI_SPEC_v3.docx`

Status: Useful as a flow summary.

- Good: reinforces removal of user country selection and operator-centered flow.
- Risk: should not override `UI_DETAIL_SPEC_v5.docx` for screen behavior.

### `03_INFORMATION_ARCHITECTURE_v3.docx`

Status: Good conceptual reference.

- Good: simple app -> contentSet -> content model aligns with the overall product direction.
- Risk: too high-level to settle collection paths, DTOs, or controller responsibilities.

### `04_DATABASE_SCHEMA_v3.docx`

Status: Partially superseded.

- Good: preserves the key count policy and validation mindset.
- Risk: `Firestore_Complete_Schema_v3.docx` is far more implementation-ready and should replace this as the backend source of truth.

### `05_FEATURE_SPEC_v3.docx`

Status: Good capability map, not a build spec.

- Good: defines the major engines clearly.
- Risk: not detailed enough for Flutter state/event implementation.

### `06_UI_DETAIL_SPEC_wireframe_v4.docx`

Status: Superseded by `UI_DETAIL_SPEC_v5.docx`.

- Good: still useful for early UX rationale and accessibility principles.
- Risk: direct implementation from this file will likely reintroduce stale behavior.

### `07_API_SPEC_v1.docx`

Status: Superseded and risky.

- Good: useful as an early interface sketch.
- Risk: it is tied to `06_UI_DETAIL_SPEC v4` and is weaker than `API_FULL_SPEC_v3.docx`.
- Risk: authentication and function contract assumptions are not cleanly aligned with the current app.

### `08_Flutter_Project_Structure_State_Design_v1.docx`

Status: Important, but requires refresh.

- Good: Riverpod + repository + controller separation fits the current code direction.
- Good: route and feature decomposition are helpful as a target architecture.
- Risk: because it is based on UI v4, it should be updated after locking UI v5/API v3/schema v3.

### `09_ADMIN_MANUAL_v1.docx`

Status: Useful operationally.

- Good: helps define the admin-facing workflows that Flutter/admin tooling may need to support.
- Risk: should be checked against the final auth policy and content upload workflow.

### `10_AUTOMATION_PLAN_v2.docx`

Status: Superseded by `Automation_Script_Spec_v3.docx`.

- Good: captures the automation intent.
- Risk: too compressed compared with the newer detailed automation document.

### `API_FULL_SPEC_v3.docx`

Status: Primary backend interface source.

- Good: strongest API document in the set.
- Good: clearly intended for Flutter + Firebase + Functions implementation.
- Risk: must be reconciled with the real Functions collection paths and currently deployed callable names.

### `Automation_Script_Spec_v3.docx`

Status: Primary automation source.

- Good: detailed enough for automation pipeline development.
- Risk: separate automation repo structure is proposed; should be aligned with the actual repo layout before implementation starts.

### `Firestore_Complete_Schema_v3.docx`

Status: Primary Firestore source.

- Good: the most implementation-ready schema document.
- Good: includes collection layout, enums, indexes, and security principles.
- Risk: must be reconciled with the current `items` subcollection usage in Functions.

### `Mission_App_FINAL_v3.docx`

Status: Good executive summary.

- Good: captures the stable headline policies.
- Risk: too brief to use for implementation details.

### `Mission_App_FULL_SPEC_v3.docx`

Status: Summary bundle, not source of truth.

- Good: convenient cross-document overview.
- Risk: because it compresses multiple domains, it should not outrank the domain-specific latest specs.

### `UI_DETAIL_SPEC_v5.docx`

Status: Primary Flutter UI source.

- Good: this is the strongest screen-level implementation document.
- Good: it explicitly includes state, events, validation, API/Firestore linkage, and accessibility expectations.
- Risk: its dependency chain still references older docs, so it should be declared the final UI baseline and the older UI/API references should be retired.

## Readiness Assessment For Flutter Work

You can start Flutter development now, but only with a controlled baseline:

1. Freeze `UI_DETAIL_SPEC_v5.docx`, `API_FULL_SPEC_v3.docx`, and `Firestore_Complete_Schema_v3.docx` as the official implementation trio.
2. Update `08_Flutter_Project_Structure_State_Design_v1.docx` so it references the v5/v3/v3 trio instead of UI v4.
3. Decide the production authentication model immediately.
4. Reconcile Firestore collection paths between docs and `functions/src/index.ts`.
5. Mark all sample seed content explicitly as fixture/test data.

## Current Codebase Snapshot

The current repo is a partial scaffold, not a full implementation:

- Flutter dependencies already align with the design direction: Riverpod, GoRouter, Firebase, audio/recording.
- App flow currently covers bootstrap, login, learning select, and sentence learning only.
- Cloud Functions currently implement only a small subset of the callable surface described in the API specs.
- README is still the default Flutter template and does not reflect the project architecture.

## Recommendation

This documentation set is usable, but not yet safe enough to hand to a Flutter team without a short normalization pass first.

The fastest safe path is:

1. declare the latest source-of-truth documents,
2. retire the older conflicting documents,
3. align auth + Firestore path policy,
4. then continue feature-by-feature implementation.
