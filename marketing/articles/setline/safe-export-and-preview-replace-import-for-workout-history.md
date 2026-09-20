---
title: "Safe export and preview-replace import for workout history"
slug: "safe-export-and-preview-replace-import-for-workout-history"
target_query: "export workout history json"
search_intent: "informational/navigational"
meta_title: "Safe export and preview-replace import for workout history | Setline"
meta_description: "Learn how Setline implements versioned JSON export and validated, bounded preview-replace import for local workout history without cloud dependencies."
---

## Outline

1. **Introduction:** The necessity of reliable workout data portability and device-first execution.
2. **Device-First Architecture:** Why active sessions never depend on network requests.
3. **Versioned JSON Export:** The mechanics of exporting immutable workout history and custom templates.
4. **Bounded Preview-Replace Import:** Safely validating state replacement before overriding local data.
5. **Preserving Data Integrity:** Maintaining the distinction between recorded, calculated, and authored values across transfers.
6. **Feature Boundaries:** What is explicitly included versus what remains deferred.

## Introduction: Reliable Data Portability and Execution

For individuals executing a structured training programme, data permanence is foundational. Setline is positioned strictly as a mobile-first workout execution tracker, not an automatic programme generator. The core proposition is clear: “Build the plan once. Follow it precisely every day.” To honor this commitment, Setline treats user-authored programmes and workout histories as critical data that must remain accessible and transferable.

While many fitness applications lock user data inside proprietary cloud databases, Setline adopts a completely different architectural stance. There is no product-specific backend holding the canonical source of truth for your workouts. Instead, the application relies on a local JSON document within the app’s own container. By prioritizing a versioned local JSON workout-data export and a validated, bounded import preview, the product guarantees that the user maintains complete ownership and control over their execution history.

This portability mechanism supports the core product purpose: allowing the user to define the programme while Setline keeps the planned order, targets, rest periods, and recorded results close at hand. Whether backing up progress or transferring a 12-week custom programme to a new device, the export and import workflows provide a robust safety net that respects the immutable nature of authored templates and completed session records.

## Device-First Architecture

To understand the design of the export and import systems, one must recognize Setline’s operating context. Used primarily on a phone in a gym with mixed lighting, limited attention, and unreliable connectivity, the repeated action—completing a set and entering a timed rest period—must be flawless. A fundamental constraint is that active workout actions must not depend on a network request.

Setline’s architecture is ruthlessly device-first. The user’s workout history, 1-16 week custom programmes, bundled movement catalogues, and structured set targets all reside locally. Starting a workout takes an immutable snapshot of the plan, meaning that any later edits or deletions of a template never rewrite an active session or saved history. Because there is no dependency on a real-time internet connection to log a completed partial segment, the app functions fully offline.

This local-first constraint deeply influences the data transfer strategy. Without a mandatory cloud synchronization engine running in the background during active sessions, the versioned JSON export remains the primary backup mechanism. Although optional Sign in with Apple synchronization exists, it is strictly deferred during an active workout. The device-first architecture demands that any manual data portability solution be self-contained and free from silent cloud conflicts.

## Versioned JSON Export: Exporting Immutable History

The foundation of Setline's data portability is the versioned JSON export feature. Rather than forcing users to rely on opaque sync states, the application allows users to generate a complete, versioned local JSON workout-data export. This single file encapsulates the entirety of the user's workout state.

The export includes the bundled Sarthak's dated 12-week strength, cardio, and mobility programme (if modified locally), the user's custom templates, the named Monday-based 1–16 week custom programmes, and the exhaustive execution history. Crucially, the export preserves the immutable authored order of exercises and sets. Because Setline treats exercise and set order as immutable programme data rather than mere suggestions, the exported JSON meticulously records every session exactly as it was planned and executed.

The export also captures the nuanced execution details that define Setline's tracking precision. Weight-and-repetition work often contains ordered partial or drop segments, such as `60 kg × 5` followed by `50 kg × 3`. The export accurately represents these multi-segment recordings. Furthermore, rest cadence is preserved natively. The JSON structure retains the authored target, any manual timer adjustments made during the session, and the actual completion-to-next-start gap as distinct, separate values.

When a user triggers an export, no account credentials or server-side data are included in the payload. The output is a pure, version 6 whole-state transfer document. This guarantees privacy and ensures that the backup is entirely portable.

## Bounded Preview-Replace Import: Validating State Replacement

Transferring data into Setline is handled with the same rigorous adherence to structure and safety as the export process. The import mechanism is explicitly designed as a bounded import preview with explicit whole-state replacement. Setline does not attempt to merge incoming JSON data with the existing local database piece-by-piece, which could lead to corrupted states or orphaned records. Instead, it enforces a complete replacement protocol.

When a user selects a versioned JSON file for import, the application first performs an explicit state validation. This validation phase checks the integrity of the incoming data against Setline's strict internal schema. It verifies that authored exercise and set orders are preserved, that double-progression rules match the expected format, and that workout history references valid movement identities.

Following validation, the user is presented with a bounded preview of the incoming state. This preview step is critical; it ensures that the user understands they are about to perform an explicit whole-state replacement. The user retains complete control over the action, aligning with the product principle that recommendations or systemic actions never silently change a programme. Only after the user confirms the preview does Setline replace the local document.

Because this import process acts on the entire state, it inherently resolves any complex sync conflicts by establishing the imported file as the absolute source of truth. It successfully transfers custom workout authoring, explicit Do later deferrals, and calendar-correct Today resolutions for scheduled sessions without silently falling back to bundled plans. The explicit nature of this workflow protects the user from accidental data loss.

## Preserving Data Integrity Across Transfers

A central pillar of Setline's brand and functional commitments is honest measurement. Throughout the application, recorded, calculated, and unavailable values must remain distinct. This strict separation must survive the round-trip of a JSON export and subsequent import.

When Setline records an estimated 1RM, it is explicitly labelled as a planning-only calculation, distinct from a verified top set load or maximum repetition test. If a user completes a shorter run, the application does not extrapolate it to a 10 km distance. Similarly, an easy carry is not recorded as a maximum effort, and missing measurements are never silently converted to zeros.

The versioned JSON format strictly enforces these distinctions. It serializes recorded workout evidence, ensuring that calculated provenance for deterministic progression recommendations is preserved. If a user receives a session-only load recommendation based on their latest comparable recorded workout, the JSON export retains the exact historical data points that generated that recommendation.

Furthermore, the data transfer preserves explicit in-session changes. Setline allows users to skip sets, add session-only extra sets, or move current steps to Do later. The application records these deviations without ever rewriting the underlying programme or future workouts. When exported and imported, the data structure accurately reflects these explicit execution records, maintaining the absolute boundary between the immutable written programme and the adaptable execution history.

## Feature Boundaries

Setline’s approach to data export and import is highly focused, and understanding its constraints is as important as understanding its capabilities. The product's scope is deliberately tightly bounded.

First, the system exclusively supports Setline's own versioned JSON format. Importing arbitrary workout formats from other applications or CSV files remains explicitly deferred. The bounded preview-replace import is strictly designed to handle versioned local JSON workout-data representing Setline's internal state.

Second, the export and import workflows are manual, user-initiated processes. They are distinct from the optional iCloud or Personal Platform synchronizations. While those cloud mechanisms manage background durability, the JSON export remains the definitive manual backup, completely bypassing network unreliability or account access issues.

Third, the import process is an all-or-nothing whole-state replacement. It does not support selective importing of a single custom workout or merging of specific history records from a friend's exported file. This architectural decision guarantees deterministic behavior and eliminates the risk of fragmented or inconsistent local states.

Features such as automatic background JSON generation, Health integrations, direct sensor data import, and social sharing features remain deferred. The current release is strictly focused on providing a stable, fast, and honest execution layer for user-authored programmes.

## Internal-link Suggestions

- **Link to custom programmes guide:** When mentioning "Monday-based 1–16 week custom programmes," link to an internal article detailing how to build and schedule block training within Setline.
- **Link to honest measurement principles:** On the phrase "recorded, calculated, and unavailable values stay distinct," provide a link to the engineering blog post regarding Setline's data schema and analytics integrity.
- **Link to execution deviations:** Connect "explicitly skip, add a session-only set, or move the current step to Do later" to the support page explaining flexible session execution and how deviations are logged.

## Next Action

If you need to secure your workout history or transfer your custom 12-week programme to a new device, navigate to the Settings tab in the Setline app today and generate your versioned JSON export. Store the file in a secure local or personal cloud directory to ensure your uncompromised workout data remains fully under your control.

---

## Source Notes

This article is based strictly on the current repository evidence documented in Setline's canonical specifications.

- **PRODUCT.md**: Supports the core positioning that Setline is a "mobile-first workout execution tracker" requiring no network request during active workouts. Confirms the operating context (gym environment with unreliable connectivity). Documents the "versioned JSON transfer lets a user download and preview-replace the complete workout state," and explicitly notes that "importing arbitrary workout formats remains deferred." Supports the principle of "honest measurement" and the immutable nature of exercise/set order.
- **PROJECT_STATUS.md**: Confirms the specific implementation details: "Versioned JSON download plus validated, bounded import preview and explicit whole-state replacement for local workout data." Corroborates the handling of "partial and drop-set segments such as 60 kg × 5 followed by 50 kg × 3" and the explicit separation of "authored, adjusted, and actual rest." Supports the explicit data validations, noting that the JSON transfer involves no "account credentials or server-side data." Validates that iCloud/Personal Platform sync is optional and does not execute during active workouts.
