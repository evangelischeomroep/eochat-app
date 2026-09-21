---
name: eochat-maintenance
description: Maintain the EOchat iOS/Android app (Flutter fork of Conduit) without repeating past mistakes. Use this for any change to EOchat's UI or native iOS layer (icon sizes, padding, colours, sheets, composer, header, attachment panel, fades, fonts), for porting polish into the native Swift surfaces on iOS 26, for verifying work on the iOS Simulator with screenshots, for syncing the fork with upstream cogwheel0/conduit release tags, and for getting a clean main plus a green TestFlight build. Trigger it whenever the user reports something that looks off in the app, asks "are we up to date with upstream", or wants a polish item done and verified, even if they do not say "skill", "fork" or "simulator".
---

# EOchat maintenance

EOchat is `evangelischeomroep/eochat-app`, a Flutter fork of Conduit
(`cogwheel0/conduit`). `FORK.md` in the repo root is the playbook for the fork
mechanics (where fork code lives, allowed inline edits, merge workflow). This
skill layers the practical lessons from the 2026-09 polish rounds on top of
it: how to find where something is really rendered, how to verify on the
simulator, and which traps cost hours before.

Read `FORK.md` §1–§3 and §8 once per session before touching upstream files.

## Priorities (Lennart, 2026-09-18)

A neat, unified UI beats a small upstream diff. Editing upstream Dart or Swift
is acceptable when a polish item only lands that way, because AI-assisted
merges make the diff cheap to carry. Still try config → wrapper → new file
first (FORK.md §1), and register every inline edit in FORK.md §3 with a
one-line "why", so the next merge knows what to keep. The voice-mode screen is
declared perfect. Do not touch it.

## Workflow for a polish item

1. **Reproduce and locate.** The user usually sends a screenshot. Before
   editing tokens, find out whether the surface is Flutter or native Swift.
   On iOS 26 the model selector, the settings/profile sheet, the attachment
   (+) panel, sheet close buttons, the header toolbar and its ⋯ menu are
   UIKit, so Flutter theme tokens never reach them. The map is in
   `references/native-surfaces.md`. A token-only change that "should" fix a
   native surface silently does nothing on the phone; that was round 2's
   main waste.
2. **Prefer shared tokens when they reach the surface.** `IconSize`,
   `Spacing`, `AppTypography`, `kConduitNativeSingleActionSymbolExtent`,
   `kCupertinoNativeMenuItemSymbolExtent`, and the per-action
   `iosSymbolSize` hook cover most sizing. For native Swift, colours come
   from `NativeSheetTheme.shared` (synced from Dart), so use those instead of
   hard-coded UIColors.
3. **One item per commit**, conventional message, and register it in the
   same commit: FORK.md §3 entry for each upstream file touched, plus a row in
   `docs/ui-polish-backlog.md` (round table: item, commit, notes). Fill the
   hash with a follow-up docs commit, never by amending: amending rewrites
   the hash you just wrote.
4. **Verify before claiming done.** Warm analyzer, the targeted test files,
   and a simulator screenshot in light and dark. See "Verification" below.
5. **Ship.** Push main, wait for the three workflows, rerun a flaky analyze
   once, and report with the commit hashes and what was verified on device.

Ask yourself at step 1 what the user actually sees. Twice the reported
problem had a cause one level down from the obvious one: a fade "with the
wrong colour" was a painted overlay on translucent Liquid Glass, so no colour
could ever match, and a dark attachment panel in light mode was a stale
keyboard appearance, not a theme bug. Fix causes, and write the cause into
the FORK.md entry.

## Verification

Run these in this order; each catches a different class of mistake.

```bash
flutter analyze --no-pub --fatal-infos    # run twice; the first cold run reports 80–170 phantom issues
flutter test test/path/to/affected_test.dart
```

The full suite has a known-failing baseline (38 tests in 9 files, listed in
`docs/ui-polish-backlog.md` under "Still open"). Compare against that list
instead of expecting green; a new failure outside the list is yours.

Then look at it. `references/simulator-harness.md` explains the login
constraint (SSO only, the simulator keeps the session across rebuilds), the
scripts in `scripts/sim/` (tap, accessibility press, screenshot, crop, offset
calibration), and the surfaces that need the accessibility route rather than
a synthetic click. Capture both appearances for anything colour-related;
several items looked fine in one mode only.

## Upstream sync

Follow FORK.md §6 (release tags only, never `main`). Lessons from the v4.1.6
sync:

- Check `git log --grep "Sync with cogwheel0/conduit"` and
  `.conduit-sync-version` before merging. The sync may already have landed
  via the scheduled task, with your commits rebased on top and their hashes
  changed. Remap hashes in the backlog by commit subject.
- After a merge, run `flutter gen-l10n` (missing getters otherwise) and
  `dart run tool/validate_arb_locales.dart`. New upstream ARB keys need an
  entry in all 12 non-English locales; Dutch gets a translation, the rest
  copy English. The L10n workflow treats a missing key as an error.
- Confirm all `ForkOverrides` call sites survived, and that the full test
  suite fails the same baseline set, not more.
- The unreleased upstream commits after the latest tag wait for the next tag.

## CI and shipping

Workflows: `analyze.yml` (`--fatal-infos`), `l10n.yml` (path-filtered, skips
when no ARB changed), `testflight.yml` (Xcode Cloud, "Add to TestFlight
(AI-team)"). Watch with:

```bash
gh run list -R evangelischeomroep/eochat-app --commit $(git rev-parse HEAD) \
  --json name,status,conclusion -q '.[] | "\(.name)=\(.status)/\(.conclusion)"'
```

Pass the full SHA; a short hash returns nothing. The riverpod_lint plugin
occasionally emits a transient info on upstream code that passed before;
`gh run rerun --failed <id>` once is the fix, not a code change. If a local
build dirties `ios/Podfile.lock` or `project.pbxproj`, check the diff is a
checksum or Xcode formatting only, then commit it once (see pitfalls);
restoring it on every run just hides it.

Direct pushes to main are allowed for this workflow (rule bypass is logged),
but leave main clean and equal to origin/main when you stop.

## Shell and tooling traps

`references/pitfalls.md` lists the ones that broke commits or wasted runs:
zsh word-splitting, quotes in commit messages, `set -e` and pipelines,
relative paths with `simctl`, decimal commas in AppleScript output, the
Simulator window living on another display.

## Open, not started

Nunito Sans as body font (brand font). Plan: bundle under `assets/fonts`,
add to `pubspec.yaml` `fonts:`, set `AppTypography._primaryFont` (one hook
used ~19×), check line heights; optionally native tier via `UIAppFonts` in
Info.plist, a `UIFontMetrics` helper for the Swift sites, and
`CNButtonConfig.labelFontFamily` for the pill. Needs Lennart's go and a font
source (Google Fonts build or licensed brand files).
