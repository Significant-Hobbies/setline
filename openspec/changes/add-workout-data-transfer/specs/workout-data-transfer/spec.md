## ADDED Requirements

### Requirement: Versioned workout-data export
The system SHALL let the user download the current device workout state in a
versioned Setline JSON envelope without a network request. The envelope MUST
contain no account identity, credential, cookie, or cloud-provider metadata.

#### Scenario: User downloads a device copy
- **WHEN** the user selects Download Setline backup from the Programme view
- **THEN** the browser downloads a dated Setline JSON file containing the
  current validated active session and history

#### Scenario: User is offline
- **WHEN** the browser has no network connection and the user downloads JSON
- **THEN** the export completes from device state without contacting a server

### Requirement: Bounded import validation
The system SHALL reject a selected file before preview when its size, extension,
JSON syntax, transfer format, transfer version, export timestamp, or embedded
workout state is invalid. Rejection MUST leave current device and cloud state
unchanged.

#### Scenario: User selects unrelated JSON
- **WHEN** a JSON file does not contain the supported Setline transfer envelope
  and valid stored state
- **THEN** the system shows a specific import error and does not offer a replace
  action

#### Scenario: User selects an oversized file
- **WHEN** a selected file is larger than the documented transfer limit
- **THEN** the system rejects it before reading the file body

### Requirement: Preview before replacement
The system SHALL show current-device context plus the incoming export time,
active-workout summary, history count, and most recent completed workout before
any import mutation. It SHALL require an explicit replace action and provide a
cancel action.

#### Scenario: User previews valid workout data
- **WHEN** a selected file passes transfer and state validation
- **THEN** the system presents its summary while retaining the current device
  state

#### Scenario: User cancels import
- **WHEN** the user cancels from the preview
- **THEN** the preview closes and current device and cloud state remain
  unchanged

### Requirement: Device-first whole-state import
The system SHALL replace the active session and history together only after
explicit confirmation. It MUST persist the replacement on device first and use
the existing authenticated sync and conflict behavior without claiming a cloud
override.

#### Scenario: Device-only user confirms import
- **WHEN** a device-only user confirms a valid preview
- **THEN** the imported active session and history replace the current device
  copy and remain available offline

#### Scenario: Authenticated user confirms import
- **WHEN** an authenticated user confirms a valid preview
- **THEN** the replacement is saved on device and enters the existing account
  sync or offline-retry path

### Requirement: Accessible responsive transfer controls
The system SHALL keep export, file selection, preview, cancellation, and
replacement keyboard-operable with visible focus, descriptive labels, and
touch targets at least 44 pixels high.

#### Scenario: User imports on a phone
- **WHEN** the Programme view is approximately 390 pixels wide
- **THEN** the transfer controls and preview remain legible without horizontal
  scrolling
