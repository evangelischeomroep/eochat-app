// Fork-only (EOchat): the Game's daily notification as a group of the native
// Notifications sheet (iOS 26), the counterpart of
// `widgets/opknapper_notification_settings.dart`.

import '../../core/services/native_sheet_bridge.dart';
import 'opknapper_config.dart';
import 'services/opknapper_reminders.dart';

/// Control ids the native rows send.
const nativeOpknapperReminderId = 'opknapper-reminder';
const nativeOpknapperReminderTimeId = 'opknapper-reminder-time';

NativeSheetSectionConfig buildNativeOpknapperReminderSection(
  OpknapperReminderSettings settings,
) {
  return NativeSheetSectionConfig(
    footer: OpknapperStrings.reminderFootnote,
    items: [
      NativeSheetItemConfig(
        id: nativeOpknapperReminderId,
        title: OpknapperStrings.reminderTitle,
        sfSymbol: 'graduationcap',
        kind: NativeSheetItemKind.toggle,
        value: settings.enabled,
      ),
      NativeSheetItemConfig(
        id: nativeOpknapperReminderTimeId,
        title: OpknapperStrings.reminderTime,
        sfSymbol: 'clock',
        kind: NativeSheetItemKind.dropdown,
        value: settings.timeLabel,
        options: [
          for (final time in OpknapperStrings.timeChoices(settings.timeLabel))
            NativeSheetOptionConfig(id: time, label: time),
        ],
      ),
    ],
  );
}
