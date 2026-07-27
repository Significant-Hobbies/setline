"use client";

/*
THESIS: Setline is a daylight attempt board for executing a known workout, not a fitness dashboard.
OWN-WORLD: Chalk field, navy rules, safety-lime action slabs, blue recorded data, and condensed tabular numerals.
STORY: See today's plan, execute one set, trust the rest deadline, then retain an honest local record.
FIRST VIEWPORT: Today's Upper A fills the screen with session facts and one unmistakable Start workout action.
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
  emptyStoredState,
  parseStoredStateJson,
  PENDING_SYNC_KEY,
  STORAGE_KEY,
  updateStoredState,
  type HistoryEntry,
  type SetRecord,
  type StoredState,
  type WorkoutSession,
} from "./lib/workout-state";

type View = "today" | "programme" | "history" | "progress";
type SetType = "Warm-up" | "Working";

type PlannedSet = {
  id: string;
  exercise: string;
  setType: SetType;
  setLabel: string;
  targetWeight: number;
  targetReps: number;
  restSeconds: number;
  targetRpe?: number;
  cue: string;
  previous: string;
};

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

type SyncStatus = "local" | "syncing" | "synced" | "offline" | "error";

const workoutSets: PlannedSet[] = [
  {
    id: "bench-warmup-1",
    exercise: "Bench press",
    setType: "Warm-up",
    setLabel: "Warm-up 1 of 3",
    targetWeight: 20,
    targetReps: 15,
    restSeconds: 45,
    cue: "Set shoulder blades. Smooth, even bar path.",
    previous: "Sample target · 20 kg × 15",
  },
  {
    id: "bench-warmup-2",
    exercise: "Bench press",
    setType: "Warm-up",
    setLabel: "Warm-up 2 of 3",
    targetWeight: 40,
    targetReps: 10,
    restSeconds: 60,
    cue: "Keep feet planted. Touch the same point.",
    previous: "Sample target · 40 kg × 10",
  },
  {
    id: "bench-warmup-3",
    exercise: "Bench press",
    setType: "Warm-up",
    setLabel: "Warm-up 3 of 3",
    targetWeight: 60,
    targetReps: 3,
    restSeconds: 120,
    cue: "Treat every rep like the working set.",
    previous: "Sample target · 60 kg × 3",
  },
  {
    id: "bench-working-1",
    exercise: "Bench press",
    setType: "Working",
    setLabel: "Working set 1 of 3",
    targetWeight: 70,
    targetReps: 5,
    restSeconds: 180,
    targetRpe: 8,
    cue: "Brace before the unrack. Drive back toward the rack.",
    previous: "Sample previous · 70 kg × 5 @ RPE 8",
  },
  {
    id: "bench-working-2",
    exercise: "Bench press",
    setType: "Working",
    setLabel: "Working set 2 of 3",
    targetWeight: 70,
    targetReps: 5,
    restSeconds: 180,
    targetRpe: 8,
    cue: "Hold tension at the bottom. Finish over the shoulders.",
    previous: "Sample previous · 70 kg × 5 @ RPE 8",
  },
  {
    id: "bench-working-3",
    exercise: "Bench press",
    setType: "Working",
    setLabel: "Working set 3 of 3",
    targetWeight: 70,
    targetReps: 5,
    restSeconds: 180,
    targetRpe: 8,
    cue: "Same setup. Stop if the bar path breaks down.",
    previous: "Sample previous · 70 kg × 5 @ RPE 8.5",
  },
  {
    id: "pulldown-1",
    exercise: "Lat pulldown",
    setType: "Working",
    setLabel: "Working set 1 of 3",
    targetWeight: 55,
    targetReps: 10,
    restSeconds: 90,
    targetRpe: 8,
    cue: "Lead with elbows. Keep ribs stacked.",
    previous: "Sample previous · 55 kg × 10 @ RPE 7.5",
  },
  {
    id: "pulldown-2",
    exercise: "Lat pulldown",
    setType: "Working",
    setLabel: "Working set 2 of 3",
    targetWeight: 55,
    targetReps: 10,
    restSeconds: 90,
    targetRpe: 8,
    cue: "Pause at the bottom without leaning back.",
    previous: "Sample previous · 55 kg × 10 @ RPE 8",
  },
  {
    id: "pulldown-3",
    exercise: "Lat pulldown",
    setType: "Working",
    setLabel: "Working set 3 of 3",
    targetWeight: 55,
    targetReps: 10,
    restSeconds: 90,
    targetRpe: 8,
    cue: "Control the return. Keep the shoulders down.",
    previous: "Sample previous · 55 kg × 9 @ RPE 8.5",
  },
  {
    id: "row-1",
    exercise: "Seated cable row",
    setType: "Working",
    setLabel: "Working set 1 of 3",
    targetWeight: 50,
    targetReps: 12,
    restSeconds: 90,
    targetRpe: 8,
    cue: "Stay tall. Pull toward the lower ribs.",
    previous: "Sample previous · 50 kg × 12 @ RPE 8",
  },
  {
    id: "row-2",
    exercise: "Seated cable row",
    setType: "Working",
    setLabel: "Working set 2 of 3",
    targetWeight: 50,
    targetReps: 12,
    restSeconds: 90,
    targetRpe: 8,
    cue: "Finish with the back, not the wrists.",
    previous: "Sample previous · 50 kg × 12 @ RPE 8",
  },
  {
    id: "row-3",
    exercise: "Seated cable row",
    setType: "Working",
    setLabel: "Working set 3 of 3",
    targetWeight: 50,
    targetReps: 12,
    restSeconds: 0,
    targetRpe: 8,
    cue: "Keep the final rep as controlled as the first.",
    previous: "Sample previous · 50 kg × 11 @ RPE 8.5",
  },
];

const schedule = [
  { day: "MON", name: "Upper A", time: "19:00", state: "Today" },
  { day: "TUE", name: "Lower A", time: "19:00", state: "Next" },
  { day: "THU", name: "Upper B", time: "19:00", state: "Planned" },
  { day: "SAT", name: "Lower B", time: "11:00", state: "Planned" },
];

const sampleTrend = [
  { label: "06 Jul", weight: 65, reps: 5 },
  { label: "13 Jul", weight: 67.5, reps: 5 },
  { label: "20 Jul", weight: 70, reps: 5 },
  { label: "Today", weight: 70, reps: 5 },
];

function makeSession(): WorkoutSession {
  return {
    id: `session-${Date.now()}`,
    startedAt: Date.now(),
    completedAt: null,
    phase: "active",
    activeIndex: 0,
    restEndsAt: null,
    pausedRestSeconds: null,
    plannedRestSeconds: 0,
    records: workoutSets.map((set) => ({
      setId: set.id,
      status: "pending",
      actualWeight: set.targetWeight,
      actualReps: set.targetReps,
      actualRpe: null,
      completedAt: null,
    })),
    quality: null,
  };
}

function formatClock(totalSeconds: number) {
  const safeSeconds = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function formatDuration(totalSeconds: number) {
  const minutes = Math.max(1, Math.round(totalSeconds / 60));
  return `${minutes} min`;
}

function getSessionMetrics(session: WorkoutSession) {
  let workingVolume = 0;
  let warmupVolume = 0;
  const rpes: number[] = [];

  session.records.forEach((record, index) => {
    if (record.status !== "completed") return;
    const planned = workoutSets[index];
    const volume = record.actualWeight * record.actualReps;
    if (planned.setType === "Warm-up") warmupVolume += volume;
    else workingVolume += volume;
    if (record.actualRpe !== null) rpes.push(record.actualRpe);
  });

  return {
    completedSets: session.records.filter((record) => record.status === "completed").length,
    skippedSets: session.records.filter((record) => record.status === "skipped").length,
    workingVolume,
    warmupVolume,
    averageRpe: rpes.length
      ? rpes.reduce((total, rpe) => total + rpe, 0) / rpes.length
      : null,
  };
}

function statusLabel(record: SetRecord, index: number, activeIndex: number) {
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
    const onVisibility = () => setNow(Date.now());
    const onInstallPrompt = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPromptEvent);
    };

    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("beforeinstallprompt", onInstallPrompt);

    queueMicrotask(() => {
      setNow(Date.now());
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
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [session]);

  const currentSet = session ? workoutSets[session.activeIndex] : null;
  const currentRecord = session ? session.records[session.activeIndex] : null;
  const metrics = useMemo(() => (session ? getSessionMetrics(session) : null), [session]);
  const elapsedSeconds = session && now ? Math.max(0, (now - session.startedAt) / 1000) : 0;
  const restSeconds =
    session?.phase === "rest"
      ? session.pausedRestSeconds ??
        Math.max(0, Math.ceil(((session.restEndsAt ?? now) - now) / 1000))
      : 0;
  const currentValuesValid = Boolean(
    currentRecord &&
      Number.isFinite(currentRecord.actualWeight) &&
      currentRecord.actualWeight > 0 &&
      Number.isFinite(currentRecord.actualReps) &&
      currentRecord.actualReps > 0,
  );

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

  const startWorkout = () => {
    setSession((existing) => existing ?? makeSession());
    setNotice(
      accountState?.status === "authenticated"
        ? "Upper A started. Progress saves on this device first, then syncs."
        : "Upper A started. Progress is saved on this device.",
    );
    setNow(Date.now());
    requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: "auto" }));
  };

  const updateCurrentRecord = (patch: Partial<SetRecord>) => {
    setSession((existing) => {
      if (!existing) return existing;
      return {
        ...existing,
        records: existing.records.map((record, index) =>
          index === existing.activeIndex ? { ...record, ...patch } : record,
        ),
      };
    });
  };

  const completeSet = () => {
    if (!session || !currentSet || !currentRecord) return;
    const completedAt = Date.now();
    const isFinal = session.activeIndex === workoutSets.length - 1;
    const nextIndex = Math.min(session.activeIndex + 1, workoutSets.length - 1);

    setSession({
      ...session,
      completedAt: isFinal ? completedAt : null,
      phase: isFinal ? "summary" : "rest",
      activeIndex: nextIndex,
      restEndsAt: isFinal ? null : completedAt + currentSet.restSeconds * 1000,
      pausedRestSeconds: null,
      plannedRestSeconds: currentSet.restSeconds,
      records: session.records.map((record, index) =>
        index === session.activeIndex
          ? { ...record, status: "completed", completedAt }
          : record,
      ),
    });
    setNow(completedAt);
    setNotice(
      isFinal
        ? "Final set recorded. Review your session."
        : `${currentSet.exercise} recorded. Rest started.`,
    );
    navigator.vibrate?.(isFinal ? [80, 40, 80] : 60);
  };

  const skipSet = () => {
    if (!session || !currentSet) return;
    const completedAt = Date.now();
    const isFinal = session.activeIndex === workoutSets.length - 1;
    setSession({
      ...session,
      completedAt: isFinal ? completedAt : null,
      phase: isFinal ? "summary" : "active",
      activeIndex: Math.min(session.activeIndex + 1, workoutSets.length - 1),
      restEndsAt: null,
      pausedRestSeconds: null,
      records: session.records.map((record, index) =>
        index === session.activeIndex
          ? { ...record, status: "skipped", completedAt }
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
        };
      }
      return {
        ...existing,
        restEndsAt: Math.max(existing.restEndsAt ?? Date.now(), Date.now()) + seconds * 1000,
      };
    });
  };

  const toggleRestPause = () => {
    setSession((existing) => {
      if (!existing || existing.phase !== "rest") return existing;
      if (existing.pausedRestSeconds !== null) {
        return {
          ...existing,
          restEndsAt: Date.now() + existing.pausedRestSeconds * 1000,
          pausedRestSeconds: null,
        };
      }
      return {
        ...existing,
        restEndsAt: null,
        pausedRestSeconds: Math.max(
          0,
          Math.ceil(((existing.restEndsAt ?? Date.now()) - Date.now()) / 1000),
        ),
      };
    });
  };

  const beginNextSet = () => {
    setSession((existing) =>
      existing
        ? {
            ...existing,
            phase: "active",
            restEndsAt: null,
            pausedRestSeconds: null,
          }
        : existing,
    );
    setNotice("Next set ready.");
  };

  const undoLastSet = () => {
    if (!session) return;
    const index =
      session.phase === "summary"
        ? session.activeIndex
        : Math.max(0, session.activeIndex - 1);
    const planned = workoutSets[index];
    setSession({
      ...session,
      completedAt: null,
      phase: "active",
      activeIndex: index,
      restEndsAt: null,
      pausedRestSeconds: null,
      plannedRestSeconds: 0,
      records: session.records.map((record, recordIndex) =>
        recordIndex === index
          ? { ...record, status: "pending", completedAt: null }
          : record,
      ),
    });
    setNotice(`${planned.exercise} reopened for correction.`);
    requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: "auto" }));
  };

  const saveWorkout = () => {
    if (!session || !metrics) return;
    const completedAt = session.completedAt ?? Date.now();
    const entry: HistoryEntry = {
      id: session.id,
      completedAt,
      durationSeconds: Math.max(60, (completedAt - session.startedAt) / 1000),
      completedSets: metrics.completedSets,
      skippedSets: metrics.skippedSets,
      workingVolume: metrics.workingVolume,
      warmupVolume: metrics.warmupVolume,
      averageRpe: metrics.averageRpe,
      quality: session.quality,
    };
    setHistory((entries) => [entry, ...entries]);
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
        <div className="session-bar">
          <button className="text-button" onClick={discardSession}>
            End session
          </button>
          <div>
            <span className="session-kicker">Upper A · Sample programme</span>
            <strong>{session.phase === "summary" ? "Session review" : "Workout in progress"}</strong>
          </div>
          <div className="session-clock" aria-label={`Elapsed time ${formatClock(elapsedSeconds)}`}>
            <span>ELAPSED</span>
            <strong>{formatClock(elapsedSeconds)}</strong>
          </div>
        </div>

        <div className="workout-progress" aria-label={`${metrics?.completedSets ?? 0} of ${workoutSets.length} sets completed`}>
          <span
            style={{
              transform: `scaleX(${(metrics?.completedSets ?? 0) / workoutSets.length})`,
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
                <h1>Upper A is on the record.</h1>
              </div>
              <span className="quality-stamp">
                {accountState.status === "authenticated" ? "SYNC" : "LOCAL"}
              </span>
            </div>

            <div className="summary-lead">
              <strong>{formatDuration(elapsedSeconds)}</strong>
              <span>Planned 60 min</span>
            </div>

            <div className="metric-grid">
              <Metric label="Completed" value={`${metrics.completedSets}/${workoutSets.length}`} provenance="Recorded" />
              <Metric label="Skipped" value={String(metrics.skippedSets)} provenance="Recorded" />
              <Metric label="Working volume" value={`${metrics.workingVolume.toLocaleString()} kg`} provenance="Calculated" />
              <Metric label="Warm-up volume" value={`${metrics.warmupVolume.toLocaleString()} kg`} provenance="Calculated" />
              <Metric
                label="Average RPE"
                value={metrics.averageRpe === null ? "—" : metrics.averageRpe.toFixed(1)}
                provenance="Calculated from recorded RPE"
              />
              <Metric label="Active set time" value="—" provenance="Unavailable in simple mode" />
            </div>

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
              Reopen final set
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
              {session.phase === "rest" && currentSet ? (
                <RestBoard
                  session={session}
                  currentSet={currentSet}
                  previousSet={workoutSets[Math.max(0, session.activeIndex - 1)]}
                  previousRecord={session.records[Math.max(0, session.activeIndex - 1)]}
                  restSeconds={restSeconds}
                  onAddRest={addRest}
                  onTogglePause={toggleRestPause}
                  onBegin={beginNextSet}
                  onUndo={undoLastSet}
                />
              ) : currentSet && currentRecord ? (
                <>
                  {session.activeIndex > 0 &&
                  session.records[session.activeIndex - 1]?.status === "skipped" ? (
                    <div className="undo-strip">
                      <span>Previous set skipped</span>
                      <button onClick={undoLastSet}>Undo skip</button>
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
                    <div className="target-notation">
                      <strong>{currentSet.targetWeight}</strong>
                      <small>KG</small>
                      <b>×</b>
                      <strong>{currentSet.targetReps}</strong>
                    </div>
                    <div className="target-meta">
                      <span>Rest after set {formatClock(currentSet.restSeconds)}</span>
                      <span>Target RPE {currentSet.targetRpe ?? "—"}</span>
                    </div>
                  </div>

                  <div className="previous-strip">
                    <span>PREVIOUS</span>
                    <strong>{currentSet.previous}</strong>
                  </div>

                  <div className="cue-strip">
                    <span>FORM CUE</span>
                    <p>{currentSet.cue}</p>
                  </div>

                  <fieldset className="actuals-fieldset">
                    <legend>Actual result</legend>
                    <label>
                      <span>Weight</span>
                      <div className="numeric-input">
                        <button
                          type="button"
                          aria-label="Decrease weight by 2.5 kilograms"
                          onClick={() =>
                            updateCurrentRecord({
                              actualWeight: Math.max(0, currentRecord.actualWeight - 2.5),
                            })
                          }
                        >
                          −
                        </button>
                        <input
                          aria-label="Actual weight in kilograms"
                          inputMode="decimal"
                          min="0"
                          step="0.5"
                          type="number"
                          value={currentRecord.actualWeight}
                          onChange={(event) =>
                            updateCurrentRecord({
                              actualWeight: Number(event.target.value),
                            })
                          }
                        />
                        <b>kg</b>
                        <button
                          type="button"
                          aria-label="Increase weight by 2.5 kilograms"
                          onClick={() =>
                            updateCurrentRecord({
                              actualWeight: currentRecord.actualWeight + 2.5,
                            })
                          }
                        >
                          +
                        </button>
                      </div>
                    </label>
                    <label>
                      <span>Reps</span>
                      <div className="numeric-input">
                        <button
                          type="button"
                          aria-label="Decrease repetitions by one"
                          onClick={() =>
                            updateCurrentRecord({
                              actualReps: Math.max(0, currentRecord.actualReps - 1),
                            })
                          }
                        >
                          −
                        </button>
                        <input
                          aria-label="Completed repetitions"
                          inputMode="numeric"
                          min="0"
                          step="1"
                          type="number"
                          value={currentRecord.actualReps}
                          onChange={(event) =>
                            updateCurrentRecord({
                              actualReps: Number(event.target.value),
                            })
                          }
                        />
                        <b>reps</b>
                        <button
                          type="button"
                          aria-label="Increase repetitions by one"
                          onClick={() =>
                            updateCurrentRecord({
                              actualReps: currentRecord.actualReps + 1,
                            })
                          }
                        >
                          +
                        </button>
                      </div>
                    </label>
                    <label>
                      <span>RPE optional</span>
                      <select
                        aria-label="Actual RPE"
                        value={currentRecord.actualRpe ?? ""}
                        onChange={(event) =>
                          updateCurrentRecord({
                            actualRpe: event.target.value
                              ? Number(event.target.value)
                              : null,
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
                  </fieldset>
                  {!currentValuesValid ? (
                    <p className="input-error" role="alert">
                      Enter a weight and at least one completed repetition.
                    </p>
                  ) : null}

                  <div className="attempt-actions">
                    <button
                      className="action-slab"
                      disabled={!currentValuesValid}
                      onClick={completeSet}
                    >
                      Complete set
                      <span>Starts {formatClock(currentSet.restSeconds)} rest</span>
                    </button>
                    <button className="secondary-action" onClick={skipSet}>
                      Skip this set
                    </button>
                  </div>
                </>
              ) : null}
            </section>

            <SetRail session={session} />
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
          onStart={startWorkout}
          onViewProgramme={() => navigate("programme")}
        />
      ) : null}
      {view === "programme" ? (
        <ProgrammeView
          accountState={accountState}
          onClear={clearLocalData}
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
  onStart,
  onViewProgramme,
}: {
  accountState: Exclude<AccountState, { status: "anonymous" }>;
  onStart: () => void;
  onViewProgramme: () => void;
}) {
  return (
    <div className="page-view today-view">
      <section className="today-intro">
        <div>
          <span className="section-code">WEEK 03 · SAMPLE PROGRAMME</span>
          <h1>Upper A is set.</h1>
          <p>Follow the plan. Record the work. Leave the decisions outside the gym.</p>
        </div>
        <div className="adherence-stamp">
          <strong>12</strong>
          <span>sets ready</span>
        </div>
      </section>

      <section className="today-workout">
        <div className="workout-title">
          <div>
            <span className="day-chip">TODAY · 19:00</span>
            <h2>Upper A</h2>
          </div>
          <span className="sample-badge">SAMPLE</span>
        </div>

        <button className="action-slab start-action" onClick={onStart}>
          Start workout
          <span>Opens with bench press warm-up</span>
        </button>

        <div className="workout-facts">
          <Metric label="Planned" value="60 min" provenance="Programme" />
          <Metric label="Exercises" value="3" provenance="Programme" />
          <Metric label="Sets" value="12" provenance="3 warm-up · 9 working" />
          <Metric label="Next target" value="20 kg × 15" provenance="Bench press warm-up" />
        </div>

        <ol className="exercise-preview">
          <li>
            <span>01</span>
            <div>
              <strong>Bench press</strong>
              <small>3 warm-up · 3 working</small>
            </div>
            <b>70 × 5</b>
          </li>
          <li>
            <span>02</span>
            <div>
              <strong>Lat pulldown</strong>
              <small>3 working sets</small>
            </div>
            <b>55 × 10</b>
          </li>
          <li>
            <span>03</span>
            <div>
              <strong>Seated cable row</strong>
              <small>3 working sets</small>
            </div>
            <b>50 × 12</b>
          </li>
        </ol>

      </section>

      <section className="week-strip">
        <div className="section-heading">
          <div>
            <span className="section-code">THIS WEEK</span>
            <h2>Four sessions. No guesswork.</h2>
          </div>
          <button className="text-button" onClick={onViewProgramme}>
            View programme
          </button>
        </div>
        <div className="schedule-grid">
          {schedule.map((item) => (
            <div className={item.state === "Today" ? "schedule-day active" : "schedule-day"} key={item.day}>
              <span>{item.day}</span>
              <strong>{item.name}</strong>
              <small>{item.time}</small>
              <b>{item.state}</b>
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
}: {
  accountState: Exclude<AccountState, { status: "anonymous" }>;
  onClear: () => void;
}) {
  return (
    <div className="page-view programme-view">
      <section className="page-heading">
        <span className="section-code">SAMPLE PROGRAMME</span>
        <h1>Four days, explicitly planned.</h1>
        <p>This first release proves execution. Programme editing and JSON import arrive in the next phase.</p>
      </section>

      <div className="programme-layout">
        <section className="programme-schedule">
          {schedule.map((item, index) => (
            <article key={item.day} className="programme-day">
              <div className="programme-index">{String(index + 1).padStart(2, "0")}</div>
              <div>
                <span>{item.day} · {item.time}</span>
                <h2>{item.name}</h2>
                <p>{index % 2 === 0 ? "Bench press · Pull · Row" : "Squat · Hinge · Carry"}</p>
              </div>
              <strong>{index % 2 === 0 ? "60 min" : "65 min"}</strong>
            </article>
          ))}
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
            <article key={entry.id} className="history-row">
              <div className="history-date">
                <strong>
                  {new Intl.DateTimeFormat("en", { day: "2-digit", month: "short" })
                    .format(new Date(entry.completedAt))
                    .toUpperCase()}
                </strong>
                <span>RECORDED</span>
              </div>
              <div>
                <h2>Upper A</h2>
                <p>
                  {entry.completedSets} completed · {entry.skippedSets} skipped · quality{" "}
                  {entry.quality === null ? "not recorded" : `${entry.quality}/5`}
                </p>
              </div>
              <div className="history-volume">
                <strong>{entry.workingVolume.toLocaleString()} kg</strong>
                <span>Calculated working volume</span>
              </div>
              <strong className="history-duration">{formatDuration(entry.durationSeconds)}</strong>
            </article>
          ))}
        </div>
      ) : (
        <section className="empty-history">
          <div className="empty-mark">0</div>
          <div>
            <h2>No recorded workouts yet.</h2>
            <p>Complete Upper A and save the summary. Your first device-local entry will appear here.</p>
          </div>
        </section>
      )}

      <section className="sample-history">
        <div className="section-heading">
          <div>
            <span className="section-code">SAMPLE REFERENCE</span>
            <h2>What a history row will contain.</h2>
          </div>
          <span className="sample-badge">NOT RECORDED</span>
        </div>
        <div className="sample-history-grid">
          <Metric label="Session" value="Upper A" provenance="Sample" />
          <Metric label="Duration" value="58 min" provenance="Sample" />
          <Metric label="Completed" value="12/12" provenance="Sample" />
          <Metric label="Working volume" value="5,550 kg" provenance="Sample calculation" />
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
        <span className="section-code">BENCH PRESS · SAMPLE TREND</span>
        <h1>Progress keeps its ingredients visible.</h1>
        <p>Weight, repetitions, RPE, and volume remain separate. Setline does not collapse them into a mystery score.</p>
      </section>

      <section className="progress-board">
        <div className="progress-heading">
          <div>
            <span>WORKING WEIGHT</span>
            <strong>70 <small>kg</small></strong>
          </div>
          <div className="delta-stamp">
            <strong>+7.7%</strong>
            <span>Sample · 4 weeks</span>
          </div>
        </div>

        <div className="bar-chart" role="img" aria-label="Sample bench press working weight rose from 65 to 70 kilograms across four weeks">
          {sampleTrend.map((point) => (
            <div className="bar-column" key={point.label}>
              <span>{point.weight} kg</span>
              <div style={{ height: `${(point.weight / 75) * 100}%` }} />
              <small>{point.label}</small>
            </div>
          ))}
        </div>

        <div className="progress-metrics">
          <Metric label="Latest reps" value="5" provenance="Sample" />
          <Metric label="Latest RPE" value="8.0" provenance="Sample" />
          <Metric label="Estimated 1RM" value="81.7 kg" provenance="Calculated · Epley" />
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

function RestBoard({
  session,
  currentSet,
  previousSet,
  previousRecord,
  restSeconds,
  onAddRest,
  onTogglePause,
  onBegin,
  onUndo,
}: {
  session: WorkoutSession;
  currentSet: PlannedSet;
  previousSet: PlannedSet;
  previousRecord: SetRecord;
  restSeconds: number;
  onAddRest: (seconds: number) => void;
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
        <small>Planned {formatClock(session.plannedRestSeconds)}</small>
      </div>

      <div className={restSeconds <= 10 ? "rest-progress warning" : "rest-progress"} aria-hidden="true">
        <span
          style={{
            transform: `scaleX(${Math.min(
              1,
              session.plannedRestSeconds
                ? restSeconds / session.plannedRestSeconds
                : 0,
            )})`,
          }}
        />
      </div>

      <div className="completed-receipt">
        <span>JUST RECORDED</span>
        <strong>{previousSet.exercise}</strong>
        <p>
          {previousRecord.actualWeight} kg × {previousRecord.actualReps}
          {previousRecord.actualRpe ? ` @ RPE ${previousRecord.actualRpe}` : ""}
        </p>
        <button onClick={onUndo}>Undo recorded set</button>
      </div>

      <p className="sr-only" role="status" aria-live="assertive">
        {restSeconds === 0
          ? `Rest complete. Next: ${currentSet.targetWeight} kilograms by ${currentSet.targetReps} repetitions.`
          : ""}
      </p>

      <div className="next-attempt">
        <span>NEXT</span>
        <div>
          <strong>{currentSet.exercise}</strong>
          <small>{currentSet.setLabel}</small>
        </div>
        <b>{currentSet.targetWeight} KG × {currentSet.targetReps}</b>
      </div>

      <div className="timer-controls">
        <button onClick={() => onAddRest(15)}>+15 sec</button>
        <button onClick={() => onAddRest(30)}>+30 sec</button>
        <button onClick={onTogglePause}>{paused ? "Resume" : "Pause"}</button>
      </div>

      <button className="action-slab" onClick={onBegin}>
        {restSeconds === 0 ? "Start next set" : "Skip rest"}
        <span>{currentSet.targetWeight} kg × {currentSet.targetReps}</span>
      </button>
    </div>
  );
}

function SetRail({ session }: { session: WorkoutSession }) {
  return (
    <aside className="set-rail">
      <div className="rail-heading">
        <span>ORDER LOCKED · SESSION PLAN</span>
        <strong>{session.activeIndex + 1}/{workoutSets.length}</strong>
      </div>
      <ol>
        {workoutSets.map((set, index) => {
          const record = session.records[index];
          const state = statusLabel(record, index, session.activeIndex);
          return (
            <li
              key={set.id}
              className={`${record.status} ${index === session.activeIndex ? "current" : ""}`}
            >
              <span className="rail-index">{String(index + 1).padStart(2, "0")}</span>
              <div>
                <strong>{set.exercise}</strong>
                <small>{set.setType} · {set.targetWeight} kg × {set.targetReps}</small>
              </div>
              <b>{state}</b>
            </li>
          );
        })}
      </ol>
    </aside>
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
