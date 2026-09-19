# EOchat UI polish backlog

Screenshot review of the EOchat iOS app (TestFlight 4.1.5, light + dark)
against the ChatGPT iOS app as the consistency benchmark. Written so a Claude
Code session can pick items up one by one.

Status: round 1 (items 0-19) landed on `main` 2026-09-16 and round 2 (items
20-33) on 2026-09-17, see the two "Done" tables below. Nothing is open except
the leftovers listed at the bottom. Next step is a screenshot pass on the
TestFlight build that contains round 2 (Settings → About shows the build
number) to confirm the changes and collect a round 3.

## Ground rules (read FORK.md first)

- Stay inside the fork's allowed surface: `lib/shared/theme/eochat_palette.dart`,
  `ForkOverrides`, ARB values, and the files listed in FORK.md §3. Prefer token
  changes over widget rewrites: a palette or `Spacing`/`IconSize` tweak survives
  the next upstream sync; a restructured widget tree usually does not. When you
  do touch a new upstream file, add it to FORK.md §3 in the same commit.
- One item per commit. Screenshot before/after in both themes (Settings →
  About shows the build number; confirm you are looking at the build you think
  you are).
- `flutter analyze --fatal-infos` must stay green. Run the tests of the files
  you touch; a set of unrelated failures is pre-existing (see bottom).
- Native iOS 26 glass draws its own material (shadow, tint ring) on the
  app-bar pills, sheet close button and scroll FAB. Flutter tokens cannot
  remove that; only backing colours/borders behind it can be tuned.

---

## Done (round 1, 2026-09-16)

| # | Item | Commit | Notes |
|---|------|--------|-------|
| P0 | 4pt spacing scale, 12/16/pill radii, real secondary text, neutral borders, `listTitleStyle` | `71f2f281` | `textSecondary` now derives from `mutedForeground`; light `6B6472`, dark `9C8FB0`. No Flutter shadows existed on pills/close button. |
| 1 | Dark settings cards surface | `eec39941` | dark `card` `2E1B4A`, light `F2E6E6` |
| 2 | User bubble text = primary ink | `7d5c045d` | removed a fork deviation |
| 3 | NL translations | `733988be` | 206 keys. `workspace*` (~250 admin strings) still English. |
| 4 | Hermes row line icon | `543baff8` | |
| 5 | Settings icon optical weight | `a398f8b7` | |
| 6 | Model pill middle-ellipsis | — | Already `useMiddleEllipsis: false` in v4.1.5 and build 67 *includes* that fix, yet the pill still showed `Standaa…evolen)`. Another path renders it, see item 33. |
| 7 | Only active quick pills | `5acd16a1` | `ForkOverrides.hideInactiveComposerQuickPills`. Covers web/image/filters, **not** tool-server pills, see item 28. |
| 8 | Humanised tool summary + metadata style | `8e8c4883` | `lib/shared/utils/tool_display_names.dart`, 3 new ARB keys |
| 9 | "Bestanden" → "Serverbestanden" | `ba33e56f` | |
| 10 | Hide per-message model header for active model | `c540d4e6` | `ForkOverrides.hideRedundantModelHeader` |
| 11 | Scroll FAB solid backing | `63b81867` | |
| 12 | Group compose + more | — | Upstream already groups them natively (`ConduitNativeToolbarActionGroup`, ≤3 actions). |
| 13 | Channels tab glyph | `81c93ab6` | `number.square` |
| 14 | One-line settings subtitles | `763922ca` | |
| 15 | Calmer attachment sheet | `3d0cf26a` | check-circle instead of switch; 64×44 filled pills |
| 16 | Neutral light surfaces | — | Skipped: team A/B call. Partly covered by the P0 border change. |
| 17 | Softer chrome scrim | `bace51b6` | held 0.7, fade 24 |
| 18 | Context menu icon weight | — | Flutter menu already uses one `IconSize`; the heavy menu in screenshots is native, see item 23. |
| 19 | Chat-list row density | `41305d92` | |

## Done (round 2, 2026-09-17)

| # | Item | Commit | Notes |
|---|------|--------|-------|
| 20 | Fades use the scaffold / shell colour | `e6260de4` | chat_page scrims take `CupertinoTheme.scaffoldBackgroundColor` on iOS; composer pill fade uses `surfaceContainerHighest`. On iOS 26 the composer shell is native glass, so the pill fade is an approximation there. |
| 21 | Icon-to-control ratio | `7fb352b6` | `IconSize.appBar`/`floatingButton` → 20; composer add glyph 20 (iOS) / 24 (Android), expand glyph 20. Native iOS 26 toolbar symbols were already 18pt (`kConduitNativeSingleActionSymbolExtent`), so the app-bar change only reaches the Flutter fallback and Android. Fixed the pre-existing icon-extent test. |
| 22 | Dark hairlines | `004dbd50` | dark `border` `2A1E40`; composer shell drops its outline in dark on the Flutter (non-glass) path. The ring seen on iOS 26 pills/composer is the native glass material and stays. |
| 23 | Native menu icon weight | `f701f577` | `CNSymbol` defaulted to 24pt in every native popup menu; now 17pt via `kCupertinoNativeMenuItemSymbolExtent` (all native menus app-wide). Pin/archive rows use outline glyphs. |
| 24 | Model sheet rhythm | `d3512475` | Actions are rows in one grouped card (`_ActionGroup`), same leading tile (28pt after item 31), same insets/type as `ModelListTile`; value subtitle moved to the trailing side in `textSecondary`. Code gaps were already 16pt; the visual gap was the 76pt cards. |
| 25 | Model row trailing column | `5eb0ccdb` | fixed 20pt check slot on every `ModelListTile` row |
| 26 | Assistant footer weights | `284c85e8` | `ChatActionButton` 20pt `iconSecondary`; outline speaker; sources chip filled card colour, `w500` secondary label |
| 27 | Composer placeholder contrast | `dbe3cc10` | `textTertiary` at full alpha |
| 28 | Inactive tool-server pills | `ea0aa69c` | same `hideInactiveComposerQuickPills` guard in the tool-server branch |
| 29 | Light-mode tints | `dab82a02` | Cupertino page/bar = `neutralTone00` (white light / `140A24` dark), matching the Material scaffold; cards stay the one grey step. Item 20's scrim follows automatically. |
| 30 | Plain sheet close button | `e5330613` | `ForkOverrides.plainSheetCloseButton` (default true) takes the existing non-glass `IconButton` path |
| 31 | Model avatars | `679aed09` | `kModelTileLeadingExtent` = 28, radius `sm`, shared with the sheet action rows |
| 32 | Empty-state greeting | — | Left as is (matches ChatGPT); revisit only if it gains a second line. |
| 33 | Model pill middle-ellipsis (closes 6) | `c6318db3` | Root cause: the native iOS 26 pill title is fitted in Dart with a middle ellipsis (`resolveConduitNativeModelSelectorLabel`), independent of `useMiddleEllipsis`. Now drops a trailing parenthesised qualifier, then tail-truncates: `Standaard` / `Standa…`. |

## Done (round 3, 2026-09-18): native iOS 26 port

Simulator check (iPhone 17 Pro, iOS 26) showed that the model sheet, the
settings sheet, the attachment (+) panel and the sheet close buttons are
native Swift on iOS 26, so items 4, 5, 15, 24, 25, 30 and 31 never reached
the iPhone build. Ported where it matters (Swift files now in FORK.md §3).

| # | Item | Commit | Notes |
|---|------|--------|-------|
| 24/25/31 (native) | Model sheet: 28pt tiles, fixed check accessory, grouped action rows with a visible surface | `f786bd75` | `NativeModelSelectorTableViewController` / `…Cell` in `NativeSheetBridge.swift` |
| 30 (native) | Plain close glyph on native sheets | `2b2460e1` | `makeNativeSheetCloseBarButton`, `hidesSharedBackground` on iOS 26 |
| 4/5 (native) | Settings row glyphs: sliders, single bubble, cube for Hermes | `1a8fa083` | symbols come from `sidebar_user_pill.dart` |
| 34 | "Serverbestanden" wrapped mid-word in the attachment tile | `dcb1d2be` | soft hyphen in the NL value |
| 35 | Attachment panel rendered dark in light mode | `d22c93ca`, `5206a8cc`, `953e7c8e` | Not a panel bug: the panel follows the keyboard appearance, and Flutter's `EditableText` only re-sends `keyboardAppearance` on reconnect, so a theme switch while the composer keeps focus leaves keyboard and panel in the old style until refocus. Overrides removed; documented in FORK.md. Only reproducible by toggling appearance mid-session. |
| 36 | Attachment panel selection was system blue | `e5d3b8d5` + `feeb35b9` | `tintColor` = `NativeSheetTheme.shared.accent` on the panel and on each tile at construction (tiles read it before joining the hierarchy) |
| 37 | Pin glyph on every featured model row | `6b7336be` + `d3d52307` | featured list is the pinned list; glyph hidden there (native + Flutter), kept in "more models". Also fixed the check slot (spacer, not alpha). |

Verified on device (both themes) after round 2: 1, 10, 13, 14, 20, 21, 22, 23,
26, 27, 29, 33. Header ⋯ menu anchors over the model pill (UIKit placement),
left alone.

## Done (round 4, 2026-09-19): composer and header details

Lennart's review of the simulator build. Voice-mode screen explicitly left
untouched ("perfect").

| # | Item | Commit | Notes |
|---|------|--------|-------|
| 38 | Temporary-chat eye too big for its circle | `c1f2b62e` | `ConduitNativeToolbarAction.iosSymbolSize`; eye at 14pt (shared extent stays 18) |
| 39 | Waveform outweighed the mic | `9991f8c7` | `_composerVoiceSymbolExtent` = 14 on iOS |
| 40 | Add glyph too far from the shell edge | `6d744006` | 2pt leading inset when the leading control is the add button; optical edges of glyph and trailing circle both 14pt from the shell (test updated `c6adfb8b`) |
| 41 | Single-line text / placeholder sat low | `2748273e` | content padding 2pt top / 6pt bottom |
| 42 | Recording controls | `e46d125f` | stop control is a 32pt filled circle in a 44pt target like the send button, no border, 16pt glyph. Verify on device: not yet screenshotted (simulator window unavailable at the time). |

---

## Still open from round 1

- `workspace*` NL translations (~250 admin-only strings) still English.
- Pre-existing failing tests: a full `flutter test` on `main` fails 38 tests
  in 9 files, identically before and after round 2 (verified at `cb44b10d`
  and `c6318db3`): `hermes_router_policy_test` (17), `adaptive_auth_flow_test`
  (9), `release_notes_sheet_test` (6, expects the "Review Conduit" brand
  string), and one each in `sidebar_page_test`, `hermes_run_transport_test`,
  `openwebui_direct_completion_relay_test`, `server_connection_adaptive_test`,
  `polish_localization_test`, `external_voice_entrypoints_test`. None are UI
  polish; the composer icon-extent failure was fixed with item 21.

## Not worth touching (would fight upstream)

- Replacing the bottom tab bar with a drawer to mirror ChatGPT: core Conduit
  navigation decision.
- Rewriting the composer to single-row: upstream's two-row layout hosts tool
  chips; item 7/28 fix the chips instead.
- Native `UIMenu` for every context menu: large surface, low visual gain.
- Removing native glass from the app bar: it is the iOS 26 platform look and
  upstream is built around it; tune what sits behind it (items 20-22).
