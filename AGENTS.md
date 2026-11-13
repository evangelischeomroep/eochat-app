# eochat-app

EOchat is the EO's build of Conduit, a Flutter client for Open WebUI, preconfigured for chat.eo.nl with Microsoft sign-in and shipped to iOS and Android. It is a long-lived fork of [cogwheel0/conduit](https://github.com/cogwheel0/conduit): most code is upstream's, and every fork change has to survive the next upstream merge.

## What we never compromise on

1. **Stay as close to upstream as possible.** A small diff means cheap merges and fewer regressions. Before adding fork behaviour, prefer in this order: configure (`ForkOverrides`, `EOchatBranding.xcconfig`), wrap (a small `if (ForkOverrides.flag)` around upstream), add a fork-only file, and only then edit an upstream file, as small as possible. For UI polish a neat, unified UI beats a small diff, so an upstream edit is acceptable when the item only lands that way.
2. **Every inline edit to an upstream file is registered.** Add an entry to `FORK.md` §3 with a one-line why, so the next merge knows what to keep. If a new fork behaviour needs another upstream file, document why in the PR.
3. **Fork runtime behaviour goes through `ForkOverrides`.** Call sites stay minimal (`if (ForkOverrides.someFlag) ...`). After each upstream merge, re-check every call site, because a refactor can make the wrapper ineffective.

## Ways to hurt yourself

1. **Renaming the Android Kotlin directories.** The source path stays upstream's `android/app/src/main/kotlin/app/cogwheel/conduit/`, while the package is `nl.eo.eochat`. Renaming the directories to match costs a large merge tax on every sync. Keep native identifiers (method channels such as `nl.eo.eochat/cookies`, broadcast actions, package-qualified `R` references) in sync across Kotlin and Dart.
2. **Hardcoding iOS identifiers.** All EOchat IDs live in `ios/Flutter/EOchatBranding.xcconfig`; `project.pbxproj` and the plists reference `$(EOCHAT_...)`. The ShareExtension and ConduitWidget xcconfigs must include it, or Xcode reports missing bundle identifiers. Profile uses the Debug app group and URL scheme with the Release bundle identifiers, like upstream; do not "simplify" that unless you change all targets and validate signing and deep links.
3. **Fixing a native surface with Flutter tokens.** On iOS 26 the model selector, the settings sheet, the attachment panel, sheet close buttons and the header toolbar are UIKit, so a theme-token change silently does nothing there. Check `.claude/skills/eochat-maintenance/references/native-surfaces.md` first.
4. **Merging upstream `main`.** Sync with upstream release tags only; unreleased commits after the latest tag wait for the next tag.
5. **Pushing to `main` carelessly.** Every push to `main` becomes a TestFlight build for the AI team. Leave `main` clean and equal to `origin/main` when you stop.
6. **Shipping a version Apple already approved.** Once a version is approved its train closes, and builds under it bounce with ITMS-90186 / ITMS-90062. `ios/ci_scripts/ci_post_clone.sh` ships such a build as the next patch on Xcode Cloud; when the TestFlight job leaves a notice that the version differs, bump `pubspec.yaml` to match. `.conduit-sync-version` records the upstream release and is not bumped with it.

## Running locally

Clone with `--recursive` or run `git submodule update --init --recursive`: `third_party/mermaid` holds path dependencies, so `flutter pub get` fails without it. `openwebui-src` and `hermes-src` are API references only; nothing builds them.

Generated Dart files are git-ignored, so run `build_runner` in every workspace member that uses it (the root and `packages/conduit_core`) after a fresh clone or a pull; until then the analyzer reports errors in files you never touched. After an upstream merge, also run `flutter gen-l10n`.

The iOS simulator build targets Apple Silicon only: `XCODE_XCCONFIG_FILE="$PWD/ios/Flutter/ArmOnly.xcconfig" flutter run -d ios`. The app signs in with SSO only; the simulator keeps the session across rebuilds. `ForkOverrides` values can be overridden per build with `--dart-define`.

Requirements, Pigeon codegen and troubleshooting are in `docs/BUILDING.md`. It is upstream's file, so its clone URL and store links are Conduit's.

## Done means green

A change is done when this passes for what you touched:

```bash
flutter analyze --no-pub --fatal-infos lib
flutter test test/path/to/affected_test.dart
```

`analyze.yml` runs the analyzer on every push and pull request; `l10n.yml` runs `dart run tool/verify_arb_descriptions.dart` and `dart run tool/validate_arb_locales.dart` when an ARB file changes. Upstream's `ci.yml` is deliberately not carried. The first cold analyzer run reports 80 to 170 phantom issues, so run it twice. The full test suite has a known-failing baseline, listed in `docs/ui-polish-backlog.md` under "Still open"; compare against it instead of expecting green, a new failure outside the list is yours.

## Documentation

Most changes need no documentation; agents can read the code.

- When you sync with upstream or touch an upstream file, read `FORK.md`: where fork code lives, the registered inline edits, the merge workflow and the conflict policy.
- When you change the UI or the native iOS layer, verify on the simulator, sync with upstream or ship, follow the `eochat-maintenance` skill in `.claude/skills/eochat-maintenance/`.
- When you work on the Opknapper tab, read `docs/opknapper.md`.
- `README.md` describes EOchat, not Conduit; on an upstream sync, keep our side of it.
- When a documented decision changes, rewrite the text; a doc describes the current state.

## How it works

Upstream is a pub workspace: the Flutter app lives in `lib/`, and most non-UI code (auth, database, sync, services, providers, Hermes, direct connections) lives in `packages/conduit_core`, next to `conduit_markdown` and `conduit_theme`. Those packages stay Flutter-free and cannot import app code, so `ForkOverrides` hooks belong in `lib/` only; inside the packages the fork carries branding strings and nothing else. `ForkOverrides` preconfigures `https://chat.eo.nl`, skips the setup screen and allows Microsoft SSO only. A push to `main` triggers Xcode Cloud, and `testflight.yml` adds the build to the AI-team TestFlight group; `app-store-submit.yml` submits a build for App Review on demand.

## Where code lives

- `lib/core/config/fork_overrides.dart` - the fork's runtime flags.
- `lib/shared/theme/eochat_palette.dart` - the EO palette.
- `ios/Flutter/EOchatBranding.xcconfig` - iOS bundle identifiers, app groups, URL schemes and display names.
- `lib/features/opknapper/` - the Opknapper tab.
- `scripts/asc_testflight.py` - the App Store Connect calls behind the TestFlight and submit workflows.

Search for `ForkOverrides`, `EOCHAT_` and `nl.eo.eochat` to find fork code quickly.

## Taste

- **One polish item per commit**, with a conventional message, registered in the same commit: a `FORK.md` §3 entry for each upstream file touched and a row in `docs/ui-polish-backlog.md`. Fill in the hash with a follow-up docs commit, never by amending, because amending changes the hash you just wrote.
- **ARB files follow upstream.** Take upstream's updates and add EOchat-specific keys instead of redefining upstream semantics. A new upstream key needs an entry in every locale: Dutch gets a translation, the others copy English.
- **Upstream's conventions apply** (logging through `DebugLogger`, credentials in secure storage, endpoints checked against `openwebui-src/`, model output treated as untrusted); they are in `docs/BUILDING.md`.
