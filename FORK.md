# EOchat Fork — Upstream Maintenance Playbook

EOchat is a long-lived fork of [Conduit](https://github.com/cogwheel0/conduit).

## 1) Primary goal (always)

**Stay as close to upstream as possible.**

Small diff = cheap merges = fewer regressions.

Before adding fork behavior, always prefer:

1. **Configure** (`ForkOverrides`, `EOchatBranding.xcconfig`)
2. **Wrap** (small `if (ForkOverrides.flag) ...` around upstream)
3. **Add file** (fork-only file next to upstream)
4. **Edit upstream file** (last resort, smallest possible edit)

If you are about to do #4, first ask: *can this be moved to config/wrapper/new-file?*

---

## 2) Where fork behavior belongs

- Runtime flags: `lib/core/config/fork_overrides.dart`
- EO palette: `lib/shared/theme/eochat_palette.dart`
- iOS brand identifiers: `ios/Flutter/EOchatBranding.xcconfig`
- iOS extension xcconfig glue:
  - `ios/ConduitWidget/ConduitWidget.xcconfig`
  - `ios/ShareExtension/ShareExtension.debug.xcconfig`
  - `ios/ShareExtension/ShareExtension.release.xcconfig`
  - `ios/ShareExtension/ShareExtension.profile.xcconfig`
- Android native package/channel identifiers: `nl.eo.eochat` values in Kotlin + matching Dart call sites

Search prefixes that usually locate fork code quickly:
- `ForkOverrides`
- `EOCHAT_`
- `nl.eo.eochat`

---

## 3) Allowed inline edits to upstream files

Keep this list short. Current known inline-touch files:

- `lib/core/router/app_router.dart`
- `lib/core/providers/app_startup_providers.dart`
- `lib/features/auth/views/server_connection_page.dart`
- `lib/features/auth/views/authentication_page.dart`
- `lib/features/profile/views/profile_page.dart`
- `lib/features/navigation/widgets/sidebar_user_pill.dart`
- `lib/shared/services/brand_service.dart`
- `lib/shared/theme/color_tokens.dart`
- `lib/shared/theme/tweakcn_themes.dart`
- `lib/core/auth/native_cookie_manager.dart`

If a new fork behavior needs another upstream file, document why in the PR.

---

## 4) Android invariant (important)

Kotlin source path stays upstream-like:
`android/app/src/main/kotlin/app/cogwheel/conduit/...`

But Kotlin package is forked:
`package nl.eo.eochat`

Do **not** rename directories to match package unless you intentionally accept a large future merge tax.

Keep native identifiers synchronized across Kotlin + Dart:
- Method channels (e.g. `nl.eo.eochat/cookies`, `nl.eo.eochat/assistant`)
- Broadcast actions
- Any package-qualified `R` references

---

## 5) iOS invariant (most merge-sensitive)

### Source of truth
All EOchat IDs live in `ios/Flutter/EOchatBranding.xcconfig`.

`project.pbxproj` and plist/build settings should reference `$(EOCHAT_...)` (not hardcoded literals).

### Extension wiring requirement
`ShareExtension` and `ConduitWidgetExtension` configs must include branding xcconfig, directly or indirectly.

Required includes (as of now):
- `ConduitWidget.xcconfig` includes `../Flutter/EOchatBranding.xcconfig`
- each `ShareExtension.*.xcconfig` includes `../Flutter/EOchatBranding.xcconfig`

If this breaks, Xcode may report missing bundle identifiers even though EOCHAT vars exist.

### Profile asymmetry (intentional)
Keep upstream convention:
- Profile uses **Debug** `APP_GROUP_ID` and `APP_URL_SCHEME`
- Profile uses **Release** bundle identifiers

Do not “simplify” this unless you change all targets consistently and validate signing/deeplinks.

---

## 6) Upstream merge workflow (release tags only)

```sh
git fetch upstream --tags
git merge vX.Y.Z
# resolve conflicts
flutter pub get
flutter gen-l10n
flutter analyze
```

Then run targeted iOS sanity check:

```sh
xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration Debug -showBuildSettings
xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration Release -showBuildSettings
xcodebuild -project ios/Runner.xcodeproj -target Runner -configuration Profile -showBuildSettings

xcodebuild -project ios/Runner.xcodeproj -target ShareExtension -configuration Debug -showBuildSettings
xcodebuild -project ios/Runner.xcodeproj -target ShareExtension -configuration Release -showBuildSettings
xcodebuild -project ios/Runner.xcodeproj -target ShareExtension -configuration Profile -showBuildSettings

xcodebuild -project ios/Runner.xcodeproj -target ConduitWidgetExtension -configuration Debug -showBuildSettings
xcodebuild -project ios/Runner.xcodeproj -target ConduitWidgetExtension -configuration Release -showBuildSettings
xcodebuild -project ios/Runner.xcodeproj -target ConduitWidgetExtension -configuration Profile -showBuildSettings
```

Verify resolved values for each target/config:
- `APP_GROUP_ID`
- `APP_URL_SCHEME`
- `PRODUCT_BUNDLE_IDENTIFIER`
- `DEVELOPMENT_TEAM`
- `INFOPLIST_FILE`

---

## 7) Common conflict policy

- `ios/Runner.xcodeproj/project.pbxproj`: keep `$(EOCHAT_*)` indirection
- `ios/Runner/Info.plist`: keep EOchat branding, adopt new upstream keys/structure
- `ios/Podfile.lock`: generated file; take upstream side, regenerate via CocoaPods if needed
- `pubspec.yaml`: usually take upstream version bumps unless intentionally pinned
- `lib/l10n/app_*.arb`: take upstream updates; add EOchat-specific keys instead of redefining upstream semantics

---

## 8) ForkOverrides rule

Every fork runtime behavior should be represented in `ForkOverrides` first.

Call sites should stay minimal (`if (ForkOverrides.someFlag) ...`).

After each upstream merge, re-check each `ForkOverrides` call site to ensure refactors did not make the wrapper ineffective.

---

## 9) Known follow-ups (short list)

- Move iOS permission strings from `Info.plist` into localized `InfoPlist.strings`.
- Review non-EN/NL EO palette translations with native speakers if those locales become product-critical.
