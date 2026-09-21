# Which EOchat surfaces are native Swift on iOS 26

Verified on the iPhone 17 Pro simulator, iOS 26, 2026-09-18. When
`PlatformUiCapabilities.usesNativeIOS26` is true these are UIKit, driven from
Dart through `NativeSheetBridge`. Flutter theme tokens, `ForkOverrides` that
only change Dart widgets, and Dart padding constants do not reach them.

| Surface | Swift | Dart side that configures it |
|---|---|---|
| Model selector sheet | `ios/Runner/NativeSheetBridge.swift` (`NativeModelSelectorTableViewController`, `NativeModelSelectorCell`) | `lib/features/chat/widgets/model_selector_sheet.dart` (groups, `showsPin`) |
| Settings / profile sheet | `NativeProfileMenuTableViewController` in `NativeSheetBridge.swift` | `lib/features/navigation/widgets/sidebar_user_pill.dart` (rows, `sfSymbol` names) |
| Attachment (+) panel | `ios/Runner/NativeKeyboardAttachmentBridge.swift` (`UIInputView(inputViewStyle: .keyboard)`, `NativeKeyboardAttachmentTile`) | `modern_chat_input.dart` native attachment actions |
| Sheet close buttons | `makeNativeSheetCloseBarButton` in `ios/Runner/NativeSheetUIFoundation.swift` | — |
| Header toolbar and ⋯ menu | `ConduitNativeToolbarActionGroup`, `CNPopupMenuButton` (`cupertino_native_better`) | `lib/shared/widgets/adaptive_toolbar_components.dart`, `chat_page.dart` |
| Composer shell | Liquid Glass backdrop (`AdaptiveGlassBackdrop`) under Flutter content | `modern_chat_input.dart` `_buildComposerShell` |

Still Flutter on iOS 26: composer contents (text field, pills, mic, send,
recording controls), message list and its footer actions, sidebar, settings
sub-pages (Chats, quick actions, appearance), voice-mode screen.

## Theme flow into Swift

Dart calls `NativeSheetBridge.syncTheme` → `NativeSheetTheme.shared`
(`background`, `surface`, `accent`, `isDark`, …). Use those in Swift instead
of literal colours so the EO palette and theme switches carry over. Cell
styling helpers: `NativeSheetSettingsStyle.applyCellStyle(_:)` and
`applyContentStyle(&content)`.

## Sizing constants that matter

- `IconSize.appBar` / `floatingButton` = `md` (20). Native header glyphs use
  `kConduitNativeSingleActionSymbolExtent` (18); per-action override via
  `ConduitNativeToolbarAction.iosSymbolSize` (temporary-chat eye = 14).
- Native menu items: `kCupertinoNativeMenuItemSymbolExtent` (17).
- `CNSymbol` defaults to 24pt if no size is passed; always pass one.
- Model tiles: `kModelTileLeadingExtent` (28), avatar `NativeModelAvatarView(side: 28)`.
- Composer circles 32pt inside a 44pt target; `_composerVoiceSymbolExtent`
  = 14 on iOS so the waveform balances the mic.

## Known limits (do not retry these)

- Attachment panel appearance follows the keyboard's `keyboardAppearance`.
  Flutter's `EditableText` re-sends its config only on keyboardType,
  obscureText or viewId changes, so toggling the theme while the composer is
  focused leaves the keyboard and panel stale until refocus.
  `overrideUserInterfaceStyle` on the input view and window-trait overrides
  are ignored. Only reproducible by switching appearance mid-session with the
  composer focused; not worth fighting.
- `accessoryView` alpha on a `UITableViewCell` is ignored by UIKit. Reserve
  the slot with a spacer view instead of fading the checkmark.
- A painted colour overlay (fade, scrim) can only match an opaque surface.
  Over Liquid Glass, mask the content's alpha (`ShaderMask` + `dstIn`).
- The soft hyphen (`­`) is the tool for long Dutch labels in native
  tiles ("Server­bestanden"); native cells do not wrap.
