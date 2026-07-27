"use client";

/*
THESIS: Setline is a daylight attempt board for executing a known workout, not a fitness dashboard.
OWN-WORLD: Chalk field, navy rules, safety-lime action slabs, blue recorded data, and condensed tabular numerals.
STORY: Resolve today's authored plan, execute each step in order, trust the rest deadline, then retain an honest local record.
FIRST VIEWPORT: The calendar-correct session fills the screen with block context and one unmistakable Start workout action.
FORM: Scoreboard split, the selected first-ranked staging from three probes; direction seed 9666e5f2.
*/

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type SetStateAction,
} from "react";
import Link from "next/link";
import {
  bindStateToAccount,
  clearStateAccountBinding,
  getAccountState,
  getGoogleConfiguration,
  getStateAccountId,
  signInWithGoogle,
  signOutAccount,
  startDeviceOnlyMode,
  type AccountState,
} from "./lib/auth-client";
import { readCloudState, writeCloudState } from "./lib/cloud-sync";
import {
  formatStepTarget,
  getProgrammePosition,
  PROGRAMME,
  PROGRAMME_SCHEDULE,
  resolveWorkout,
  type PlannedStep,
  type WorkoutId,
} from "./lib/programme";
import {
  emptyStoredState,
  deferActiveExecution,
  executionIsModified,
  executionIsValid,
  getActiveExecution,
  getExecution,
  getSessionMetrics,
  insertExtraExecution,
  makeWorkoutSession,
  parseStoredStateJson,
  PENDING_SYNC_KEY,
  startQueuedExecution,
  STORAGE_KEY,
  updateStoredState,
  type ExecutionRecord,
  type HistoryEntry,
  type SetSegment,
  type StoredState,
  type WorkoutSession,
} from "./lib/workout-state";

type View = "today" | "programme" | "history" | "progress";

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

type SyncStatus = "local" | "syncing" | "synced" | "offline" | "error";

const sampleTrend = [
  { label: "Start", weight: 65, reps: 5 },
  { label: "Target", weight: 65, reps: 6 },
  { label: "Range", weight: 65, reps: 7 },
  { label: "Progress", weight: 65, reps: 8 },
];

function wallClockNow() {
  return Date.now();
}

function formatClock(totalSeconds: number) {
  const safeSeconds = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function formatDuration(totalSeconds: number) {
  const minutes = Math.max(0, Math.round(totalSeconds / 60));
  return `${minutes} min`;
}

function formatTimedWork(totalSeconds: number) {
  const safeSeconds = Math.max(0, Math.round(totalSeconds));
  if (safeSeconds < 60) return `${safeSeconds} sec`;
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;
  return seconds === 0 ? `${minutes} min` : `${minutes}m ${seconds}s`;
}

function recordSummary(planned: PlannedStep, record: ExecutionRecord): string {
  if (planned.tracking === "weight-reps") {
    return `${record.segments
      .map((segment) => `${segment.weight ?? 0} kg × ${segment.reps ?? 0}`)
      .join(" → ")}${
      record.actualRpe ? ` @ RPE ${record.actualRpe}` : ""
    }`;
  }
  if (planned.tracking === "weight-duration") {
    const segment = record.segments[0];
    return `${segment.weight ?? 0} kg · ${formatTimedWork(segment.durationSeconds ?? 0)}`;
  }
  if (planned.tracking === "duration") {
    return formatTimedWork(record.segments[0]?.durationSeconds ?? 0);
  }
  if (planned.tracking === "reps") {
    return `${record.segments[0]?.reps ?? 0} reps`;
  }
  return "Completed";
}

function statusLabel(record: ExecutionRecord, index: number, activeIndex: number) {
  if (record.status === "completed") return "Done";
  if (record.status === "skipped") return "Skipped";
  if (index === activeIndex) return "Current";
  return "Upcoming";
}

export default function SetlineApp() {
  const [view, setView] = useState<View>("today");
  const [workoutState, setWorkoutState] = useState<StoredState>(emptyStoredState);
  const [hydrated, setHydrated] = useState(false);
  const [now, setNow] = useState(0);
  const [online, setOnline] = useState(true);
  const [notice, setNotice] = useState("");
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [accountState, setAccountState] = useState<AccountState | null>(null);
  const [googleConfigured, setGoogleConfigured] = useState(false);
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState("");
  const [syncStatus, setSyncStatus] = useState<SyncStatus>("local");
  const [correction, setCorrection] = useState<{
    id: string;
    draft: ExecutionRecord;
  } | null>(null);
  const workoutStateRef = useRef(workoutState);
  const lastSyncedAtRef = useRef(0);
  const cloudReadyRef = useRef(false);
  const syncTimerRef = useRef<number | null>(null);

  const session = workoutState.session;
  const history = workoutState.history;

  const setSession = useCallback((next: SetStateAction<WorkoutSession | null>) => {
    setWorkoutState((current) =>
      updateStoredState(current, {
        session:
          typeof next === "function"
            ? (next as (previous: WorkoutSession | null) => WorkoutSession | null)(
                current.session,
              )
            : next,
      }),
    );
  }, []);

  const setHistory = useCallback((next: SetStateAction<HistoryEntry[]>) => {
    setWorkoutState((current) =>
      updateStoredState(current, {
        history:
          typeof next === "function"
            ? (next as (previous: HistoryEntry[]) => HistoryEntry[])(current.history)
            : next,
      }),
    );
  }, []);

  const pushCurrentState = useCallback(async () => {
    if (accountState?.status !== "authenticated" || !navigator.onLine) {
      setSyncStatus(accountState?.status === "authenticated" ? "offline" : "local");
      return;
    }

    setSyncStatus("syncing");
    const localState = workoutStateRef.current;
    const result = await writeCloudState(localState);

    if (result.status === "ok") {
      lastSyncedAtRef.current = result.state.updatedAt;
      cloudReadyRef.current = true;
      localStorage.removeItem(PENDING_SYNC_KEY);
      setSyncStatus("synced");
      setAccountState((current) =>
        current?.status === "authenticated" && current.offline
          ? { ...current, offline: false }
          : current,
      );
      return;
    }

    if (result.status === "conflict") {
      lastSyncedAtRef.current = result.state.updatedAt;
      cloudReadyRef.current = true;
      workoutStateRef.current = result.state;
      setWorkoutState(result.state);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(result.state));
      localStorage.removeItem(PENDING_SYNC_KEY);
      setSyncStatus("synced");
      setNotice("A newer account copy was restored on this device.");
      return;
    }

    if (result.status === "unauthorized") {
      cloudReadyRef.current = false;
      startDeviceOnlyMode();
      setAccountState({ status: "local" });
      setSyncStatus("local");
      setNotice("Your Google session ended. Workout data remains on this device.");
      return;
    }

    localStorage.setItem(PENDING_SYNC_KEY, "true");
    setSyncStatus("error");
  }, [accountState]);

  const reconcileCloudState = useCallback(async () => {
    if (accountState?.status !== "authenticated" || !navigator.onLine) {
      setSyncStatus(accountState?.status === "authenticated" ? "offline" : "local");
      return;
    }

    setSyncStatus("syncing");
    const result = await readCloudState();
    if (result.status === "unauthorized") {
      cloudReadyRef.current = false;
      startDeviceOnlyMode();
      setAccountState({ status: "local" });
      setSyncStatus("local");
      return;
    }
    if (result.status === "unavailable") {
      cloudReadyRef.current = false;
      setSyncStatus("error");
      return;
    }

    const localState = workoutStateRef.current;
    if (!result.state || localState.updatedAt > result.state.updatedAt) {
      await pushCurrentState();
      return;
    }

    lastSyncedAtRef.current = result.state.updatedAt;
    cloudReadyRef.current = true;
    localStorage.removeItem(PENDING_SYNC_KEY);
    if (result.state.updatedAt > localState.updatedAt) {
      workoutStateRef.current = result.state;
      setWorkoutState(result.state);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(result.state));
      setNotice("Your latest account copy is ready.");
    }
    setSyncStatus("synced");
    setAccountState((current) =>
      current?.status === "authenticated" && current.offline
        ? { ...current, offline: false }
        : current,
    );
  }, [accountState, pushCurrentState]);

  useEffect(() => {
    let restoredState = emptyStoredState();
    let restorationNotice = "";
    const raw = localStorage.getItem(STORAGE_KEY);
    const parsed = parseStoredStateJson(raw);

    if (parsed) {
      restoredState = parsed;
    } else if (raw) {
      restorationNotice = "Local workout data could not be restored. A fresh session is ready.";
    }

    const onOnline = () => {
      setOnline(true);
    };
    const onOffline = () => {
      setOnline(false);
      setSyncStatus((current) => (current === "local" ? current : "offline"));
    };
    const onVisibility = () => setNow(wallClockNow());
    const onInstallPrompt = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPromptEvent);
    };

    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("beforeinstallprompt", onInstallPrompt);

    queueMicrotask(() => {
      setNow(wallClockNow());
      setOnline(navigator.onLine);
      workoutStateRef.current = restoredState;
      setWorkoutState(restoredState);
      if (restorationNotice) setNotice(restorationNotice);
      setHydrated(true);
    });

    void Promise.all([getAccountState(), getGoogleConfiguration()]).then(
      ([nextAccountState, configured]) => {
        if (nextAccountState.status === "authenticated") {
          const stateAccountId = getStateAccountId();
          if (stateAccountId && stateAccountId !== nextAccountState.account.id) {
            const resetState = emptyStoredState();
            workoutStateRef.current = resetState;
            setWorkoutState(resetState);
            localStorage.setItem(STORAGE_KEY, JSON.stringify(resetState));
            setNotice("This Google account will use its own private workout copy.");
          }
          bindStateToAccount(nextAccountState.account.id);
        }
        if (nextAccountState.status === "anonymous" && parsed) {
          startDeviceOnlyMode();
          setAccountState({ status: "local" });
          setSyncStatus("local");
        } else {
          setAccountState(nextAccountState);
          setSyncStatus(
            nextAccountState.status === "authenticated"
              ? navigator.onLine
                ? "syncing"
                : "offline"
              : "local",
          );
        }
        setGoogleConfigured(configured);
      },
    );

    if (process.env.NODE_ENV === "production" && "serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(() => {
        // Workout storage remains device-local even if shell caching is unavailable.
      });
    }

    return () => {
      window.removeEventListener("online", onOnline);
      window.removeEventListener("offline", onOffline);
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("beforeinstallprompt", onInstallPrompt);
    };
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    workoutStateRef.current = workoutState;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(workoutState));

    if (
      accountState?.status !== "authenticated" ||
      !cloudReadyRef.current ||
      workoutState.updatedAt <= lastSyncedAtRef.current
    ) {
      return;
    }

    localStorage.setItem(PENDING_SYNC_KEY, "true");
    if (!online) {
      queueMicrotask(() => setSyncStatus("offline"));
      return;
    }
    queueMicrotask(() => setSyncStatus("syncing"));
    if (syncTimerRef.current !== null) window.clearTimeout(syncTimerRef.current);
    syncTimerRef.current = window.setTimeout(() => {
      void pushCurrentState();
    }, 700);
  }, [accountState, hydrated, online, pushCurrentState, workoutState]);

  useEffect(() => {
    if (!hydrated || accountState?.status !== "authenticated") return;
    queueMicrotask(() => void reconcileCloudState());
  }, [accountState?.status, hydrated, online, reconcileCloudState]);

  useEffect(
    () => () => {
      if (syncTimerRef.current !== null) window.clearTimeout(syncTimerRef.current);
    },
    [],
  );

  useEffect(() => {
    if (!session) return;
    const timer = window.setInterval(() => setNow(wallClockNow()), 1000);
    return () => window.clearInterval(timer);
  }, [session]);

  const programmePosition = useMemo(
    () => getProgrammePosition(new Date(now)),
    [now],
  );
  const sessionWorkout = useMemo(
    () =>
      session
        ? resolveWorkout(session.workoutId, session.weekNumber, session.dayIndex)
        : null,
    [session],
  );
  const orderedExecutions = useMemo(
    () =>
      session
        ? session.queue
            .map((id) => getExecution(session, id))
            .filter((record): record is ExecutionRecord => record !== null)
        : [],
    [session],
  );
  const currentRecord = session ? getActiveExecution(session) : null;
  const currentSet = currentRecord?.step ?? null;
  const metrics = useMemo(
    () => (session ? getSessionMetrics(session) : null),
    [session],
  );
  const elapsedSeconds = session && now ? Math.max(0, (now - session.startedAt) / 1000) : 0;
  const restSeconds =
    session?.phase === "rest"
      ? session.pausedRestSeconds ??
        Math.max(0, Math.ceil(((session.restEndsAt ?? now) - now) / 1000))
      : 0;
  const currentValuesValid = executionIsValid(currentRecord);
  const correctionSet =
    correction === null ? null : correction.draft.step;
  const restFromRecord = session
    ? getExecution(session, session.restFromExecutionId)
    : null;
  const previousQueueRecord =
    session && session.activeIndex > 0
      ? orderedExecutions[session.activeIndex - 1] ?? null
      : null;

  const beginGoogleSignIn = async () => {
    if (
      accountState?.status === "local" &&
      !window.confirm(
        "Sign in and sync this device’s workout copy to your private Setline account copy?",
      )
    ) {
      return;
    }
    setAuthBusy(true);
    setAuthError("");
    try {
      await signInWithGoogle();
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : "Google sign-in could not start.");
      setAuthBusy(false);
    }
  };

  const continueOnDevice = () => {
    startDeviceOnlyMode();
    setAccountState({ status: "local" });
    setSyncStatus("local");
    setAuthError("");
    setNotice("Device-only mode is ready. Nothing is sent to an account.");
  };

  const signOut = async () => {
    if (
      !window.confirm(
        "Sign out and remove this account’s workout copy from this device? The private account copy remains available after you sign in again.",
      )
    ) {
      return;
    }
    setAuthBusy(true);
    setAuthError("");
    try {
      await signOutAccount();
      cloudReadyRef.current = false;
      lastSyncedAtRef.current = 0;
      localStorage.removeItem(PENDING_SYNC_KEY);
      localStorage.removeItem(STORAGE_KEY);
      clearStateAccountBinding();
      const resetState = emptyStoredState();
      workoutStateRef.current = resetState;
      setWorkoutState(resetState);
      setAccountState({ status: "anonymous" });
      setSyncStatus("local");
      setNotice("Signed out. This device copy was removed; your account copy remains.");
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Sign-out could not be completed.";
      setAuthError(message);
      setNotice(message);
    } finally {
      setAuthBusy(false);
    }
  };

  const navigate = (nextView: View) => {
    setView(nextView);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const startWorkout = (
    workoutId: Exclude<WorkoutId, "legacy-upper-a"> = programmePosition.schedule.workoutId,
    dayIndex = programmePosition.dayIndex,
  ) => {
    const template = resolveWorkout(workoutId, programmePosition.weekNumber, dayIndex);
    setCorrection(null);
    setSession(
      (existing) =>
        existing ??
        makeWorkoutSession(template, programmePosition.weekNumber, dayIndex),
    );
    setNotice(
      accountState?.status === "authenticated"
        ? `${template.name} started. Progress saves on this device first, then syncs.`
        : `${template.name} started. Progress is saved on this device.`,
    );
    setNow(wallClockNow());
    requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: "auto" }));
  };

  const updateCurrentRecord = (patch: Partial<ExecutionRecord>) => {
    setSession((existing) => {
      const active = existing ? getActiveExecution(existing) : null;
      if (!existing || !active) return existing;
      return {
        ...existing,
        records: existing.records.map((record) =>
          record.id === active.id ? { ...record, ...patch } : record,
        ),
      };
    });
  };

  const updateCurrentSegment = (
    segmentId: string,
    patch: Partial<SetSegment>,
  ) => {
    if (!currentRecord) return;
    updateCurrentRecord({
      segments: currentRecord.segments.map((segment) =>
        segment.id === segmentId ? { ...segment, ...patch } : segment,
      ),
    });
  };

  const addCurrentSegment = () => {
    if (!currentRecord || currentRecord.step.tracking !== "weight-reps") return;
    const last = currentRecord.segments[currentRecord.segments.length - 1];
    const nextNumber = currentRecord.segments.length + 1;
    updateCurrentRecord({
      segments: [
        ...currentRecord.segments,
        {
          id: `${currentRecord.id}:segment:${wallClockNow()}`,
          weight: last?.weight ?? 0,
          reps: 0,
          durationSeconds: null,
        },
      ],
    });
    setNotice(`Segment ${nextNumber} added to ${currentRecord.step.exercise}.`);
  };

  const removeCurrentSegment = (segmentId: string) => {
    if (!currentRecord || currentRecord.segments.length === 1) return;
    updateCurrentRecord({
      segments: currentRecord.segments.filter((segment) => segment.id !== segmentId),
    });
  };

  const saveCorrection = (status: "completed" | "skipped") => {
    if (!session || !correction || !correctionSet) return;
    if (status === "completed" && !executionIsValid(correction.draft)) {
      return;
    }
    const completedAt = correction.draft.completedAt ?? wallClockNow();
    setSession({
      ...session,
      records: session.records.map((record) =>
        record.id === correction.id
          ? {
              ...correction.draft,
              status,
              completedAt,
            }
          : record,
      ),
    });
    setCorrection(null);
    setNotice(
      `${correctionSet.exercise} ${status === "completed" ? "recording updated" : "marked skipped"}.`,
    );
  };

  const addExtraSet = (source = currentRecord) => {
    if (!session || !source) return;
    const id = `extra:${source.step.id}:${wallClockNow()}`;
    setSession((existing) => {
      if (!existing) return existing;
      const currentSource = getExecution(existing, source.id) ?? source;
      return insertExtraExecution(existing, currentSource, id);
    });
    setNotice(`Extra ${source.step.exercise} set added to this session only.`);
  };

  const deferCurrentSet = () => {
    if (!session || !currentRecord || session.phase !== "active") return;
    if (session.activeIndex >= session.queue.length - 1) {
      setNotice("This is already the final pending step.");
      return;
    }
    setSession(deferActiveExecution(session, wallClockNow()));
    setNotice(`${currentRecord.step.exercise} moved to the end of this session only.`);
  };

  const completeSet = () => {
    if (!session || !currentSet || !currentRecord) return;
    const completedAt = wallClockNow();
    const isFinal = session.activeIndex === session.queue.length - 1;
    const nextIndex = Math.min(session.activeIndex + 1, session.queue.length - 1);
    const needsRest = !isFinal && currentSet.restSeconds > 0;
    const nextId = isFinal ? null : session.queue[nextIndex];
    const performedPosition =
      session.records.filter((record) => record.status !== "pending").length + 1;

    setSession({
      ...session,
      completedAt: isFinal ? completedAt : null,
      phase: isFinal ? "summary" : needsRest ? "rest" : "active",
      activeIndex: nextIndex,
      restEndsAt: needsRest ? completedAt + currentSet.restSeconds * 1000 : null,
      pausedRestSeconds: null,
      authoredRestSeconds: currentSet.restSeconds,
      adjustedRestSeconds: currentSet.restSeconds,
      restFromExecutionId: needsRest ? currentRecord.id : null,
      records: session.records.map((record) =>
        record.id === currentRecord.id
          ? {
              ...record,
              status: "completed",
              startedAt: record.startedAt ?? completedAt,
              completedAt,
              performedPosition,
              adjustedRestSeconds: currentSet.restSeconds,
              actualRestSeconds: !needsRest && !isFinal ? 0 : record.actualRestSeconds,
            }
          : record.id === nextId && !needsRest
            ? { ...record, startedAt: completedAt }
            : record,
      ),
    });
    setNow(completedAt);
    setNotice(
      isFinal
        ? "Final step recorded. Review your session."
        : needsRest
          ? `${currentSet.exercise} recorded. Rest started.`
          : `${currentSet.exercise} recorded. Next step ready.`,
    );
    navigator.vibrate?.(isFinal ? [80, 40, 80] : 60);
  };

  const skipSet = () => {
    if (!session || !currentSet || !currentRecord) return;
    const completedAt = wallClockNow();
    const isFinal = session.activeIndex === session.queue.length - 1;
    const nextIndex = Math.min(session.activeIndex + 1, session.queue.length - 1);
    const nextId = isFinal ? null : session.queue[nextIndex];
    const performedPosition =
      session.records.filter((record) => record.status !== "pending").length + 1;
    setSession({
      ...session,
      completedAt: isFinal ? completedAt : null,
      phase: isFinal ? "summary" : "active",
      activeIndex: nextIndex,
      restEndsAt: null,
      pausedRestSeconds: null,
      authoredRestSeconds: 0,
      adjustedRestSeconds: 0,
      restFromExecutionId: null,
      records: session.records.map((record) =>
        record.id === currentRecord.id
          ? {
              ...record,
              status: "skipped",
              startedAt: record.startedAt ?? completedAt,
              completedAt,
              performedPosition,
            }
          : record.id === nextId
            ? { ...record, startedAt: completedAt }
            : record,
      ),
    });
    setNotice(`${currentSet.exercise} ${currentSet.setLabel.toLowerCase()} skipped.`);
  };

  const addRest = (seconds: number) => {
    setSession((existing) => {
      if (!existing || existing.phase !== "rest") return existing;
      if (existing.pausedRestSeconds !== null) {
        return {
          ...existing,
          pausedRestSeconds: existing.pausedRestSeconds + seconds,
          adjustedRestSeconds: existing.adjustedRestSeconds + seconds,
          records: existing.records.map((record) =>
            record.id === existing.restFromExecutionId
              ? {
                  ...record,
                  adjustedRestSeconds: record.adjustedRestSeconds + seconds,
                }
              : record,
          ),
        };
      }
      return {
        ...existing,
        restEndsAt:
          Math.max(existing.restEndsAt ?? wallClockNow(), wallClockNow()) +
          seconds * 1000,
        adjustedRestSeconds: existing.adjustedRestSeconds + seconds,
        records: existing.records.map((record) =>
          record.id === existing.restFromExecutionId
            ? {
                ...record,
                adjustedRestSeconds: record.adjustedRestSeconds + seconds,
              }
            : record,
        ),
      };
    });
  };

  const toggleRestPause = () => {
    setSession((existing) => {
      if (!existing || existing.phase !== "rest") return existing;
      if (existing.pausedRestSeconds !== null) {
        return {
          ...existing,
          restEndsAt: wallClockNow() + existing.pausedRestSeconds * 1000,
          pausedRestSeconds: null,
        };
      }
      return {
        ...existing,
        restEndsAt: null,
        pausedRestSeconds: Math.max(
          0,
          Math.ceil(
            ((existing.restEndsAt ?? wallClockNow()) - wallClockNow()) / 1000,
          ),
        ),
      };
    });
  };

  const beginNextSet = () => {
    const startedAt = wallClockNow();
    setSession((existing) => {
      if (!existing) return existing;
      return startQueuedExecution(existing, startedAt);
    });
    setNotice("Next step ready.");
  };

  const undoLastSet = () => {
    if (!session) return;
    const index =
      session.phase === "summary"
        ? session.activeIndex
        : Math.max(0, session.activeIndex - 1);
    const recordId = session.queue[index];
    const recordToReopen = getExecution(session, recordId);
    if (!recordToReopen) return;
    const followingId = session.queue[index + 1] ?? null;
    setSession({
      ...session,
      completedAt: null,
      phase: "active",
      activeIndex: index,
      restEndsAt: null,
      pausedRestSeconds: null,
      authoredRestSeconds: 0,
      adjustedRestSeconds: 0,
      restFromExecutionId: null,
      records: session.records.map((record) =>
        record.id === recordId
          ? {
              ...record,
              status: "pending",
              performedPosition: null,
              completedAt: null,
              actualRestSeconds: null,
            }
          : record.id === followingId
            ? { ...record, startedAt: null }
            : record,
      ),
    });
    setNotice(`${recordToReopen.step.exercise} reopened for correction.`);
    requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: "auto" }));
  };

  const saveWorkout = () => {
    if (!session || !metrics) return;
    const completedAt = session.completedAt ?? wallClockNow();
    const entry: HistoryEntry = {
      id: session.id,
      workoutId: session.workoutId,
      workoutName: session.workoutName,
      weekNumber: session.weekNumber,
      completedAt,
      durationSeconds: Math.max(60, (completedAt - session.startedAt) / 1000),
      completedSets: metrics.completedSets,
      modifiedSets: metrics.modifiedSets,
      extraSets: metrics.extraSets,
      deferredSets: metrics.deferredSets,
      skippedSets: metrics.skippedSets,
      workingVolume: metrics.workingVolume,
      warmupVolume: metrics.warmupVolume,
      completedDurationSeconds: metrics.completedDurationSeconds,
      totalActualRestSeconds: metrics.totalActualRestSeconds,
      averageRpe: metrics.averageRpe,
      quality: session.quality,
      detailsAvailable: true,
      executions: orderedExecutions.map((record) => ({
        ...record,
        segments: record.segments.map((segment) => ({ ...segment })),
      })),
    };
    setHistory((entries) => [entry, ...entries]);
    setCorrection(null);
    setSession(null);
    setView("history");
    setNotice(
      accountState?.status === "authenticated"
        ? "Workout saved on this device. Account sync is queued."
        : "Workout saved to device history.",
    );
  };

  const installApp = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    setInstallPrompt(null);
  };

  const clearLocalData = () => {
    if (!window.confirm("Clear this device’s Setline session and recorded workout history?")) {
      return;
    }
    setWorkoutState((current) =>
      updateStoredState(current, {
        session: null,
        history: [],
      }),
    );
    clearStateAccountBinding();
    setNotice("Local Setline data cleared.");
  };

  const discardSession = () => {
    if (!window.confirm("End this workout and discard its recorded set progress?")) {
      return;
    }
    setCorrection(null);
    setSession(null);
    setNotice("Workout discarded.");
  };

  if (!hydrated || accountState === null) {
    return <AccountLoading />;
  }

  if (accountState.status === "anonymous") {
    return (
      <AccountChoice
        busy={authBusy}
        error={authError}
        googleConfigured={googleConfigured}
        onDeviceOnly={continueOnDevice}
        onGoogle={() => void beginGoogleSignIn()}
      />
    );
  }

  if (session) {
    return (
      <main className="player-shell">
        {correction && correctionSet ? (
          <CorrectionPanel
            planned={correctionSet}
            record={correction.draft}
            onChangeRecord={(patch) =>
              setCorrection((current) =>
                current
                  ? { ...current, draft: { ...current.draft, ...patch } }
                  : current,
              )
            }
            onChangeSegment={(segmentId, patch) =>
              setCorrection((current) =>
                current
                  ? {
                      ...current,
                      draft: {
                        ...current.draft,
                        segments: current.draft.segments.map((segment) =>
                          segment.id === segmentId
                            ? { ...segment, ...patch }
                            : segment,
                        ),
                      },
                    }
                  : current,
              )
            }
            onAddSegment={() =>
              setCorrection((current) => {
                if (
                  !current ||
                  current.draft.step.tracking !== "weight-reps"
                ) {
                  return current;
                }
                const last =
                  current.draft.segments[current.draft.segments.length - 1];
                return {
                  ...current,
                  draft: {
                    ...current.draft,
                    segments: [
                      ...current.draft.segments,
                      {
                        id: `${current.draft.id}:segment:${wallClockNow()}`,
                        weight: last?.weight ?? 0,
                        reps: 0,
                        durationSeconds: null,
                      },
                    ],
                  },
                };
              })
            }
            onRemoveSegment={(segmentId) =>
              setCorrection((current) =>
                current && current.draft.segments.length > 1
                  ? {
                      ...current,
                      draft: {
                        ...current.draft,
                        segments: current.draft.segments.filter(
                          (segment) => segment.id !== segmentId,
                        ),
                      },
                    }
                  : current,
              )
            }
            onClose={() => setCorrection(null)}
            onComplete={() => saveCorrection("completed")}
            onSkip={() => saveCorrection("skipped")}
          />
        ) : null}
        <div className="session-bar">
          <button className="text-button" onClick={discardSession}>
            End session
          </button>
          <div>
            <span className="session-kicker">
              Week {session.weekNumber} · {session.workoutName}
            </span>
            <strong>{session.phase === "summary" ? "Session review" : "Workout in progress"}</strong>
          </div>
          <div className="session-clock" aria-label={`Elapsed time ${formatClock(elapsedSeconds)}`}>
            <span>ELAPSED</span>
            <strong>{formatClock(elapsedSeconds)}</strong>
          </div>
        </div>

        <div
          className="workout-progress"
          aria-label={`${(metrics?.completedSets ?? 0) + (metrics?.skippedSets ?? 0)} of ${orderedExecutions.length} steps resolved`}
        >
          <span
            style={{
              transform: `scaleX(${orderedExecutions.length ? ((metrics?.completedSets ?? 0) + (metrics?.skippedSets ?? 0)) / orderedExecutions.length : 0})`,
            }}
          />
        </div>

        <div className="live-region" aria-live="polite">
          {notice}
        </div>

        {session.phase === "summary" && metrics ? (
          <section className="summary-board">
            <div className="summary-heading">
              <div>
                <span className="section-code">SESSION COMPLETE</span>
                <h1>{session.workoutName} is on the record.</h1>
              </div>
              <span className="quality-stamp">
                {accountState.status === "authenticated" ? "SYNC" : "LOCAL"}
              </span>
            </div>

            <div className="summary-lead">
              <strong>{formatDuration(elapsedSeconds)}</strong>
              <span>Planned {sessionWorkout?.expectedMinutes ?? 0} min</span>
            </div>

            <div className="metric-grid">
              <Metric label="Completed" value={`${metrics.completedSets}/${orderedExecutions.length}`} provenance="Recorded" />
              <Metric label="Modified" value={String(metrics.modifiedSets)} provenance="Recorded vs programme" />
              <Metric label="Extra" value={String(metrics.extraSets)} provenance="Session only" />
              <Metric label="Skipped" value={String(metrics.skippedSets)} provenance="Recorded" />
              <Metric label="Working volume" value={`${metrics.workingVolume.toLocaleString()} kg`} provenance="Calculated" />
              <Metric label="Warm-up volume" value={`${metrics.warmupVolume.toLocaleString()} kg`} provenance="Calculated" />
              <Metric
                label="Average RPE"
                value={metrics.averageRpe === null ? "—" : metrics.averageRpe.toFixed(1)}
                provenance="Calculated from recorded RPE"
              />
              <Metric
                label="Timed work"
                value={formatDuration(metrics.completedDurationSeconds)}
                provenance="Recorded from completed timed steps"
              />
              <Metric
                label="Actual rest"
                value={formatTimedWork(metrics.totalActualRestSeconds)}
                provenance="Calculated from completion and next-start timestamps"
              />
            </div>

            <ExecutionLedger executions={orderedExecutions} />

            <fieldset className="quality-fieldset">
              <legend>How would you rate the session quality?</legend>
              <p className="field-help">Optional. No rating is recorded until you choose one.</p>
              <div className="quality-options">
                {[
                  { score: 2, label: "Poor" },
                  { score: 4, label: "Solid" },
                  { score: 5, label: "Excellent" },
                ].map(({ score, label }) => (
                  <button
                    className={session.quality === score ? "quality-option active" : "quality-option"}
                    key={score}
                    onClick={() => setSession({ ...session, quality: score })}
                    type="button"
                    aria-pressed={session.quality === score}
                  >
                    <strong>{score}</strong>
                    <span>{label}</span>
                  </button>
                ))}
              </div>
            </fieldset>

            <button className="secondary-action" onClick={undoLastSet}>
              Reopen final step
            </button>
            <button className="action-slab" onClick={saveWorkout}>
              Save workout
              <span>
                {accountState.status === "authenticated"
                  ? "Save locally, then sync"
                  : "Stored on this device"}
              </span>
            </button>
          </section>
        ) : (
          <div className="player-layout">
            <section className="attempt-board">
              {session.phase === "rest" && currentSet && restFromRecord ? (
                <RestBoard
                  session={session}
                  currentSet={currentSet}
                  previousSet={restFromRecord.step}
                  previousRecord={restFromRecord}
                  restSeconds={restSeconds}
                  onAddRest={addRest}
                  onAddExtra={() => addExtraSet(restFromRecord)}
                  onTogglePause={toggleRestPause}
                  onBegin={beginNextSet}
                  onUndo={undoLastSet}
                />
              ) : currentSet && currentRecord ? (
                <>
                  {previousQueueRecord &&
                  previousQueueRecord.status !== "pending" ? (
                    <div className="undo-strip">
                      <span>
                        Previous step{" "}
                        {previousQueueRecord.status === "skipped"
                          ? "skipped"
                          : "recorded"}
                      </span>
                      <button onClick={undoLastSet}>
                        {previousQueueRecord.status === "skipped"
                          ? "Undo skip"
                          : "Undo recording"}
                      </button>
                    </div>
                  ) : null}
                  <div className="attempt-heading">
                    <div>
                      <span className="set-type">{currentSet.setType}</span>
                      <h1>{currentSet.exercise}</h1>
                    </div>
                    <span className="set-count">{currentSet.setLabel}</span>
                  </div>

                  <div className="target-block">
                    <span>TARGET</span>
                    <div className="target-notation target-copy">
                      <strong>{formatStepTarget(currentSet)}</strong>
                    </div>
                    <div className="target-meta">
                      <span>
                        {currentSet.restSeconds
                          ? `Rest after step ${formatClock(currentSet.restSeconds)}`
                          : "Next step follows immediately"}
                      </span>
                      <span>Target RPE {currentSet.targetRpe ?? "—"}</span>
                    </div>
                  </div>

                  <div className="previous-strip">
                    <span>PLAN DOSE</span>
                    <strong>
                      {currentSet.setLabel}
                      {currentSet.optional ? " · Optional / conditional" : ""}
                    </strong>
                  </div>

                  <div className="cue-strip">
                    <span>FORM CUE</span>
                    <p>{currentSet.cue}</p>
                  </div>

                  <fieldset className="actuals-fieldset">
                    <legend>Actual result</legend>
                    <ActualInputs
                      planned={currentSet}
                      record={currentRecord}
                      onChangeRecord={updateCurrentRecord}
                      onChangeSegment={updateCurrentSegment}
                      onAddSegment={addCurrentSegment}
                      onRemoveSegment={removeCurrentSegment}
                    />
                  </fieldset>
                  {!currentValuesValid ? (
                    <p className="input-prompt">
                      Finish every segment to enable completion.
                    </p>
                  ) : null}

                  <div className="attempt-actions">
                    <button
                      className="action-slab"
                      disabled={!currentValuesValid}
                      onClick={completeSet}
                    >
                      Complete step
                      <span>
                        {currentSet.restSeconds
                          ? `Starts ${formatClock(currentSet.restSeconds)} rest`
                          : "Advances in the written order"}
                      </span>
                    </button>
                    <button className="secondary-action" onClick={skipSet}>
                      Skip this {currentSet.optional ? "optional step" : "step"}
                    </button>
                    <div className="deviation-actions">
                      <button type="button" onClick={() => addExtraSet()}>
                        <strong>Add another set</strong>
                        <span>This session only</span>
                      </button>
                      <button type="button" onClick={deferCurrentSet}>
                        <strong>Do later</strong>
                        <span>Moves to session end</span>
                      </button>
                    </div>
                  </div>
                </>
              ) : null}
            </section>

            <SetRail
              session={session}
              executions={orderedExecutions}
              onEdit={(record) =>
                setCorrection({
                  id: record.id,
                  draft: {
                    ...record,
                    segments: record.segments.map((segment) => ({ ...segment })),
                  },
                })
              }
            />
          </div>
        )}
      </main>
    );
  }

  return (
    <main className="app-shell">
      <header className="app-header">
        <button className="wordmark" onClick={() => navigate("today")} aria-label="Setline home">
          SETLINE
        </button>
        <div className="header-actions">
          <span className={online ? "connection-state" : "connection-state offline"}>
            <i />
            {accountState.status === "authenticated"
              ? syncStatus === "syncing"
                ? "Syncing"
                : syncStatus === "synced"
                  ? "Synced"
                  : syncStatus === "error"
                    ? "Sync pending"
                    : syncStatus === "offline"
                      ? "Offline · local"
                      : "Account ready"
              : online
                ? "Device only"
                : "Offline · device"}
          </span>
          <AccountControl
            accountState={accountState}
            busy={authBusy}
            googleConfigured={googleConfigured}
            onGoogle={() => void beginGoogleSignIn()}
            onRetry={() => void reconcileCloudState()}
            onSignOut={() => void signOut()}
            syncStatus={syncStatus}
          />
          {installPrompt ? (
            <button className="install-button" onClick={installApp}>
              Install
            </button>
          ) : null}
        </div>
      </header>

      <div className="live-region" aria-live="polite">
        {notice}
      </div>

      {view === "today" ? (
        <TodayView
          accountState={accountState}
          position={programmePosition}
          onStart={startWorkout}
          onViewProgramme={() => navigate("programme")}
        />
      ) : null}
      {view === "programme" ? (
        <ProgrammeView
          accountState={accountState}
          onClear={clearLocalData}
          onStart={startWorkout}
          position={programmePosition}
        />
      ) : null}
      {view === "history" ? <HistoryView history={history} /> : null}
      {view === "progress" ? <ProgressView history={history} /> : null}

      <nav className="bottom-nav" aria-label="Primary navigation">
        {[
          ["today", "Today"],
          ["programme", "Programme"],
          ["history", "History"],
          ["progress", "Progress"],
        ].map(([id, label]) => (
          <button
            key={id}
            className={view === id ? "active" : ""}
            aria-current={view === id ? "page" : undefined}
            onClick={() => navigate(id as View)}
          >
            <span className="nav-mark" />
            {label}
          </button>
        ))}
      </nav>
    </main>
  );
}

function AccountLoading() {
  return (
    <main className="account-shell" aria-busy="true">
      <section className="account-board loading">
        <span className="section-code">SETLINE · LOADING</span>
        <h1>Your plan is coming back.</h1>
        <p>Restoring this device’s saved state.</p>
      </section>
    </main>
  );
}

function AccountChoice({
  busy,
  error,
  googleConfigured,
  onDeviceOnly,
  onGoogle,
}: {
  busy: boolean;
  error: string;
  googleConfigured: boolean;
  onDeviceOnly: () => void;
  onGoogle: () => void;
}) {
  return (
    <main className="account-shell">
      <section className="account-board">
        <div className="account-wordmark">SETLINE</div>
        <div className="account-heading">
          <span className="section-code">ACCOUNT OR DEVICE · YOUR CALL</span>
          <h1>Keep the plan close.</h1>
          <p>
            Google sign-in keeps one private Setline workout copy available across devices. Device-only
            mode keeps everything in this browser.
          </p>
        </div>

        <div className="account-facts" aria-label="Storage choices">
          <div>
            <strong>Google sync</strong>
            <span>Private D1 copy · basic Google identity scopes</span>
          </div>
          <div>
            <strong>Device only</strong>
            <span>No account · full offline workout player</span>
          </div>
          <div>
            <strong>Both modes</strong>
            <span>Sets save locally before any network request</span>
          </div>
        </div>

        <button
          className="google-action"
          disabled={!googleConfigured || busy}
          onClick={onGoogle}
          type="button"
        >
          <span aria-hidden="true">G</span>
          {busy ? "Opening Google…" : "Continue with Google"}
        </button>
        {!googleConfigured ? (
          <p className="account-availability">Google sign-in is not configured in this environment.</p>
        ) : null}
        <button className="secondary-action account-local-action" onClick={onDeviceOnly} type="button">
          Use this device only
        </button>
        {error ? (
          <p className="input-error" role="alert">
            {error}
          </p>
        ) : null}

        <p className="account-legal">
          By continuing with Google, you agree to the <Link href="/terms">terms</Link>{" "}
          and acknowledge the <Link href="/privacy">privacy notice</Link>.
        </p>
      </section>
    </main>
  );
}

function AccountControl({
  accountState,
  busy,
  googleConfigured,
  onGoogle,
  onRetry,
  onSignOut,
  syncStatus,
}: {
  accountState: Exclude<AccountState, { status: "anonymous" }>;
  busy: boolean;
  googleConfigured: boolean;
  onGoogle: () => void;
  onRetry: () => void;
  onSignOut: () => void;
  syncStatus: SyncStatus;
}) {
  if (accountState.status === "local") {
    return (
      <button
        className="account-compact"
        disabled={!googleConfigured || busy}
        onClick={onGoogle}
        type="button"
      >
        {busy ? "Opening…" : "Sign in & sync"}
      </button>
    );
  }

  const syncLabel =
    syncStatus === "syncing"
      ? "Syncing now"
      : syncStatus === "synced"
        ? "Private copy synced"
        : syncStatus === "offline"
          ? "Offline · saved locally"
          : syncStatus === "error"
            ? "Sync pending"
            : "Account ready";

  return (
    <details className="account-menu">
      <summary>
        <span>{accountState.account.name.split(" ")[0] || "Account"}</span>
      </summary>
      <div>
        <strong>{accountState.account.name}</strong>
        <span>{accountState.account.email}</span>
        <small>{syncLabel}</small>
        {syncStatus === "error" ? (
          <button disabled={busy} onClick={onRetry} type="button">
            Retry sync
          </button>
        ) : null}
        <button disabled={busy} onClick={onSignOut} type="button">
          {busy ? "Signing out…" : "Sign out"}
        </button>
      </div>
    </details>
  );
}

function TodayView({
  accountState,
  position,
  onStart,
  onViewProgramme,
}: {
  accountState: Exclude<AccountState, { status: "anonymous" }>;
  position: ReturnType<typeof getProgrammePosition>;
  onStart: (
    workoutId?: Exclude<WorkoutId, "legacy-upper-a">,
    dayIndex?: number,
  ) => void;
  onViewProgramme: () => void;
}) {
  const preview = position.workout.steps.filter(
    (planned, index, steps) =>
      steps.findIndex((candidate) => candidate.exercise === planned.exercise) === index,
  ).slice(0, 5);
  return (
    <div className="page-view today-view">
      <section className="today-intro">
        <div>
          <span className="section-code">
            WEEK {String(position.weekNumber).padStart(2, "0")} · {PROGRAMME.startLabel}—{PROGRAMME.endLabel}
          </span>
          <h1>{position.workout.name} is set.</h1>
          <p>Follow the written sequence. Record the work. Review the block after Week 12.</p>
        </div>
        <div className="adherence-stamp">
          <strong>{position.workout.steps.length}</strong>
          <span>steps ready</span>
        </div>
      </section>

      <section className="today-workout">
        <div className="workout-title">
          <div>
            <span className="day-chip">TODAY · {position.schedule.time}</span>
            <h2>{position.workout.name}</h2>
          </div>
          <span className="sample-badge">WEEK {position.weekNumber}</span>
        </div>

        <button className="action-slab start-action" onClick={() => onStart()}>
          Start workout
          <span>Opens with {position.workout.steps[0].exercise.toLowerCase()}</span>
        </button>

        <div className="workout-facts">
          <Metric label="Planned" value={`${position.workout.expectedMinutes} min`} provenance="Programme" />
          <Metric label="Activities" value={String(preview.length)} provenance="First distinct movements" />
          <Metric label="Steps" value={String(position.workout.steps.length)} provenance="Exact authored order" />
          <Metric
            label="First target"
            value={formatStepTarget(position.workout.steps[0])}
            provenance={position.workout.steps[0].exercise}
          />
        </div>

        <ol className="exercise-preview">
          {preview.map((planned, index) => (
            <li key={planned.id}>
              <span>{String(index + 1).padStart(2, "0")}</span>
              <div>
                <strong>{planned.exercise}</strong>
                <small>{planned.setType}</small>
              </div>
              <b>{formatStepTarget(planned)}</b>
            </li>
          ))}
        </ol>

      </section>

      <section className="week-strip">
        <div className="section-heading">
          <div>
            <span className="section-code">THIS WEEK</span>
            <h2>Seven days. One written rhythm.</h2>
          </div>
          <button className="text-button" onClick={onViewProgramme}>
            View programme
          </button>
        </div>
        <div className="schedule-grid">
          {PROGRAMME_SCHEDULE.map((item) => (
            <div className={item.dayIndex === position.dayIndex ? "schedule-day active" : "schedule-day"} key={item.day}>
              <span>{item.day}</span>
              <strong>{item.name}</strong>
              <small>{item.time}</small>
              <b>{item.dayIndex === position.dayIndex ? "Today" : "Planned"}</b>
            </div>
          ))}
        </div>
      </section>

      <aside className="local-note">
        <span className="local-mark">L</span>
        <div>
          <strong>Ready without a signal.</strong>
          <p>
            {accountState.status === "authenticated"
              ? "Workout actions save on this device first. Your private account copy catches up when a connection is available."
              : "Active workouts and recorded history stay on this device. Nothing is sent to an account."}
          </p>
        </div>
      </aside>
    </div>
  );
}

function ProgrammeView({
  accountState,
  onClear,
  onStart,
  position,
}: {
  accountState: Exclude<AccountState, { status: "anonymous" }>;
  onClear: () => void;
  onStart: (
    workoutId?: Exclude<WorkoutId, "legacy-upper-a">,
    dayIndex?: number,
  ) => void;
  position: ReturnType<typeof getProgrammePosition>;
}) {
  return (
    <div className="page-view programme-view">
      <section className="page-heading">
        <span className="section-code">WEEK {position.weekNumber} OF 12 · FIXED BLOCK</span>
        <h1>Strength, cardio and mobility—already decided.</h1>
        <p>{PROGRAMME.name}. Exercise and step order is locked during execution.</p>
      </section>

      <div className="programme-layout">
        <section className="programme-schedule">
          {PROGRAMME_SCHEDULE.map((item, index) => {
            const workout = resolveWorkout(item.workoutId, position.weekNumber, item.dayIndex);
            return (
              <article key={item.day} className={item.dayIndex === position.dayIndex ? "programme-day current" : "programme-day"}>
                <div className="programme-index">{String(index + 1).padStart(2, "0")}</div>
                <div>
                  <span>{item.day} · {item.time}</span>
                  <h2>{item.name}</h2>
                  <p>{workout.steps.length} ordered steps · {workout.notes[0]}</p>
                </div>
                <div className="programme-day-actions">
                  <strong>{workout.expectedMinutes} min</strong>
                  <button onClick={() => onStart(item.workoutId, item.dayIndex)}>
                    Start
                  </button>
                </div>
              </article>
            );
          })}
        </section>

        <aside className="programme-rules">
          <span className="section-code">PROGRAMME RULES</span>
          <dl>
            <div>
              <dt>Units</dt>
              <dd>Kilograms</dd>
            </div>
            <div>
              <dt>Progression</dt>
              <dd>Manual approval</dd>
            </div>
            <div>
              <dt>Execution mode</dt>
              <dd>Simple</dd>
            </div>
            <div>
              <dt>Storage</dt>
              <dd>
                {accountState.status === "authenticated"
                  ? "Device first · account sync"
                  : "Device only"}
              </dd>
            </div>
          </dl>
          {accountState.status === "local" ? (
            <button className="danger-link" onClick={onClear}>
              Clear local workout data
            </button>
          ) : (
            <p className="storage-help">
              Sign out and choose device-only mode before clearing this device copy.
            </p>
          )}
        </aside>
      </div>
    </div>
  );
}

function HistoryView({ history }: { history: HistoryEntry[] }) {
  return (
    <div className="page-view history-view">
      <section className="page-heading">
        <span className="section-code">WORKOUT HISTORY</span>
        <h1>The record, without interpretation.</h1>
        <p>Recorded values are yours. Volume and averages are calculated from those entries.</p>
      </section>

      {history.length ? (
        <div className="history-list">
          {history.map((entry) => (
            <section key={entry.id} className="history-entry">
              <article className="history-row">
                <div className="history-date">
                  <strong>
                    {new Intl.DateTimeFormat("en", { day: "2-digit", month: "short" })
                      .format(new Date(entry.completedAt))
                      .toUpperCase()}
                  </strong>
                  <span>RECORDED</span>
                </div>
                <div>
                  <h2>{entry.workoutName}</h2>
                  <p>
                    Week {entry.weekNumber} · {entry.completedSets} completed ·{" "}
                    {entry.modifiedSets} modified · {entry.skippedSets} skipped · quality{" "}
                    {entry.quality === null ? "not recorded" : `${entry.quality}/5`}
                  </p>
                </div>
                <div className="history-volume">
                  <strong>
                    {entry.workingVolume
                      ? `${entry.workingVolume.toLocaleString()} kg`
                      : formatDuration(entry.completedDurationSeconds)}
                  </strong>
                  <span>
                    {entry.workingVolume
                      ? "Calculated working volume"
                      : "Recorded timed work"}
                  </span>
                </div>
                <strong className="history-duration">{formatDuration(entry.durationSeconds)}</strong>
              </article>
              {entry.detailsAvailable ? (
                <details className="history-details">
                  <summary>
                    View every set, segment and gap
                    <span>{formatTimedWork(entry.totalActualRestSeconds)} actual rest</span>
                  </summary>
                  <ExecutionLedger executions={entry.executions} />
                </details>
              ) : (
                <p className="history-unavailable">
                  Per-set detail and cadence were unavailable in this older
                  summary-only record.
                </p>
              )}
            </section>
          ))}
        </div>
      ) : (
        <section className="empty-history">
          <div className="empty-mark">0</div>
          <div>
            <h2>No recorded workouts yet.</h2>
            <p>Complete any scheduled session and save the summary. Your first device-local entry will appear here.</p>
          </div>
        </section>
      )}

      <section className="sample-history">
        <div className="section-heading">
          <div>
            <span className="section-code">BLOCK REFERENCE</span>
            <h2>The plan is fixed; the record is yours.</h2>
          </div>
          <span className="sample-badge">12 WEEKS</span>
        </div>
        <div className="sample-history-grid">
          <Metric label="Start" value="27 Jul" provenance="Programme" />
          <Metric label="Finish" value="18 Oct" provenance="Programme" />
          <Metric label="Strength" value="4 / week" provenance="Programme" />
          <Metric label="Mobility" value="3 full / week" provenance="Programme" />
        </div>
      </section>
    </div>
  );
}

function ProgressView({ history }: { history: HistoryEntry[] }) {
  const recordedVolume = history[0]?.workingVolume;
  return (
    <div className="page-view progress-view">
      <section className="page-heading">
        <span className="section-code">BENCH PRESS · PROGRAMME RANGE</span>
        <h1>Progress keeps its ingredients visible.</h1>
        <p>Weight, repetitions, RPE, and volume remain separate. Setline does not collapse them into a mystery score.</p>
      </section>

      <section className="progress-board">
        <div className="progress-heading">
          <div>
            <span>WORKING WEIGHT</span>
            <strong>65 <small>kg</small></strong>
          </div>
          <div className="delta-stamp">
            <strong>5–8</strong>
            <span>Reps · add load after 3 × 8</span>
          </div>
        </div>

        <div className="bar-chart" role="img" aria-label="Programme bench press progression keeps 65 kilograms while repetitions move from five toward eight">
          {sampleTrend.map((point) => (
            <div className="bar-column" key={point.label}>
              <span>{point.weight} kg</span>
              <div style={{ height: `${(point.weight / 75) * 100}%` }} />
              <small>{point.label}</small>
            </div>
          ))}
        </div>

        <div className="progress-metrics">
          <Metric label="Starting weight" value="65 kg" provenance="Programme" />
          <Metric label="Target range" value="3 × 5–8" provenance="Programme" />
          <Metric label="Load increase" value="2.5 kg" provenance="After clean 3 × 8" />
          <Metric
            label="Latest local volume"
            value={recordedVolume ? `${recordedVolume.toLocaleString()} kg` : "—"}
            provenance={recordedVolume ? "Calculated from recorded workout" : "No recorded workout"}
          />
        </div>
      </section>

      <aside className="measurement-note">
        <strong>Measurement rule</strong>
        <p>Targets are programme data. Actuals are recorded by you. Volume and estimated 1RM are calculations. Sensor-only metrics remain unavailable.</p>
      </aside>
    </div>
  );
}

function ActualInputs({
  planned,
  record,
  onChangeRecord,
  onChangeSegment,
  onAddSegment,
  onRemoveSegment,
}: {
  planned: PlannedStep;
  record: ExecutionRecord;
  onChangeRecord: (patch: Partial<ExecutionRecord>) => void;
  onChangeSegment: (segmentId: string, patch: Partial<SetSegment>) => void;
  onAddSegment: () => void;
  onRemoveSegment: (segmentId: string) => void;
}) {
  const usesWeight =
    planned.tracking === "weight-reps" || planned.tracking === "weight-duration";
  const usesReps = planned.tracking === "weight-reps" || planned.tracking === "reps";
  const usesDuration =
    planned.tracking === "duration" || planned.tracking === "weight-duration";
  const editableSegments =
    planned.tracking === "weight-reps"
      ? record.segments
      : record.segments.slice(0, 1);

  if (planned.tracking === "completion") {
    return <p className="field-help">No numeric result is required for this step.</p>;
  }

  return (
    <>
      <div className="segment-stack">
        {editableSegments.map((segment, index) => (
          <section className="segment-editor" key={segment.id}>
            {planned.tracking === "weight-reps" ? (
              <div className="segment-heading">
                <strong>Segment {index + 1}</strong>
                {record.segments.length > 1 ? (
                  <button
                    aria-label={`Remove segment ${index + 1}`}
                    onClick={() => onRemoveSegment(segment.id)}
                    type="button"
                  >
                    Remove
                  </button>
                ) : (
                  <span>Standard set</span>
                )}
              </div>
            ) : null}

            <div className="segment-fields">
              {usesWeight ? (
                <label>
                  <span>Weight</span>
                  <div className="numeric-input">
                    <button
                      type="button"
                      aria-label={`Decrease segment ${index + 1} weight by 2.5 kilograms`}
                      onClick={() =>
                        onChangeSegment(segment.id, {
                          weight: Math.max(0, (segment.weight ?? 0) - 2.5),
                        })
                      }
                    >
                      −
                    </button>
                    <input
                      aria-label={`Segment ${index + 1} weight in kilograms`}
                      inputMode="decimal"
                      min="0"
                      step="0.5"
                      type="number"
                      value={segment.weight ?? 0}
                      onChange={(event) =>
                        onChangeSegment(segment.id, {
                          weight: Number(event.target.value),
                        })
                      }
                    />
                    <b>kg</b>
                    <button
                      type="button"
                      aria-label={`Increase segment ${index + 1} weight by 2.5 kilograms`}
                      onClick={() =>
                        onChangeSegment(segment.id, {
                          weight: (segment.weight ?? 0) + 2.5,
                        })
                      }
                    >
                      +
                    </button>
                  </div>
                </label>
              ) : null}

              {usesReps ? (
                <label>
                  <span>Reps completed</span>
                  <div className="numeric-input">
                    <button
                      type="button"
                      aria-label={`Decrease segment ${index + 1} repetitions by one`}
                      onClick={() =>
                        onChangeSegment(segment.id, {
                          reps: Math.max(0, (segment.reps ?? 0) - 1),
                        })
                      }
                    >
                      −
                    </button>
                    <input
                      aria-label={`Segment ${index + 1} completed repetitions`}
                      inputMode="numeric"
                      min="0"
                      step="1"
                      type="number"
                      value={segment.reps ?? 0}
                      onChange={(event) =>
                        onChangeSegment(segment.id, {
                          reps: Number(event.target.value),
                        })
                      }
                    />
                    <b>reps</b>
                    <button
                      type="button"
                      aria-label={`Increase segment ${index + 1} repetitions by one`}
                      onClick={() =>
                        onChangeSegment(segment.id, {
                          reps: (segment.reps ?? 0) + 1,
                        })
                      }
                    >
                      +
                    </button>
                  </div>
                </label>
              ) : null}

              {usesDuration ? (
                <label>
                  <span>Duration</span>
                  <div className="numeric-input">
                    <button
                      type="button"
                      aria-label="Decrease duration by 30 seconds"
                      onClick={() =>
                        onChangeSegment(segment.id, {
                          durationSeconds: Math.max(
                            0,
                            (segment.durationSeconds ?? 0) - 30,
                          ),
                        })
                      }
                    >
                      −
                    </button>
                    <output
                      aria-label={`Completed duration ${formatClock(segment.durationSeconds ?? 0)}`}
                    >
                      {formatClock(segment.durationSeconds ?? 0)}
                    </output>
                    <b>min:sec</b>
                    <button
                      type="button"
                      aria-label="Increase duration by 30 seconds"
                      onClick={() =>
                        onChangeSegment(segment.id, {
                          durationSeconds: (segment.durationSeconds ?? 0) + 30,
                        })
                      }
                    >
                      +
                    </button>
                  </div>
                </label>
              ) : null}
            </div>
          </section>
        ))}
      </div>

      {planned.tracking === "weight-reps" ? (
        <button className="add-segment" onClick={onAddSegment} type="button">
          Add drop or partial segment
          <span>Record another weight × reps portion in this set</span>
        </button>
      ) : null}

      {planned.setType === "Working" ? (
        <label>
          <span>RPE optional</span>
          <select
            aria-label="Actual RPE"
            value={record.actualRpe ?? ""}
            onChange={(event) =>
              onChangeRecord({
                actualRpe: event.target.value ? Number(event.target.value) : null,
              })
            }
          >
            <option value="">—</option>
            {[6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10].map((rpe) => (
              <option key={rpe} value={rpe}>
                {rpe}
              </option>
            ))}
          </select>
        </label>
      ) : null}
    </>
  );
}

function CorrectionPanel({
  planned,
  record,
  onChangeRecord,
  onChangeSegment,
  onAddSegment,
  onRemoveSegment,
  onClose,
  onComplete,
  onSkip,
}: {
  planned: PlannedStep;
  record: ExecutionRecord;
  onChangeRecord: (patch: Partial<ExecutionRecord>) => void;
  onChangeSegment: (segmentId: string, patch: Partial<SetSegment>) => void;
  onAddSegment: () => void;
  onRemoveSegment: (segmentId: string) => void;
  onClose: () => void;
  onComplete: () => void;
  onSkip: () => void;
}) {
  const valid = executionIsValid(record);
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (dialog && !dialog.open) dialog.showModal();
    return () => {
      if (dialog?.open) dialog.close();
    };
  }, []);

  const finish = (action: () => void) => {
    dialogRef.current?.close();
    action();
  };

  return (
    <dialog
      aria-labelledby="correction-title"
      className="correction-panel"
      onCancel={(event) => {
        event.preventDefault();
        finish(onClose);
      }}
      onKeyDown={(event) => {
        if (event.key !== "Tab") return;
        const dialog = dialogRef.current;
        const focusable = dialog?.querySelectorAll<HTMLElement>(
          'button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])',
        );
        if (!dialog || !focusable?.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }}
      ref={dialogRef}
    >
      <div className="correction-heading">
        <div>
          <span className="section-code">CORRECT RECORDED STEP</span>
          <h2 id="correction-title">{planned.exercise}</h2>
          <p>{planned.setLabel} · {formatStepTarget(planned)}</p>
        </div>
        <button
          aria-label="Close correction"
          autoFocus
          onClick={() => finish(onClose)}
          type="button"
        >
          Close
        </button>
      </div>
      <fieldset className="actuals-fieldset">
        <legend>Recorded result</legend>
        <ActualInputs
          planned={planned}
          record={record}
          onChangeRecord={onChangeRecord}
          onChangeSegment={onChangeSegment}
          onAddSegment={onAddSegment}
          onRemoveSegment={onRemoveSegment}
        />
      </fieldset>
      {!valid && record.status === "completed" ? (
        <p className="input-error" role="alert">
          Enter the recorded values required for this step.
        </p>
      ) : null}
      <div className="correction-actions">
        <button
          className="secondary-action"
          onClick={() => finish(onSkip)}
          type="button"
        >
          Mark skipped
        </button>
        <button
          className="action-slab"
          disabled={!valid}
          onClick={() => finish(onComplete)}
          type="button"
        >
          Save correction
          <span>Keeps workout order unchanged</span>
        </button>
      </div>
    </dialog>
  );
}

function RestBoard({
  session,
  currentSet,
  previousSet,
  previousRecord,
  restSeconds,
  onAddRest,
  onAddExtra,
  onTogglePause,
  onBegin,
  onUndo,
}: {
  session: WorkoutSession;
  currentSet: PlannedStep;
  previousSet: PlannedStep;
  previousRecord: ExecutionRecord;
  restSeconds: number;
  onAddRest: (seconds: number) => void;
  onAddExtra: () => void;
  onTogglePause: () => void;
  onBegin: () => void;
  onUndo: () => void;
}) {
  const paused = session.pausedRestSeconds !== null;
  return (
    <div className={restSeconds === 0 ? "rest-board finished" : "rest-board"}>
      <div
        className="rest-heading"
        role="timer"
        aria-label={`Rest timer ${formatClock(restSeconds)}`}
      >
        <span>{paused ? "REST PAUSED" : restSeconds === 0 ? "REST COMPLETE" : "RESTING"}</span>
        <strong>{formatClock(restSeconds)}</strong>
        <small>
          Authored {formatClock(session.authoredRestSeconds)}
          {session.adjustedRestSeconds !== session.authoredRestSeconds
            ? ` · adjusted ${formatClock(session.adjustedRestSeconds)}`
            : ""}
        </small>
      </div>

      <div className={restSeconds <= 10 ? "rest-progress warning" : "rest-progress"} aria-hidden="true">
        <span
          style={{
            transform: `scaleX(${Math.min(
              1,
              session.adjustedRestSeconds
                ? restSeconds / session.adjustedRestSeconds
                : 0,
            )})`,
          }}
        />
      </div>

      <div className="completed-receipt">
        <span>JUST RECORDED</span>
        <strong>{previousSet.exercise}</strong>
        <p>{recordSummary(previousSet, previousRecord)}</p>
        <button onClick={onUndo}>Undo recorded step</button>
      </div>

      <p className="sr-only" role="status" aria-live="assertive">
        {restSeconds === 0
          ? `Rest complete. Next: ${currentSet.exercise}, ${formatStepTarget(currentSet)}.`
          : ""}
      </p>

      <div className="next-attempt">
        <span>NEXT</span>
        <div>
          <strong>{currentSet.exercise}</strong>
          <small>{currentSet.setLabel}</small>
        </div>
        <b>{formatStepTarget(currentSet)}</b>
      </div>

      <div className="timer-controls">
        <button onClick={() => onAddRest(15)}>+15 sec</button>
        <button onClick={() => onAddRest(30)}>+30 sec</button>
        <button onClick={onTogglePause}>{paused ? "Resume" : "Pause"}</button>
      </div>

      {previousSet.tracking === "weight-reps" ? (
        <button className="secondary-action" onClick={onAddExtra} type="button">
          Add another {previousSet.exercise} set
        </button>
      ) : null}

      <button className="action-slab" onClick={onBegin}>
        {restSeconds === 0 ? "Start next step" : "Skip rest"}
        <span>{formatStepTarget(currentSet)}</span>
      </button>
    </div>
  );
}

function SetRail({
  session,
  executions,
  onEdit,
}: {
  session: WorkoutSession;
  executions: ExecutionRecord[];
  onEdit: (record: ExecutionRecord) => void;
}) {
  return (
    <aside className="set-rail">
      <div className="rail-heading">
        <span>PLAN + ACTUAL SESSION QUEUE</span>
        <strong>{session.activeIndex + 1}/{executions.length}</strong>
      </div>
      <ol>
        {executions.map((record, index) => {
          const set = record.step;
          const state = statusLabel(record, index, session.activeIndex);
          const deviation =
            record.source === "extra"
              ? "Extra"
              : record.deferred
                ? "Deferred"
                : executionIsModified(record) && record.status === "completed"
                  ? "Modified"
                  : null;
          return (
            <li
              key={record.id}
              className={`${record.status} ${index === session.activeIndex ? "current" : ""}`}
            >
              <span className="rail-index">
                {record.plannedPosition === null
                  ? "+"
                  : String(record.plannedPosition).padStart(2, "0")}
              </span>
              <div>
                <strong>{set.exercise}</strong>
                <small>{set.setType} · {formatStepTarget(set)}</small>
                {deviation ? <em>{deviation}</em> : null}
              </div>
              {record.status === "pending" ? (
                <b>{state}</b>
              ) : (
                <button
                  className="rail-edit"
                  onClick={() => onEdit(record)}
                  type="button"
                >
                  Edit {state}
                </button>
              )}
            </li>
          );
        })}
      </ol>
    </aside>
  );
}

function ExecutionLedger({
  executions,
}: {
  executions: ExecutionRecord[];
}) {
  return (
    <section className="execution-ledger" aria-label="Planned and actual execution ledger">
      <div className="ledger-heading">
        <div>
          <span className="section-code">PLAN / ACTUAL LEDGER</span>
          <h2>What the session asked for—and what happened.</h2>
        </div>
        <span>{executions.length} entries</span>
      </div>
      <ol>
        {executions.map((record, index) => {
          const status =
            record.status === "skipped"
              ? "Skipped"
              : record.source === "extra"
                ? "Extra"
                : record.deferred
                  ? "Deferred"
                  : executionIsModified(record)
                    ? "Modified"
                    : "As planned";
          return (
            <li key={record.id}>
              <div className="ledger-position">
                <span>PLAN</span>
                <strong>
                  {record.plannedPosition === null
                    ? "—"
                    : String(record.plannedPosition).padStart(2, "0")}
                </strong>
                <small>Actual {record.performedPosition ?? index + 1}</small>
              </div>
              <div className="ledger-result">
                <div>
                  <strong>{record.step.exercise}</strong>
                  <span className={`ledger-status ${status.toLowerCase().replace(" ", "-")}`}>
                    {status}
                  </span>
                </div>
                <p>
                  <span>Planned</span>
                  {formatStepTarget(record.step)}
                </p>
                <p>
                  <span>Actual</span>
                  {record.status === "skipped"
                    ? "Skipped"
                    : recordSummary(record.step, record)}
                </p>
              </div>
              <div className="ledger-rest">
                <span>REST AFTER</span>
                <strong>
                  {record.actualRestSeconds === null
                    ? "—"
                    : formatClock(record.actualRestSeconds)}
                </strong>
                <small>
                  Plan {formatClock(record.authoredRestSeconds)}
                  {record.adjustedRestSeconds !== record.authoredRestSeconds
                    ? ` · target ${formatClock(record.adjustedRestSeconds)}`
                    : ""}
                </small>
              </div>
            </li>
          );
        })}
      </ol>
    </section>
  );
}

function Metric({
  label,
  value,
  provenance,
}: {
  label: string;
  value: string;
  provenance: string;
}) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{provenance}</small>
    </div>
  );
}
