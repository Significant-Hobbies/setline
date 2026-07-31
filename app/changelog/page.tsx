import type { Metadata } from "next";
import Link from "next/link";

const repository = "https://github.com/Significant-Hobbies/setline";
const releases = [
  {
    date: "2026-07-31",
    title: "Put custom workouts on the calendar",
    outcomes: [
      "Write one explicit 1–16 week programme, assign custom workouts to Monday-based days, copy a week forward, and pause or resume the block.",
      "Today now opens the scheduled custom workout or identifies an in-range day as unplanned; programme state stays device-first and travels in whole-state backup and private sync.",
    ],
  },
  {
    date: "2026-07-31",
    title: "Your own workouts, in your own order",
    outcomes: [
      "Create an ordered workout from scratch or duplicate a bundled or custom template into an independent copy.",
      "Custom templates stay device-first, travel in Setline backups and private account sync, and never rewrite sessions or history after an edit or deletion.",
    ],
  },
  {
    date: "2026-07-28",
    title: "The full twelve-week programme arrived",
    outcomes: [
      "Strength, cardio, mobility, preparation, and cooldown work now follow the supplied authored order.",
      "Week-aware RDL volume, hard-cardio rounds, and pull-up checkpoints appear on the correct dates.",
    ],
  },
  {
    date: "2026-07-28",
    title: "Flexible sessions without silent programme rewrites",
    outcomes: [
      "Partial and drop segments, session-only extra sets, and Do later deferrals can be recorded explicitly.",
      "Planned order, actual execution order, authored rest, adjusted rest, and wall-clock rest remain separate in history.",
    ],
  },
  {
    date: "2026-07-27",
    title: "Private sync stayed optional",
    outcomes: [
      "Google sign-in can keep one private D1-backed account copy while device-only workouts remain first-class.",
      "Offline changes retry deterministically without reordering exercises or sets.",
    ],
  },
  {
    date: "2026-07-27",
    title: "Setline v1",
    outcomes: [
      "The first installable workout player shipped with guided sets, modality-aware recording, automatic rest, history, and progress.",
      "The active workout remains functional without a network request.",
    ],
  },
] as const;

export const metadata: Metadata = {
  title: "Changelog — Setline",
  description: "Meaningful improvements to Setline workout execution and history.",
};

export default function ChangelogPage() {
  return (
    <main className="changelog-shell">
      <header className="changelog-header">
        <Link className="wordmark changelog-wordmark" href="/">SETLINE</Link>
        <span className="section-code">PRODUCT HISTORY</span>
        <h1>Changelog</h1>
        <p>Meaningful improvements to programme execution, rest timing, and workout history.</p>
        <nav aria-label="Project links">
          <a href={`${repository}/issues`}>Roadmap</a>
          <a href={repository}>Source</a>
        </nav>
      </header>

      <ol className="changelog-list">
        {releases.map((release) => (
          <li key={`${release.date}-${release.title}`}>
            <article className="changelog-entry">
              <time dateTime={release.date}>
                {new Date(`${release.date}T00:00:00`).toLocaleDateString("en-US", {
                  year: "numeric",
                  month: "long",
                  day: "numeric",
                })}
              </time>
              <h2>{release.title}</h2>
              <ul>
                {release.outcomes.map((outcome) => <li key={outcome}>{outcome}</li>)}
              </ul>
            </article>
          </li>
        ))}
      </ol>
    </main>
  );
}
