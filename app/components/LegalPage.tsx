import Link from "next/link";

export function LegalPage({ kind }: { kind: "privacy" | "terms" }) {
  const privacy = kind === "privacy";

  return (
    <main className="legal-shell">
      <Link className="legal-back" href="/">
        ← Back to Setline
      </Link>
      <article className="legal-board">
        <span className="section-code">SETLINE · PUBLIC INFORMATION</span>
        <h1>{privacy ? "Privacy notice" : "Terms of use"}</h1>
        <p className="legal-date">Effective 27 July 2026</p>

        {privacy ? (
          <>
            <h2>The short version</h2>
            <p>
              Setline is a private workout execution tracker. Device-only mode keeps
              programme, active-session, and history data in this browser. If you choose
              Google sign-in, one private copy is also stored in Cloudflare D1 for your
              account.
            </p>

            <h2>Data Setline processes</h2>
            <p>
              Device storage can contain exercise targets, completed and skipped sets,
              actual weight and repetitions, RPE, pain or notes when supported, workout
              timestamps, and history. Google mode also receives your Google account
              identifier, name, email address, and profile image from the basic identity
              scopes you approve. Authentication records can include OAuth access,
              refresh, and ID tokens, granted scope, Setline session tokens, IP address,
              and browser user-agent information.
            </p>

            <h2>How the data is used</h2>
            <p>
              Setline uses this information only to operate the workout player, restore
              your record, calculate clearly labelled training summaries, and synchronize
              your private account copy. Authentication and session data is used to sign
              you in, keep the account private, and protect the service. Setline does not
              sell personal data, show advertising, or train AI models on workout data.
            </p>

            <h2>Storage and synchronization</h2>
            <p>
              Workout actions are written to the device before synchronization. Signed-in
              state is stored in a Cloudflare D1 row scoped to the authenticated user.
              Signing out removes that account’s workout copy from the device while
              retaining the private account copy. In device-only mode, clearing workout
              data removes the browser copy.
            </p>

            <h2>Retention and choices</h2>
            <p>
              Cloud state remains associated with the account until account-deletion
              tooling is provided or a deletion request is fulfilled. You can use
              device-only mode, sign out, revoke Google access, or stop using the service
              at any time.
            </p>
          </>
        ) : (
          <>
            <h2>Using Setline</h2>
            <p>
              You may use Setline to execute and record personal workout programmes. Keep
              access to your device and Google account secure, and do not interfere with
              the service or attempt to access another person’s data.
            </p>

            <h2>You control the programme</h2>
            <p>
              Setline records the targets and results you provide. It does not prescribe
              training, automatically change a programme, or replace qualified medical or
              coaching advice.
            </p>

            <h2>Your data</h2>
            <p>
              You retain ownership of workout information you enter. You grant Setline
              only the limited permission needed to store, synchronize, calculate, and
              display that information back to you.
            </p>

            <h2>Availability</h2>
            <p>
              The service is provided as available and may change. The workout player is
              designed to continue locally without a network connection, but browser
              storage can be cleared by you, the browser, or the operating system.
            </p>

            <h2>Safety</h2>
            <p>
              Stop an exercise if you experience pain or feel unsafe. Setline is a record
              and execution tool, not diagnosis, treatment, emergency guidance, or a
              substitute for a qualified professional.
            </p>
          </>
        )}
      </article>
    </main>
  );
}
