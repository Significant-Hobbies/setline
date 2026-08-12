# Setline for iPhone

Native SwiftUI workout execution for iOS 17 and later. The app uses Apple frameworks only and keeps active workouts usable offline.

## Local checks

```bash
./scripts/check.sh
```

The destination can be overridden with `SETLINE_SIMULATOR_DESTINATION`.

## Personal-team archive

```bash
SETLINE_ARCHIVE_PATH=/private/tmp/Setline.xcarchive ./scripts/archive.sh
```

The archive script is locked to personal team `8F7LXHTJZR`, verifies the app signature, and intentionally contains no upload step.

## Device-only checks before submission

- Exercise the full workout flow one-handed on the smallest supported physical iPhone.
- Background the app for longer than one rest interval and confirm wall-clock recovery.
- Verify VoiceOver order and the largest Dynamic Type categories on hardware.
- Confirm account callback, Keychain persistence, airplane-mode recovery, and notification behavior once account sync is enabled.
- Confirm the final App Store icon, screenshots, support URL, privacy URL, age rating, and privacy answers in App Store Connect before any upload.
