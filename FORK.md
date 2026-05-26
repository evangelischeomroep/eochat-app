# EOchat Fork — Maintenance Guide

EOchat is a long-lived fork of [Conduit](https://github.com/cogwheel0/conduit)
that ships as the EO (Evangelische Omroep) branded chat client. We track
upstream actively and merge releases (`vX.Y.Z` tags) into `main`. Stay close
to upstream — the smaller our divergence, the cheaper merges become.

This document describes the **architectural conventions** the fork uses so
divergence stays cheap. It is not an exhaustive inventory of every changed
line; for that, run `git diff upstream/main` after `git fetch upstream`.

---

## North star: minimise the diff against upstream

Every fork modification carries an ongoing maintenance tax — paid in time
spent resolving merge conflicts. Before adding fork-specific code, prefer in
this order:

1. **Configure** — change behaviour via `ForkOverrides` (Dart) or
   `EOchatBranding.xcconfig` (iOS). No source code edits required.
2. **Wrap** — add a one-line `if (ForkOverrides.flag) ...` around upstream
   code. Survives almost any edit upstream makes inside the wrapped block.
3. **Add** — drop a new fork-only file next to upstream code. New files
   never conflict.
4. **Edit upstream** — last resort. Touch as few lines as possible; document
   the *why* in a comment.

If a fork modification can't fit one of patterns 1–3, treat it as a code
smell and ask whether the upstream design has an extension point we missed.

---

## Where fork-specific code lives

| Concern | Location | Pattern |
|---|---|---|
| Runtime feature flags | `lib/core/config/fork_overrides.dart` | `static const ... = bool.fromEnvironment(...)` overridable via `--dart-define` |
| Startup behaviour | `lib/core/config/fork_startup_watchdog.dart` | Standalone provider, no upstream edits |
| Theme (EO brand palette) | `lib/shared/theme/eochat_palette.dart` | New palette registered in `TweakcnThemes.all` |
| iOS bundle config | `ios/Flutter/EOchatBranding.xcconfig` | xcconfig variables referenced from `project.pbxproj` and `Info.plist` |
| iOS post-install hooks | `ios/Podfile` `post_install` blocks | Tagged `[EOchat] …` in the build phase name |
| App icons, screenshots | `ios/Runner/Assets.xcassets/AppIcon*`, `android/.../mipmap-*`, `assets/icons` | Asset replacement only — no upstream code edits |
| Localised brand strings | Per-locale `lib/l10n/app_*.arb` | New `themePaletteEochat*` keys; upstream `*Conduit*` keys stay vanilla |

When in doubt, grep for `ForkOverrides` and `EOCHAT_` — those two prefixes
should cover most fork-aware code in the project.

---

## ForkOverrides: the configuration boundary

`ForkOverrides` is the single source of truth for runtime fork behaviour.
Every flag has the same shape:

```dart
static const bool showDonationLinks = bool.fromEnvironment(
  'SHOW_DONATION_LINKS',
  defaultValue: false,
);
```

This gives us three things:

1. **The fork value lives in one file** (default in code) — easy to audit.
2. **CI / builds can override** via `--dart-define=SHOW_DONATION_LINKS=true`
   without touching code.
3. **Call sites stay tiny** — a one-line `if (ForkOverrides.flag) ...` is
   the entire diff against upstream at the use-site.

Brand strings (`brandName`, `brandDescription`) follow the same pattern but
return `null` when the override is empty, so the upstream default is used
unmodified. This keeps the call site as `ForkOverrides.brandNameOverride
?? 'Conduit'`, which is robust if upstream ever changes their default.

**Add new fork flags here, not at the call site.**

---

## Theme: separate palette, don't overwrite

Earlier versions of the fork overwrote the `_conduitLight` / `_conduitDark`
variants in `tweakcn_themes.dart` with EO colours. Any upstream tweak to
the Conduit theme caused a conflict.

Now:

- `lib/shared/theme/eochat_palette.dart` owns the EO palette (constants,
  light/dark variants, `eochatPalette` definition).
- `lib/shared/theme/tweakcn_themes.dart` stays close to vanilla. Fork delta
  is one import, one static field, one entry in the `all` list, and a
  legacy-id alias map for users who stored `'conduit'` before the split.
- The default fallback in `color_tokens.dart` is `TweakcnThemes.eochat`.

To tweak EO colours, edit `eochat_palette.dart` only.
To add a *third* fork palette later, mirror that pattern: new file, one
entry in the registry, done.

---

## iOS bundle config: xcconfig is the source of truth

All EOchat-specific iOS identifiers — bundle IDs, app group, URL scheme,
display names, background-task ID, development team — live in
`ios/Flutter/EOchatBranding.xcconfig`. The xcconfig is included by both
`Debug.xcconfig` and `Release.xcconfig`, so every build configuration
(Debug / Release / Profile) sees the same variables.

`project.pbxproj` and the `Info.plist` files reference `$(EOCHAT_*)`
instead of embedding literal strings. To rebrand or spin up a new
flavour, edit one file.

**Caveats:**

- Upstream still uses literal values in `project.pbxproj`, so merging a
  pbxproj change will conflict on these lines. The cost-saver isn't the
  merge — it's that we now have one place to look when the rebrand
  question comes up.
- A few `Info.plist` keys (`CFBundleDisplayName`, `CFBundleName`,
  permission descriptions like `NSCameraUsageDescription`) still embed
  the brand string. `INFOPLIST_KEY_*` build settings override the first
  two at build time; permission strings would need localisation in
  `InfoPlist.strings` to be fully extracted. Worth doing if upstream's
  permission strings drift often.
- `Podfile` carries an EOchat-tagged `post_install` block that generates
  a dSYM for `objective_c.framework`. Tag your future post-install
  additions the same way so the merge tool can spot them.

---

## Localisation

EOchat lives in NL primarily, but we keep all upstream locales. Two
conventions:

- **Don't override upstream keys** to mean different things. When the
  fork needs a new string, add a new key (`themePaletteEochat*`,
  `appTitle`, etc.) rather than redefining an upstream one.
- **Re-run `flutter gen-l10n`** after editing any `.arb` file. The
  generated `app_localizations*.dart` is committed, so the regeneration
  needs to land in the same commit as the ARB edits.

`appTitle` is currently overridden in every locale to read "EOchat"; that
predates the split and is OK because the string is genuinely the app name.

---

## Server, auth, brand surface

These are configured at build time via `ForkOverrides`:

- `preconfigureServer` + `preconfiguredServerUrl` skip the
  server-selection screen and point all installs at `https://chat.eo.nl`.
- `skipSetupScreenWhenPreconfigured` jumps straight to auth.
- `forceSsoOnly` + `preferredSsoProvider` ('microsoft') hide the
  email/password form and prefer the Microsoft SSO button.
- `enableStartupLoadingWatchdog` + `startupLoadingTimeoutMs` (12s) make
  the splash bail out if auth never resolves, so users can recover from a
  bad cached token instead of staring at a spinner.

All have safe defaults — building without any `--dart-define` produces
the EOchat-branded build. Pass overrides only when you need a variant
(e.g., a staging server).

---

## Merging from upstream

The expected workflow:

```sh
git fetch upstream
git merge vX.Y.Z          # always merge a tagged release, not a branch
# resolve conflicts (see below)
flutter pub get
flutter gen-l10n
flutter analyze
# verify iOS still builds — xcconfig changes don't show up in `flutter analyze`
```

**Conflicts you should expect:**

| File | Cause | Resolution rule |
|---|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | Bundle IDs etc. on different literal lines than ours | Keep the `$(EOCHAT_*)` references; the variable definitions are in `EOchatBranding.xcconfig` |
| `ios/Runner/Info.plist` | Brand strings, permissions | Keep EOchat strings; adopt new upstream permission keys with EOchat branding |
| `pubspec.yaml` | Version bumps | Adopt upstream version unless we deliberately pinned |
| `ios/Podfile.lock` | Generated | Take upstream's and rerun `pod install` |
| `lib/l10n/app_*.arb` | New strings or upstream rewordings | Adopt upstream; only override when EOchat needs a different string |

**Conflicts you should NOT expect** (if you do, it's a sign the fork has
drifted from the conventions in this file):

- `lib/shared/theme/tweakcn_themes.dart` — should be near-vanilla.
- `lib/shared/services/brand_service.dart` — only the two `?? 'Conduit'`
  fallbacks should differ.
- Any `lib/features/**` file — feature code should be wrapped via
  `ForkOverrides`, not edited inline.

If you find yourself editing upstream code directly to add a fork
behaviour, stop and add a `ForkOverrides` flag instead.

---

## Known follow-ups

- `chat_page.dart` and `model_selector_sheet.dart` use `ScrollCacheExtent`
  from `package:flutter/rendering.dart`, which only exists on Flutter
  master. Pin Flutter or patch these out depending on the stable channel
  you target.
- iOS permission strings (`NSCameraUsageDescription` etc.) are still
  literal EOchat strings in `Info.plist`. Move to `InfoPlist.strings`
  per locale when upstream next changes them.
- `themePaletteEochat*` translations were added in 11 locales; only
  English and Dutch are owned by the EO team. Other locales are
  best-effort and should be reviewed by native speakers if EOchat ever
  ships in those markets.
