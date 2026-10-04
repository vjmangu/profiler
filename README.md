# Profiler

One-tap profiles that block apps on Android.

| Profile | Blocks by default | Extras |
|---|---|---|
| **Kid** | Messaging, calls & contacts, banking/payments, email, shopping | Parent PIN or fingerprint to exit · Tamper protection (Settings, Play Store and uninstall blocked) |
| **Focus** | Social media | — |
| **Work** | Social, video, games, news, shopping | Auto-on Mon–Fri 9–5 (editable) |
| **Custom** | Whatever you pick | Any schedule |

Defaults are suggestions based on known package names, Android app categories and app-name keywords. Every list can be edited.

## How it works

```
Flutter UI (lib/)  ──syncConfig(JSON)──▶  profiler_blocker plugin (Kotlin)
                                           ├─ BlockerConfig      rules + schedule (mirrors Dart)
                                           ├─ AccessibilityService  sees foreground package → blocks
                                           └─ BlockActivity      "X is blocked" screen
```

* Blocking runs natively, so it keeps working when the app is closed. Schedules are checked on every app switch and re-checked every 15 seconds.
* Precedence: a profile you start manually wins. Otherwise the first profile whose schedule is active applies. "Pause" on a scheduled profile lasts until its current window ends.
* The service reads **only the foreground package name**. It has `canRetrieveWindowContent=false`, no network permission, and no analytics.
* The PIN is stored as a salted SHA-256 hash in encrypted storage. Five wrong tries lock entry for 30 seconds. Biometrics use `local_auth`.

## Project layout

```
lib/
  main.dart                    app shell, first-run PIN setup
  models/profile.dart          Profile, ProfileSchedule (+ JSON)
  data/app_groups.dart         package/keyword/category rules for suggestions
  state/app_state.dart         active-profile logic, persistence, native sync
  services/                    profile_store (prefs), auth_service (PIN + biometrics)
  screens/                     home, profile editor, app picker, lock, PIN setup
  widgets/                     pin pad, Play-required accessibility disclosure
packages/profiler_blocker/     local Flutter plugin (Dart API + Kotlin engine)
android/app/.../MainActivity.kt  FlutterFragmentActivity (needed for biometrics)
test/widget_test.dart          unit tests for schedules, JSON, suggestions
.github/workflows/android.yml  CI: create → analyze → test → build APK
```

Only the files that differ from Flutter's template are committed. CI (or you, locally) runs `flutter create` to fill in the standard Gradle boilerplate. Existing files are never overwritten.

## Build locally

```bash
flutter create --org com.vamsee --project-name profiler --platforms android .
# set minSdk = 24 in android/app/build.gradle.kts
flutter pub get
flutter test
flutter run            # phone connected with USB debugging on
```

## Test checklist (real phone)

1. First launch: set a 4-digit PIN.
2. Tap **Blocking is off** → read the disclosure → **Agree** → enable *Profiler* under Accessibility.
   * Android 13+ may grey it out for sideloaded APKs. Go to App info → ⋮ → **Allow restricted settings**, then try again.
3. **Focus** → Start → open Instagram/YouTube → you should be sent home with a "blocked" screen.
4. **Kid** → Start → try Messages, Phone, a bank app, Settings, and Play Store → all blocked. Try a game → it works.
5. In Kid, tap **Turn off** → PIN or fingerprint is required. Five wrong PINs → 30-second lockout.
6. **Work**: edit the schedule to start 2 minutes from now, open a social app, and wait. It gets blocked within about 15 seconds of the start time.
7. Reboot the phone → blocking still works (the service restarts automatically).

## Known limits

* Incoming calls still ring. The Kid profile blocks the dialer and contacts, which stops outgoing calls.
* A determined user with a computer could use `adb` to remove the app. Device Owner / Family Link-style management is a possible future upgrade.
* iOS is not included yet. It needs Apple's Family Controls entitlement and the Screen Time APIs (planned).

## Google Play launch checklist

- [ ] Developer account ($25) + identity verification
- [ ] Release signing: create an upload keystore, add `key.properties`, and set the release `signingConfig`. Enroll in Play App Signing.
- [ ] `flutter build appbundle --release`
- [ ] Privacy policy URL (the app collects no data; still required)
- [ ] Data safety form: no data collected or shared
- [ ] **AccessibilityService declaration** in Play Console + demo video. The video must show the in-app disclosure, the consent tap, and blocking in action (`lib/widgets/permission_disclosure.dart`).
- [ ] Target audience: adults/parents (keeps you out of the Families program)
- [ ] Closed test: **12+ testers opted in for 14 consecutive days** (new personal accounts), then apply for production
- [ ] Store listing: icon, feature graphic, phone screenshots, short and full description
