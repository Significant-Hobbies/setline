# Setline privacy

Setline has no account and no server. Your training is a file on your iPhone.

Last updated 16 August 2026.

**The app collects nothing.** Setline has no sign-in, no analytics and makes no
network requests. Every workout, target and measurement is written to the app's
own container on your device. There is no copy anywhere else, and the developer
cannot see your data.

## What the app stores, and where

Setline keeps one JSON document in its own private container on your iPhone. It
holds your programme, workout templates, recorded sets, exercise targets and
history. iOS protects it with the same sandbox and device encryption it applies
to any app's private storage.

That document is the only copy. If you delete the app, iOS deletes it with the
app, and the data is gone. If you lose the device, the data is gone with it.

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
- No backend, database, or hosting account. There is no server to hold your data
  or to breach.
- No analytics, telemetry, crash reporting, or advertising SDK in the app.
- No tracking across apps or websites, and no data shared with or sold to
  anyone.
- No sensors, contacts, photos, location, or Apple Health access. The app
  requests no permissions beyond notifications, and only if you enable them.

Planned features — syncing across your devices through iCloud, and reading and
writing Apple Health — are not built. When either ships, this page will change
before it does, and both will be something you turn on rather than a default.

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
someone else is holding it. For the app, nobody is: you already hold the only
copy, Export produces it in full, and Reset local data or deleting the app
erases it. For website analytics, ask for removal at the contact below and it
will be deleted.

## Changes

If this notice changes, the date above changes with it, and the reason appears
in the [changelog](https://setline.significanthobbies.com/changelog). It will not
be changed to retroactively permit collecting something that was previously
stated as not collected.

## Contact

Raise a privacy question as a
[GitHub issue](https://github.com/Significant-Hobbies/setline/issues), or through
[sarthakagrawal.dev](https://sarthakagrawal.dev).
