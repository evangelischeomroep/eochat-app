# Pitfalls that cost time before

Each of these produced a broken commit, a silent no-op, or a wasted run.

## Git and commits

- Commit messages with inner double quotes broke an inline `git commit -m`
  under zsh. Write the message to a file and use `git commit -F`.
- Amending to insert the commit hash into a doc changes the hash. Record the
  hash in a separate docs commit.
- `set -e` does not catch a failing command inside `cmd | tail`. Some polish
  commits went in with failing tests because of this. Run the test command
  alone or use `set -o pipefail`.
- zsh does not word-split `$FILES`; use `${=FILES}` or an array.
- `flutter run` rewrites `ios/Podfile.lock` (checksum) and
  `ios/Runner.xcodeproj/project.pbxproj` (Xcode reformatting). Restore both
  before committing.
- After an upstream sync landed via the scheduled task, local polish commits
  were rebased and their hashes changed. Remap doc references by subject.

## Analyzer and tests

- Cold `flutter analyze` reports 80–170 phantom issues (riverpod_lint plugin
  warm-up). The warm rerun is the truth. CI has the same flake; rerun once.
- The full suite has a fixed failing baseline (38 tests, 9 files; list in
  `docs/ui-polish-backlog.md`). Compare, do not expect green.
- After merging upstream, `flutter gen-l10n` or the analyzer reports missing
  localisation getters.
- Widget tests that assert a decoration inside a fade or tile must filter
  for the decoration they mean; children (chips) carry their own
  `DecoratedBox`.

## Simulator

- `xcrun simctl io booted screenshot` rejects relative paths and fails
  silently in scripts. Resolve absolute paths first
  (`S=$(cd "$(dirname "$0")" && pwd)`).
- Changing appearance with `simctl ui appearance` dismisses transient native
  menus and popovers. Capture first, then toggle.
- System Events `click at` inside the Simulator window fails with -25211.
  Use CGEvent clicks (`simtap`) for Flutter widgets and `AXPress`
  (`press.sh`) for UIKit controls (menus, table rows, switches).
- The Simulator window moves between displays and Spaces. Hard-coded screen
  offsets go stale; recalibrate with `calibrate.sh` from a known control's
  accessibility frame. With the window on another Space, System Events sees
  0 windows and taps are blocked while headless screenshots keep working.
- AppleScript formats numbers with a decimal comma in the Dutch locale
  ("881,0"). Coerce to integer before printing (the bundled scripts do).
- `press.sh "<label>"` matches the first accessibility description that
  *contains* the text. "Chats" matched a different row's description; use
  the most specific substring, or a coordinate tap from a fresh screenshot.
- A blind "dismiss" tap can land inside a panel that opened in the meantime
  and toggle a setting (image generation was switched on this way). Close
  panels by their own control, and screenshot when unsure.
- Quick pills in the composer only show when the corresponding quick action
  is enabled in Settings → Chats → Snelkoppelingen in chat. A fresh
  simulator has none enabled, so composer-row bugs from the user's phone may
  not reproduce until you enable one.
- A Flutter switch did not toggle on a synthetic click at its centre;
  `press.sh` on the row label worked.
- Killing the detached `flutter run` shut the simulator down once; check
  `xcrun simctl list devices booted` before assuming taps reach anything.
- In the sidebar the avatar sits where the hamburger sits in the chat
  header (≈38, 86). A second blind tap there opens the settings sheet
  instead of closing the sidebar. Screenshot between navigation taps.
- `sips -c` silently ignores a crop whose offset plus height equals the
  image height; `crop.sh` clamps for this.

## Server and login

- chat.eo.nl has the password form disabled; `/auths/signin` returns 403
  for the review account. Only Microsoft SSO works. Lennart signs in once;
  the simulator keeps the session across rebuilds, so never erase the
  simulator to "start clean".
