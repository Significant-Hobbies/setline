"use client";

import { useEffect, useRef, useState } from "react";

import {
  copyProgrammeWeekForward,
  isCustomProgramme,
  isMondayIsoDate,
  MAX_CUSTOM_PROGRAMME_NAME_LENGTH,
  MAX_CUSTOM_PROGRAMME_WEEKS,
  mondayIsoForLocalDate,
  mondayIsoForIsoDate,
  type CustomProgramme,
} from "../lib/custom-programme";
import type { CustomWorkoutTemplate } from "../lib/custom-workouts";
import type { CustomWorkoutId } from "../lib/programme";

type Props = {
  authoringLocked?: boolean;
  customWorkouts: CustomWorkoutTemplate[];
  programme: CustomProgramme | null;
  onDelete: () => void;
  onEditingChange: (editing: boolean) => void;
  onSave: (programme: CustomProgramme) => void;
};

const DAY_LABELS = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
] as const;

function newProgramme(now = Date.now()): CustomProgramme {
  return {
    name: "",
    startsOn: mondayIsoForLocalDate(new Date(now)),
    weekCount: 4,
    enabled: true,
    assignments: [],
    createdAt: now,
    updatedAt: now,
  };
}

export function CustomProgrammePlanner({
  authoringLocked = false,
  customWorkouts,
  programme,
  onDelete,
  onEditingChange,
  onSave,
}: Props) {
  const [draft, setDraft] = useState<CustomProgramme | null>(null);
  const [activeWeek, setActiveWeek] = useState(1);
  const [error, setError] = useState("");
  const [receipt, setReceipt] = useState("");
  const nameInputRef = useRef<HTMLInputElement>(null);
  const startDateInputRef = useRef<HTMLInputElement>(null);
  const createButtonRef = useRef<HTMLButtonElement>(null);
  const editButtonRef = useRef<HTMLButtonElement>(null);
  const pendingSaveFocusRef = useRef(false);
  const editing = draft !== null;
  const draftCreatedAt = draft?.createdAt;

  useEffect(() => {
    onEditingChange(editing);
  }, [editing, onEditingChange]);

  useEffect(
    () => () => {
      onEditingChange(false);
    },
    [onEditingChange],
  );

  useEffect(() => {
    if (draftCreatedAt !== undefined) nameInputRef.current?.focus();
  }, [draftCreatedAt]);

  useEffect(() => {
    if (!programme || !pendingSaveFocusRef.current) return;
    pendingSaveFocusRef.current = false;
    requestAnimationFrame(() => editButtonRef.current?.focus());
  }, [programme]);

  useEffect(() => {
    if (!draft) return;
    const preventUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", preventUnload);
    return () => window.removeEventListener("beforeunload", preventUnload);
  }, [draft]);

  const closeEditor = () => {
    const returnTarget = programme ? editButtonRef : createButtonRef;
    setDraft(null);
    requestAnimationFrame(() => returnTarget.current?.focus());
  };

  const beginCreate = () => {
    if (authoringLocked) return;
    if (!customWorkouts.length) {
      setError("Create at least one custom workout before writing a programme.");
      return;
    }
    setError("");
    setReceipt("");
    setActiveWeek(1);
    setDraft(newProgramme());
  };

  const beginEdit = () => {
    if (!programme || authoringLocked) return;
    if (
      draft &&
      !window.confirm("Discard the current unsaved programme draft and reopen the saved copy?")
    ) {
      return;
    }
    setError("");
    setReceipt("");
    setActiveWeek(1);
    setDraft(structuredClone(programme));
  };

  const cancelEditing = () => {
    if (!window.confirm("Discard this unsaved programme draft?")) return;
    closeEditor();
  };

  const updateWeekCount = (weekCount: number) => {
    if (
      !draft ||
      !Number.isInteger(weekCount) ||
      weekCount < 1 ||
      weekCount > MAX_CUSTOM_PROGRAMME_WEEKS
    ) {
      return;
    }
    const removedAssignments = draft.assignments.filter(
      (assignment) => assignment.weekNumber > weekCount,
    );
    if (
      removedAssignments.length &&
      !window.confirm(
        `Reducing this programme removes ${removedAssignments.length} assignment${
          removedAssignments.length === 1 ? "" : "s"
        }. Continue?`,
      )
    ) {
      return;
    }
    setDraft({
      ...draft,
      weekCount,
      assignments: draft.assignments.filter(
        (assignment) => assignment.weekNumber <= weekCount,
      ),
    });
    setActiveWeek((current) => Math.min(current, weekCount));
  };

  const setAssignment = (
    weekNumber: number,
    dayIndex: number,
    workoutId: string,
  ) => {
    setDraft((current) => {
      if (!current) return current;
      const assignments = current.assignments.filter(
        (assignment) =>
          assignment.weekNumber !== weekNumber ||
          assignment.dayIndex !== dayIndex,
      );
      return {
        ...current,
        assignments: workoutId
          ? [
              ...assignments,
              {
                weekNumber,
                dayIndex,
                workoutId: workoutId as CustomWorkoutId,
              },
            ]
          : assignments,
      };
    });
  };

  const copyWeekForward = (weekNumber: number) => {
    if (!draft || weekNumber >= draft.weekCount) return;
    const laterCount = draft.assignments.filter(
      (assignment) => assignment.weekNumber > weekNumber,
    ).length;
    if (
      laterCount &&
      !window.confirm(
        `Copy Week ${weekNumber} forward and replace ${laterCount} later assignment${
          laterCount === 1 ? "" : "s"
        }?`,
      )
    ) {
      return;
    }
    setDraft({
      ...draft,
      assignments: copyProgrammeWeekForward(
        draft.assignments,
        weekNumber,
        draft.weekCount,
      ),
    });
    setReceipt(`Week ${weekNumber} copied through Week ${draft.weekCount}.`);
  };

  const saveDraft = () => {
    if (!draft) return;
    if (!isMondayIsoDate(draft.startsOn)) {
      setError("Choose a Monday start date before saving this programme.");
      startDateInputRef.current?.focus();
      return;
    }
    const candidate: CustomProgramme = {
      ...draft,
      name: draft.name.trim(),
      updatedAt: Date.now(),
    };
    if (
      !isCustomProgramme(
        candidate,
        new Set(customWorkouts.map((workout) => workout.id)),
      )
    ) {
      setError(
        "Check the programme name, Monday start date, duration, and workout assignments.",
      );
      return;
    }
    pendingSaveFocusRef.current = true;
    onSave(candidate);
    setDraft(null);
    setError("");
    setReceipt(`${candidate.name} saved with ${candidate.assignments.length} assignments.`);
  };

  const deleteProgramme = () => {
    if (
      !programme ||
      authoringLocked ||
      !window.confirm(
        `Delete ${programme.name}? Custom workouts and recorded sessions will be kept.`,
      )
    ) {
      return;
    }
    onDelete();
    setDraft(null);
    setReceipt(`${programme.name} deleted. Custom workouts and records were kept.`);
    requestAnimationFrame(() => createButtonRef.current?.focus());
  };

  return (
    <section
      className="custom-programme"
      aria-labelledby="custom-programme-heading"
    >
      <div className="custom-programme-heading">
        <div>
          <span className="section-code">YOUR PROGRAMME</span>
          <h2 id="custom-programme-heading">Place each workout on the calendar.</h2>
          <p>
            One explicit Monday-based block. Empty days stay unplanned; Setline
            never generates or progresses the work for you.
          </p>
        </div>
        {!programme && !draft ? (
          <button
            ref={createButtonRef}
            type="button"
            disabled={authoringLocked}
            onClick={beginCreate}
          >
            New programme
          </button>
        ) : null}
      </div>

      {receipt ? (
        <p className="custom-programme-receipt" role="status">
          {receipt}
        </p>
      ) : null}
      {error ? (
        <p className="custom-programme-error" role="alert">
          {error}
        </p>
      ) : null}
      {authoringLocked ? (
        <p className="custom-programme-lock" role="status">
          Finish or discard the custom workout draft before editing the programme.
        </p>
      ) : null}

      {!customWorkouts.length && !draft ? (
        <p className="custom-programme-empty">
          Create a custom workout above before assigning a programme day.
        </p>
      ) : null}

      {programme && !draft ? (
        <article className="custom-programme-summary">
          <div>
            <span className={programme.enabled ? "status-chip" : "status-chip paused"}>
              {programme.enabled ? "Enabled" : "Paused"}
            </span>
            <h3>{programme.name}</h3>
            <p>
              Starts {programme.startsOn} · {programme.weekCount} week
              {programme.weekCount === 1 ? "" : "s"} ·{" "}
              {programme.assignments.length} assignment
              {programme.assignments.length === 1 ? "" : "s"}
            </p>
          </div>
          <div>
            <button
              ref={editButtonRef}
              type="button"
              disabled={authoringLocked}
              onClick={beginEdit}
            >
              Edit programme
            </button>
            <button
              type="button"
              disabled={authoringLocked}
              onClick={deleteProgramme}
            >
              Delete
            </button>
          </div>
        </article>
      ) : null}

      {draft ? (
        <form
          className="custom-programme-editor"
          onSubmit={(event) => {
            event.preventDefault();
            saveDraft();
          }}
        >
          <div className="custom-programme-editor-heading">
            <div>
              <span className="section-code">PROGRAMME AUTHORING</span>
              <h3>{programme ? "Edit programme" : "New programme"}</h3>
            </div>
            <button type="button" onClick={cancelEditing}>
              Cancel
            </button>
          </div>

          <div className="custom-programme-fields">
            <label>
              <span>Programme name</span>
              <input
                ref={nameInputRef}
                required
                maxLength={MAX_CUSTOM_PROGRAMME_NAME_LENGTH}
                value={draft.name}
                placeholder="e.g. Four-week strength block"
                onChange={(event) =>
                  setDraft((current) =>
                    current ? { ...current, name: event.target.value } : current,
                  )
                }
              />
            </label>
            <label>
              <span>Starts Monday</span>
              <input
                required
                type="date"
                ref={startDateInputRef}
                aria-describedby={
                  isMondayIsoDate(draft.startsOn)
                    ? undefined
                    : "custom-programme-start-error"
                }
                aria-invalid={!isMondayIsoDate(draft.startsOn)}
                value={draft.startsOn}
                onChange={(event) =>
                  setDraft((current) =>
                    current
                      ? { ...current, startsOn: event.target.value }
                      : current,
                  )
                }
              />
              {!isMondayIsoDate(draft.startsOn) ? (
                <span
                  className="custom-programme-inline-error"
                  id="custom-programme-start-error"
                >
                  Choose a Monday.
                  {mondayIsoForIsoDate(draft.startsOn) ? (
                    <button
                      type="button"
                      onClick={() =>
                        {
                          setDraft((current) =>
                            current
                              ? {
                                  ...current,
                                  startsOn: mondayIsoForIsoDate(current.startsOn),
                                }
                              : current,
                          );
                          requestAnimationFrame(() =>
                            startDateInputRef.current?.focus(),
                          );
                        }
                      }
                    >
                      Use {mondayIsoForIsoDate(draft.startsOn)}
                    </button>
                  ) : null}
                </span>
              ) : null}
            </label>
            <label>
              <span>Weeks</span>
              <input
                required
                type="number"
                min={1}
                max={MAX_CUSTOM_PROGRAMME_WEEKS}
                inputMode="numeric"
                value={draft.weekCount}
                onChange={(event) => updateWeekCount(Number(event.target.value))}
              />
            </label>
            <label className="custom-programme-toggle">
              <input
                type="checkbox"
                checked={draft.enabled}
                onChange={(event) =>
                  setDraft((current) =>
                    current
                      ? { ...current, enabled: event.target.checked }
                      : current,
                  )
                }
              />
              <span>Use this programme on Today</span>
            </label>
          </div>

          <div className="custom-programme-weeks">
            <div className="custom-programme-week-nav">
              <button
                type="button"
                disabled={activeWeek === 1}
                onClick={() => setActiveWeek((current) => current - 1)}
              >
                Previous week
              </button>
              <label>
                <span>Editing week</span>
                <select
                  value={activeWeek}
                  onChange={(event) => setActiveWeek(Number(event.target.value))}
                >
                  {Array.from(
                    { length: draft.weekCount },
                    (_, index) => index + 1,
                  ).map((weekNumber) => {
                    const assigned = draft.assignments.filter(
                      (assignment) => assignment.weekNumber === weekNumber,
                    ).length;
                    return (
                      <option key={weekNumber} value={weekNumber}>
                        Week {weekNumber} · {assigned} assigned · {7 - assigned} open
                      </option>
                    );
                  })}
                </select>
              </label>
              <button
                type="button"
                disabled={activeWeek === draft.weekCount}
                onClick={() => setActiveWeek((current) => current + 1)}
              >
                Next week
              </button>
            </div>
            <fieldset className="custom-programme-week">
              <legend>Week {String(activeWeek).padStart(2, "0")}</legend>
              <div className="custom-programme-days">
                {DAY_LABELS.map((day, dayIndex) => {
                  const assignment = draft.assignments.find(
                    (candidate) =>
                      candidate.weekNumber === activeWeek &&
                      candidate.dayIndex === dayIndex,
                  );
                  return (
                    <label key={day}>
                      <span>{day}</span>
                      <select
                        aria-label={`Week ${activeWeek}, ${day}`}
                        value={assignment?.workoutId ?? ""}
                        onChange={(event) =>
                          setAssignment(
                            activeWeek,
                            dayIndex,
                            event.target.value,
                          )
                        }
                      >
                        <option value="">Unplanned</option>
                        {customWorkouts.map((workout) => (
                          <option key={workout.id} value={workout.id}>
                            {workout.name}
                          </option>
                        ))}
                      </select>
                    </label>
                  );
                })}
              </div>
              {activeWeek < draft.weekCount ? (
                <button
                  type="button"
                  className="copy-week"
                  onClick={() => copyWeekForward(activeWeek)}
                >
                  Repeat Week {activeWeek} through Week {draft.weekCount}
                </button>
              ) : null}
            </fieldset>
          </div>

          <div className="custom-programme-actions">
            <button type="button" onClick={cancelEditing}>
              Discard draft
            </button>
            <button type="submit">Save programme</button>
          </div>
        </form>
      ) : null}
    </section>
  );
}
