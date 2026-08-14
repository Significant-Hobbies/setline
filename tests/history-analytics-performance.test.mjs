import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { performance } from "node:perf_hooks";
import test from "node:test";
import { createServer } from "vite";

const SIZES = [50, 250, 500];
const ITERATIONS = 25;
const EXPECTED_HASHES = new Map([
  [50, "4a1278846a049e8abaab37035ef5dcf1f817a22fea8512d5b5926b6a855dc9b8"],
  [250, "bc7296bb5223078b7eb1810b1822ef1bc343b4a20524794c1f23e10f62726579"],
  [500, "d23d83d5588606a97912239ad1b189e522a1eb70ad3feef96cdd7057889d8a38"],
]);

let deriveHistoryAnalytics;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  ({ deriveHistoryAnalytics } = await vite.ssrLoadModule(
    "/src/lib/history-analytics.ts",
  ));
});

test.after(async () => {
  await vite.close();
});

test("history analytics scales across the supported session limit", () => {
  const metrics = [];

  for (const size of SIZES) {
    const history = buildHistory(size);
    const expected = JSON.stringify(deriveHistoryAnalytics(history));
    const expectedHash = createHash("sha256").update(expected).digest("hex");
    assert.equal(expectedHash, EXPECTED_HASHES.get(size));
    let durationMs = 0;

    for (let iteration = 0; iteration < ITERATIONS; iteration += 1) {
      const startedAt = performance.now();
      const result = deriveHistoryAnalytics(history);
      durationMs += performance.now() - startedAt;
      const serialized = JSON.stringify(result);
      assert.equal(serialized, expected);
      assert.equal(
        createHash("sha256").update(serialized).digest("hex"),
        expectedHash,
      );
    }

    metrics.push(`size${size}=${(durationMs / ITERATIONS).toFixed(3)}ms/op`);
  }

  console.log(`[benchmark] ${metrics.join(" ")} (${ITERATIONS} iterations)`);
  console.log(`[resource] maximum_supported_sessions=${SIZES.at(-1)}`);
});

function buildHistory(size) {
  return Array.from({ length: size }, (_, historyIndex) => {
    const executions = Array.from({ length: 18 }, (_, executionIndex) => {
      const exerciseIndex = executionIndex % 12;
      const weight = 40 + exerciseIndex * 2.5 + (historyIndex % 8) * 1.25;
      const reps = 5 + ((historyIndex + executionIndex) % 8);
      return {
        id: `execution-${historyIndex}-${executionIndex}`,
        source: "planned",
        clonedFromId: null,
        plannedPosition: executionIndex + 1,
        performedPosition: executionIndex + 1,
        deferred: false,
        status: executionIndex % 17 === 0 ? "skipped" : "completed",
        step: {
          id: `step-${executionIndex}`,
          plannedStepId: `step-${executionIndex}`,
          exercise: `Exercise ${exerciseIndex}`,
          setType: executionIndex % 6 === 0 ? "Warm-up" : "Working",
          setLabel: `Set ${executionIndex + 1}`,
          tracking: "weight-reps",
          targetWeight: weight,
          targetReps: reps,
          targetRepsMax: reps + 2,
          targetDurationSeconds: null,
          restSeconds: 90,
          targetRpe: 8,
          cue: "",
          optional: false,
        },
        segments: [
          {
            id: `segment-${historyIndex}-${executionIndex}`,
            weight,
            reps,
            durationSeconds: null,
          },
        ],
        actualRpe: 6 + ((historyIndex + executionIndex) % 4),
        startedAt: historyIndex * 100_000 + executionIndex * 1_000,
        completedAt: historyIndex * 100_000 + executionIndex * 1_000 + 500,
        authoredRestSeconds: 90,
        adjustedRestSeconds: 90,
        actualRestSeconds: 80 + (executionIndex % 20),
      };
    });

    return {
      id: `history-${historyIndex}`,
      workoutId: historyIndex % 10 === 0 ? "custom:conditioning" : "upper",
      workoutName: historyIndex % 10 === 0 ? "Conditioning" : "Upper",
      weekNumber: (historyIndex % 12) + 1,
      completedAt: 2_000_000_000_000 - historyIndex * 86_400_000,
      durationSeconds: 2_400 + (historyIndex % 600),
      completedSets: executions.filter(
        (record) => record.status === "completed",
      ).length,
      modifiedSets: historyIndex % 3,
      extraSets: historyIndex % 2,
      deferredSets: historyIndex % 4,
      skippedSets: executions.filter((record) => record.status === "skipped")
        .length,
      workingVolume: executions.reduce(
        (total, record) =>
          record.status === "completed" && record.step.setType === "Working"
            ? total + record.segments[0].weight * record.segments[0].reps
            : total,
        0,
      ),
      warmupVolume: 0,
      completedDurationSeconds: 0,
      totalActualRestSeconds: 1_400,
      averageRpe: 7.5,
      quality: 4,
      detailsAvailable: true,
      executions,
    };
  });
}
