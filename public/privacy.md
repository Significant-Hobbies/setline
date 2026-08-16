# Setline privacy

Setline has no account and no server. Your training is a file on your iPhone.

Last updated 16 August 2026.

**The developer collects nothing.** Setline has no account, no analytics and no
server of its own. Every workout, target and measurement is written to the app's
own container on your device. The only copy that ever leaves it is one you send —
an export, or iCloud sync into your own Apple Account, which the developer cannot
read.

## What the app stores, and where

Setline keeps one JSON document in its own private container on your iPhone. It
holds your programme, workout templates, recorded sets, exercise targets and
history. iOS protects it with the same sandbox and device encryption it applies
to any app's private storage.

Until you export it or turn on iCloud sync, that document is the only copy. If you
delete the app, iOS deletes it with the app, and the data is gone. If you lose the
device, the data is gone with it.

### Your data leaves only when you send it

- **Export** writes the complete document to a file you choose the destination
  for, using the standard iOS share sheet. Where it goes after that — Files,
  iCloud Drive, a message, another app — is your choice and that service's
  privacy policy, not Setline's.
- **Import** reads a file you pick and, after showing you what it contains,
  replaces the data on the device. Nothing is uploaded.
- **Reset local data** erases the document on the device immediately.

### Notifications

If you allow notifications, Setline schedules a local alert so a rest timer
still finishes when you leave the app. Local notifications are scheduled by iOS
on the device; nothing is sent to a push server, and no notification content
reaches the developer.

## What Setline does not do

- No account, sign-in, or user identity.
- No backend, database, or hosting account of Setline's own. There is no server
  the developer controls that holds your data, so there is none to breach.
- No analytics, telemetry, crash reporting, or advertising SDK in the app.
- No tracking across apps or websites, and no data shared with or sold to
  anyone.
- No sensors, contacts, photos, location, or Apple Health access. The app
  requests no permissions beyond notifications, and only if you enable them.

### iCloud sync

Sync between your own devices is built but **not active yet**, because it has not
been verified against a real iCloud container. When it is switched on, this is
exactly what it does and does not do:

- Your training is stored in **your own iCloud private database**, under your
  Apple Account. Apple holds it under
  [Apple's privacy policy](https://www.apple.com/legal/privacy/); the developer has
  no access to it and no way to read it.
- There is still no Setline account and no Setline server. Sync uses the iCloud
  account already on your device.
- **A workout in progress is never synced.** A session you are still doing belongs
  to the phone in your hand.
- Nothing is sent if you are signed out of iCloud, and the app says so rather than
  failing quietly.
- Export keeps working regardless, and stays your backup on any device where
  iCloud is off.

Apple Health reading and writing is not built. When it ships, this page will
change before it does, and it will be something you turn on rather than a default.

## This website

The website is separate from the app and is not needed to use it. It is static
files served by GitHub Pages, which records request logs including IP addresses
as any web host does. See the
[GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

Two third-party scripts run on these pages:

### PostHog analytics

Counts page views, so the developer knows whether anyone reads these pages. It
handles the page URL, referrer, browser and device type, approximate location
derived from your IP address, and a stored identifier. Autocapture of clicks and
typing is switched off, so it records that a page was viewed and not what you did
on it.

### Portfolio strip (`sassmaker.com`)

Shows the developer's other projects at the bottom of the page. Loading it
requests a file from that domain, which exposes your IP address to it as any
embedded script does.

No workout data reaches either one, because the app never sends anything to the
website. Blocking both, or blocking cookies, does not affect the app.

## Children

Setline is not directed at children under 13 and collects nothing from anyone.

## Your rights

Rights to access, correct, export and erase personal data generally assume
someone else is holding it. For the app, the developer is not: you hold the copy,
Export produces it in full, and Reset local data or deleting the app erases it. If
you turn on iCloud sync, the other copy sits in your own Apple Account, which you
control directly through iCloud settings. For website analytics, ask for removal at
the contact below and it will be deleted.

## Changes

If this notice changes, the date above changes with it, and the reason appears
in the [changelog](https://setline.significanthobbies.com/changelog). It will not
be changed to retroactively permit collecting something that was previously
stated as not collected.

## Contact

Raise a privacy question as a
[GitHub issue](https://github.com/Significant-Hobbies/setline/issues), or through
[sarthakagrawal.dev](https://sarthakagrawal.dev).
