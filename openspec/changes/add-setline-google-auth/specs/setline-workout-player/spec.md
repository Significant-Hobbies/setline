## MODIFIED Requirements

### Requirement: Device-local continuity
The system SHALL persist active-session progress and completed-session history
on the device before any network request. In authenticated mode it SHALL also
reconcile the versioned state with the current user's private cloud record
without making cloud availability a prerequisite for workout execution.

#### Scenario: User reloads during a workout
- **WHEN** the user reloads Setline after completing at least one set
- **THEN** the system restores the active workout, completed results, and any
  in-progress rest deadline from device storage before cloud reconciliation

#### Scenario: Signed-in user opens another device
- **WHEN** an authenticated user opens Setline on a device whose local state is
  older than the user's cloud state
- **THEN** the system restores the newer cloud envelope without changing the
  authored exercise or set order

#### Scenario: Cloud is unavailable
- **WHEN** a signed-in user starts or continues a workout without connectivity
- **THEN** completing sets, skipping sets, rest timers, and local history remain
  fully operational
