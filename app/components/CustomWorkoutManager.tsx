"use client";

import { useEffect, useRef, useState } from "react";

import {
  blankCustomWorkoutTemplate,
  customWorkoutId,
  duplicateWorkoutTemplate,
  isCustomWorkoutTemplate,
  MAX_CUSTOM_WORKOUTS,
  MAX_CUSTOM_WORKOUT_STEPS,
  type CustomWorkoutTemplate,
} from "../lib/custom-workouts";
import {
  formatStepTarget,
  type PlannedStep,
  type StepType,
  type TrackingKind,
  type WorkoutTemplate,
} from "../lib/programme";

type Props = {
  authoringLocked?: boolean;
  builtInWorkouts: WorkoutTemplate[];
  customWorkouts: CustomWorkoutTemplate[];
  onDelete: (id: CustomWorkoutTemplate["id"]) => void;
  onEditingChange: (editing: boolean) => void;
  onSave: (template: CustomWorkoutTemplate) => void;
  onStart: (template: CustomWorkoutTemplate) => void;
};

const TRACKING_OPTIONS: { value: TrackingKind; label: string }[] = [
  { value: "weight-reps", label: "Weight + reps" },
  { value: "reps", label: "Repetitions" },
  { value: "duration", label: "Duration" },
  { value: "weight-duration", label: "Weight + duration" },
  { value: "completion", label: "Completion only" },
];

const STEP_TYPES: StepType[] = [
  "Preparation",
  "Warm-up",
  "Working",
  "Cardio",
  "Mobility",
  "Cooldown",
  "Check",
];

function wallClockNow() {
  return Date.now();
}

function cloneTemplate(template: CustomWorkoutTemplate): CustomWorkoutTemplate {
  return structuredClone(template);
}

function numberOrNull(value: string) {
  if (!value.trim()) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function stepForTracking(
  step: PlannedStep,
  tracking: TrackingKind,
): PlannedStep {
  return {
    ...step,
    tracking,
    targetWeight:
      tracking === "weight-reps" || tracking === "weight-duration"
        ? step.targetWeight
        : null,
    targetReps:
      tracking === "weight-reps" || tracking === "reps"
        ? (step.targetReps ?? 8)
        : null,
    targetRepsMax:
      tracking === "weight-reps" || tracking === "reps"
        ? step.targetRepsMax
        : null,
    targetDurationSeconds:
      tracking === "duration" || tracking === "weight-duration"
        ? (step.targetDurationSeconds ?? 60)
        : null,
  };
}

export function CustomWorkoutManager({
  authoringLocked = false,
  builtInWorkouts,
  customWorkouts,
  onDelete,
  onEditingChange,
  onSave,
  onStart,
}: Props) {
  const [draft, setDraft] = useState<CustomWorkoutTemplate | null>(null);
  const [error, setError] = useState("");
  const [receipt, setReceipt] = useState("");
  const nameInputRef = useRef<HTMLInputElement>(null);
  const newWorkoutButtonRef = useRef<HTMLButtonElement>(null);
  const returnFocusRef = useRef<HTMLButtonElement | null>(null);
  const draftId = draft?.id;
  const isEditing = draft !== null;

  useEffect(() => {
    onEditingChange(isEditing);
  }, [isEditing, onEditingChange]);

  useEffect(
    () => () => {
      onEditingChange(false);
    },
    [onEditingChange],
  );

  useEffect(() => {
    if (draftId) nameInputRef.current?.focus();
  }, [draftId]);

  useEffect(() => {
    if (!draft) return;
    const preventUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", preventUnload);
    return () => window.removeEventListener("beforeunload", preventUnload);
  }, [draft]);

  const finishEditing = () => {
    setDraft(null);
    requestAnimationFrame(() => {
      const returnTarget = returnFocusRef.current?.isConnected
        ? returnFocusRef.current
        : newWorkoutButtonRef.current;
      returnTarget?.focus();
    });
  };

  const canReplaceDraft = () =>
    draft === null ||
    window.confirm(
      "Discard the current unsaved draft and open another workout?",
    );

  const cancelEditing = () => {
    if (!window.confirm("Discard this unsaved custom workout draft?")) return;
    finishEditing();
  };

  const beginNew = (opener: HTMLButtonElement) => {
    if (!canReplaceDraft()) return;
    if (customWorkouts.length >= MAX_CUSTOM_WORKOUTS) {
      setError(`Setline keeps at most ${MAX_CUSTOM_WORKOUTS} custom workouts.`);
      return;
    }
    returnFocusRef.current = opener;
    setError("");
    setReceipt("");
    setDraft(blankCustomWorkoutTemplate(customWorkoutId()));
  };

  const beginDuplicate = (
    source: WorkoutTemplate,
    opener: HTMLButtonElement,
  ) => {
    if (!canReplaceDraft()) return;
    if (customWorkouts.length >= MAX_CUSTOM_WORKOUTS) {
      setError(`Setline keeps at most ${MAX_CUSTOM_WORKOUTS} custom workouts.`);
      return;
    }
    returnFocusRef.current = opener;
    setError("");
    setReceipt("");
    setDraft(duplicateWorkoutTemplate(source, customWorkoutId()));
  };

  const beginEdit = (
    template: CustomWorkoutTemplate,
    opener: HTMLButtonElement,
  ) => {
    if (!canReplaceDraft()) return;
    returnFocusRef.current = opener;
    setError("");
    setReceipt("");
    setDraft(cloneTemplate(template));
  };

  const updateStep = (stepId: string, patch: Partial<PlannedStep>) => {
    setDraft((current) =>
      current
        ? {
            ...current,
            steps: current.steps.map((step) =>
              step.id === stepId ? { ...step, ...patch } : step,
            ),
          }
        : current,
    );
  };

  const addStep = () => {
    setDraft((current) => {
      if (!current || current.steps.length >= MAX_CUSTOM_WORKOUT_STEPS) {
        return current;
      }
      const stepNumber = current.steps.length + 1;
      return {
        ...current,
        steps: [
          ...current.steps,
          {
            id: `${current.id}:step:${Date.now()}:${stepNumber}`,
            exercise: "",
            setType: "Working",
            setLabel: `Set ${stepNumber}`,
            tracking: "weight-reps",
            targetWeight: null,
            targetReps: 8,
            targetRepsMax: null,
            targetDurationSeconds: null,
            restSeconds: 90,
            cue: "",
          },
        ],
      };
    });
  };

  const moveStep = (index: number, offset: -1 | 1) => {
    if (!draft) return;
    const destination = index + offset;
    if (destination < 0 || destination >= draft.steps.length) return;
    const movedStep = draft.steps[index];
    const steps = [...draft.steps];
    [steps[index], steps[destination]] = [steps[destination], steps[index]];
    setDraft({ ...draft, steps });
    setReceipt(
      `Moved ${movedStep.exercise.trim() || "unnamed exercise"} to step ${
        destination + 1
      } of ${steps.length}.`,
    );
  };

  const removeStep = (stepId: string) => {
    const step = draft?.steps.find((candidate) => candidate.id === stepId);
    if (
      !step ||
      !window.confirm(
        `Remove ${step.exercise.trim() || "this exercise"} from the unsaved draft?`,
      )
    ) {
      return;
    }
    setDraft((current) =>
      current && current.steps.length > 1
        ? {
            ...current,
            steps: current.steps.filter((step) => step.id !== stepId),
          }
        : current,
    );
  };

  const saveDraft = () => {
    if (!draft) return;
    const savedAt = wallClockNow();
    const candidate: CustomWorkoutTemplate = {
      ...draft,
      name: draft.name.trim(),
      scheduleName: draft.name.trim(),
      updatedAt: savedAt,
      steps: draft.steps.map((step) => ({
        ...step,
        exercise: step.exercise.trim(),
        setLabel: step.setLabel.trim(),
        cue: step.cue.trim(),
      })),
    };
    if (!isCustomWorkoutTemplate(candidate)) {
      setError(
        "Check the workout name and every exercise target. Duration, repetitions, and rest must be valid non-negative values.",
      );
      return;
    }
    onSave(candidate);
    finishEditing();
    setError("");
    setReceipt(`${candidate.name} saved in authored order.`);
  };

  const deleteTemplate = (template: CustomWorkoutTemplate) => {
    const deletingEditedTemplate = draft?.id === template.id;
    if (
      !window.confirm(
        `Delete ${template.name}?${
          deletingEditedTemplate ? " Unsaved edits will be discarded." : ""
        } Active sessions and saved history will remain unchanged.`,
      )
    ) {
      return;
    }
    onDelete(template.id);
    setReceipt(`${template.name} deleted. Existing workout records were kept.`);
    if (deletingEditedTemplate) {
      returnFocusRef.current = newWorkoutButtonRef.current;
      finishEditing();
    }
  };

  return (
    <section
      className="custom-workouts"
      aria-labelledby="custom-workouts-heading"
    >
      <div className="custom-workouts-heading">
        <div>
          <span className="section-code">YOUR WORKOUTS</span>
          <h2 id="custom-workouts-heading">Write the sequence once.</h2>
          <p>
            Ordered templates stay on this device first. Setline never changes
            targets or treats a duplicate as linked to its source.
          </p>
        </div>
        <button
          ref={newWorkoutButtonRef}
          type="button"
          disabled={authoringLocked}
          onClick={(event) => beginNew(event.currentTarget)}
        >
          New workout
        </button>
      </div>

      {receipt ? (
        <p className="custom-workout-receipt" role="status">
          {receipt}
        </p>
      ) : null}
      {error ? (
        <p className="custom-workout-error" role="alert">
          {error}
        </p>
      ) : null}
      {authoringLocked ? (
        <p className="custom-workout-lock" role="status">
          Finish or discard the programme draft before changing workout
          templates.
        </p>
      ) : null}

      {draft ? (
        <form
          className="custom-workout-editor"
          onSubmit={(event) => {
            event.preventDefault();
            saveDraft();
          }}
        >
          <div className="custom-editor-heading">
            <div>
              <span className="section-code">AUTHORING MODE</span>
              <h3>
                {draft.createdAt === draft.updatedAt
                  ? "Custom workout"
                  : "Edit workout"}
              </h3>
            </div>
            <button type="button" onClick={cancelEditing}>
              Cancel
            </button>
          </div>

          <div className="custom-workout-fields">
            <label>
              <span>Workout name</span>
              <input
                ref={nameInputRef}
                required
                maxLength={80}
                value={draft.name}
                onChange={(event) =>
                  setDraft((current) =>
                    current
                      ? { ...current, name: event.target.value }
                      : current,
                  )
                }
                placeholder="e.g. Travel-day strength"
              />
            </label>
            <label>
              <span>Expected minutes</span>
              <input
                required
                type="number"
                min={1}
                max={480}
                inputMode="numeric"
                value={draft.expectedMinutes}
                onChange={(event) =>
                  setDraft((current) =>
                    current
                      ? {
                          ...current,
                          expectedMinutes: Number(event.target.value),
                        }
                      : current,
                  )
                }
              />
            </label>
          </div>

          <ol className="custom-step-list">
            {draft.steps.map((step, index) => (
              <li
                key={step.id}
                className="custom-step-editor"
                role="group"
                aria-label={`Step ${index + 1}: ${
                  step.exercise.trim() || "unnamed exercise"
                }`}
              >
                <div className="custom-step-heading">
                  <strong>{String(index + 1).padStart(2, "0")}</strong>
                  <span>Authored position</span>
                  <div>
                    <button
                      type="button"
                      disabled={index === 0}
                      aria-label={`Move ${step.exercise || `step ${index + 1}`} earlier`}
                      onClick={() => moveStep(index, -1)}
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      disabled={index === draft.steps.length - 1}
                      aria-label={`Move ${step.exercise || `step ${index + 1}`} later`}
                      onClick={() => moveStep(index, 1)}
                    >
                      ↓
                    </button>
                    <button
                      type="button"
                      disabled={draft.steps.length === 1}
                      onClick={() => removeStep(step.id)}
                    >
                      Remove
                    </button>
                  </div>
                </div>

                <div className="custom-step-fields">
                  <label className="custom-step-exercise">
                    <span>Exercise</span>
                    <input
                      required
                      maxLength={240}
                      value={step.exercise}
                      onChange={(event) =>
                        updateStep(step.id, { exercise: event.target.value })
                      }
                      placeholder="e.g. Goblet squat"
                    />
                  </label>
                  <label>
                    <span>Step type</span>
                    <select
                      value={step.setType}
                      onChange={(event) =>
                        updateStep(step.id, {
                          setType: event.target.value as StepType,
                        })
                      }
                    >
                      {STEP_TYPES.map((type) => (
                        <option key={type} value={type}>
                          {type}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label>
                    <span>Tracking</span>
                    <select
                      value={step.tracking}
                      onChange={(event) =>
                        updateStep(
                          step.id,
                          stepForTracking(
                            step,
                            event.target.value as TrackingKind,
                          ),
                        )
                      }
                    >
                      {TRACKING_OPTIONS.map((option) => (
                        <option key={option.value} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label>
                    <span>Set label</span>
                    <input
                      required
                      maxLength={240}
                      value={step.setLabel}
                      onChange={(event) =>
                        updateStep(step.id, { setLabel: event.target.value })
                      }
                    />
                  </label>
                  {step.tracking === "weight-reps" ||
                  step.tracking === "weight-duration" ? (
                    <label>
                      <span>Target kg (optional)</span>
                      <input
                        type="number"
                        min={0}
                        max={10_000}
                        step="any"
                        inputMode="decimal"
                        value={step.targetWeight ?? ""}
                        onChange={(event) =>
                          updateStep(step.id, {
                            targetWeight: numberOrNull(event.target.value),
                          })
                        }
                      />
                    </label>
                  ) : null}
                  {step.tracking === "weight-reps" ||
                  step.tracking === "reps" ? (
                    <label>
                      <span>Target reps</span>
                      <input
                        required
                        type="number"
                        min={1}
                        max={10_000}
                        inputMode="numeric"
                        value={step.targetReps ?? ""}
                        onChange={(event) =>
                          updateStep(step.id, {
                            targetReps: numberOrNull(event.target.value),
                          })
                        }
                      />
                    </label>
                  ) : null}
                  {step.tracking === "duration" ||
                  step.tracking === "weight-duration" ? (
                    <label>
                      <span>Target seconds</span>
                      <input
                        required
                        type="number"
                        min={1}
                        max={10_000}
                        inputMode="numeric"
                        value={step.targetDurationSeconds ?? ""}
                        onChange={(event) =>
                          updateStep(step.id, {
                            targetDurationSeconds: numberOrNull(
                              event.target.value,
                            ),
                          })
                        }
                      />
                    </label>
                  ) : null}
                  <label>
                    <span>Rest seconds</span>
                    <input
                      required
                      type="number"
                      min={0}
                      max={3_600}
                      inputMode="numeric"
                      value={step.restSeconds}
                      onChange={(event) =>
                        updateStep(step.id, {
                          restSeconds: Number(event.target.value),
                        })
                      }
                    />
                  </label>
                  <label className="custom-step-cue">
                    <span>Cue (optional)</span>
                    <input
                      maxLength={240}
                      value={step.cue}
                      onChange={(event) =>
                        updateStep(step.id, { cue: event.target.value })
                      }
                      placeholder="One precise execution note"
                    />
                  </label>
                </div>
              </li>
            ))}
          </ol>

          <div className="custom-editor-actions">
            <button
              type="button"
              disabled={draft.steps.length >= MAX_CUSTOM_WORKOUT_STEPS}
              onClick={addStep}
            >
              Add exercise
            </button>
            <button type="submit">Save workout</button>
          </div>
        </form>
      ) : null}

      <div className="custom-workout-library">
        <section>
          <h3>Custom templates</h3>
          {customWorkouts.length ? (
            <div className="custom-workout-list">
              {customWorkouts.map((template) => (
                <article key={template.id}>
                  <div>
                    <strong>{template.name}</strong>
                    <span>
                      {template.steps.length} ordered steps ·{" "}
                      {template.expectedMinutes} min
                    </span>
                    <small>{formatStepTarget(template.steps[0])} first</small>
                  </div>
                  <div>
                    <button type="button" onClick={() => onStart(template)}>
                      Start
                    </button>
                    <button
                      type="button"
                      disabled={authoringLocked}
                      onClick={(event) =>
                        beginEdit(template, event.currentTarget)
                      }
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      disabled={authoringLocked}
                      onClick={(event) =>
                        beginDuplicate(template, event.currentTarget)
                      }
                    >
                      Duplicate
                    </button>
                    <button
                      type="button"
                      disabled={authoringLocked}
                      onClick={() => deleteTemplate(template)}
                    >
                      Delete
                    </button>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <p className="custom-workout-empty">
              No custom workouts yet. Duplicate a written workout or start with
              a blank sequence.
            </p>
          )}
        </section>

        <section>
          <h3>Duplicate the written plan</h3>
          <div className="custom-source-list">
            {builtInWorkouts.map((template) => (
              <button
                type="button"
                key={template.id}
                disabled={authoringLocked}
                onClick={(event) =>
                  beginDuplicate(template, event.currentTarget)
                }
              >
                <span>{template.name}</span>
                <small>{template.steps.length} steps · copy to edit</small>
              </button>
            ))}
          </div>
        </section>
      </div>
    </section>
  );
}
