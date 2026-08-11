# Setline iOS release draft

This file is preparation only. No App Store Connect record has been created.

## Identity

- Name: Setline
- Bundle ID: `com.significanthobbies.setline`
- Version: `1.0.0`
- Build: `1`
- SKU: `setline-ios-1`
- Primary language: English (U.S.)
- Category: Health & Fitness
- Minimum iOS: 17.0
- Copyright: `2026 Sarthak Agrawal`
- License: Apple's standard EULA
- Content rights: all bundled copy, artwork, and sample programme content is owned or licensed for distribution

## Store copy

**Subtitle**
Follow every set precisely

**Promotional text**
Bring your authored programme into the gym, record what really happened, and keep every set usable offline.

**Description**
Setline is the execution layer for a programme you already trust. Start the planned workout, follow exercises and sets in their exact authored order, record weight, repetitions, timed work, cardio, mobility, and drop segments, and let timestamp-based rest timing survive interruptions.

Explicit session changes stay explicit: skip a set, do it later, or add an extra without silently rewriting the next workout. History keeps planned and recorded values separate, while deterministic progression suggestions require your approval.

Active workouts are device-first and remain usable without a connection. Export or preview-replace the complete local state whenever you choose.

**Keywords**
workout,training,strength,gym,sets,reps,rest timer,programme,fitness log

## URLs

- Support: `https://setline.significanthobbies.com`
- Privacy: `https://setline.significanthobbies.com/privacy`

## Privacy draft

- Tracking: none
- Third-party advertising: none
- Local workout and profile data: remains on device in device-only mode
- Optional account mode sends the user's name, email address, account identifier,
  programme, templates, workout history, and profile settings to Setline's service
  so the data can sync across devices
- App Store Connect answer for this build: “Yes, we collect data from this app”
- Data linked to the user for App Functionality:
  - Contact Info: Name, Email Address
  - Health & Fitness: Fitness
  - Identifiers: User ID
  - User Content: Other User Content (authored programmes, workout templates,
    workout records, and profile settings)
- Data is not used for tracking, third-party advertising, developer advertising,
  or analytics
- IDFA: not used

## Age rating draft

- Made for Kids: No
- Violence, sexual content, profanity, drugs, alcohol, gambling, horror: None
- Medical or treatment claims: None
- User-generated content, messaging, unrestricted web access: None

Confirm the rating produced by App Store Connect's current questionnaire.

## Review notes draft

Setline does not generate or prescribe a training programme. The bundled sample demonstrates exact-order workout playback. All active workout actions work offline. No HealthKit or sensor data is requested.

Device-only mode is available without creating an account. Optional cloud sync
offers Sign in with Apple beside Google. Existing Google users explicitly add
Apple while authenticated; matching email text does not silently merge
identities. The Apple token is nonce-bound and validated by the service for
`com.significanthobbies.setline`.

## Screenshots and release

- iPhone 6.9-inch portrait: `artifacts/app-store/iphone-6.9/today.jpg`,
  `plan.jpg`, `workout-player.jpg`, `rest-timer.jpg`, and `history.jpg`
- Each store image is `1320 × 2868`, has no alpha channel, and is an accepted
  6.9-inch screenshot size
- Accessibility evidence is retained separately and is not part of the default store sequence
- iPad screenshots: not required; the target is iPhone only
- App previews: omit for version 1.0
- Release: manual
