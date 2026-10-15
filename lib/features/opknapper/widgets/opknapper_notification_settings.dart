// Fork-only (EOchat): the Game's daily notification, on the Notifications
// settings page. One switch and a time, with what to expect as the footer.

import 'dart:async';

import 'package:conduit/shared/widgets/platform_ui/platform_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/adaptive_date_time_picker.dart';
import '../../../shared/widgets/utility_components.dart';
import '../../notifications/services/local_notification_service.dart';
import '../../profile/widgets/settings_page_scaffold.dart';
import '../opknapper_availability.dart';
import '../opknapper_config.dart';
import '../services/opknapper_reminders.dart';

/// Nothing while the Game is hidden (not released, not in beta mode).
class OpknapperNotificationSettings extends ConsumerWidget {
  const OpknapperNotificationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(opknapperAvailableProvider)) return const SizedBox.shrink();
    final settings = ref.watch(opknapperRemindersProvider);

    return Column(
      children: [
        settingsSectionGap,
        InsetGroupedList(
          footer: OpknapperStrings.reminderFootnote,
          children: [
            UtilityRow(
              key: const ValueKey<String>('opknapper-reminder-toggle'),
              title: OpknapperStrings.reminderTitle,
              subtitle: settings.enabled
                  ? OpknapperStrings.reminderSubtitle(settings.timeLabel)
                  : null,
              toggled: settings.enabled,
              trailing: AdaptiveSwitch(
                value: settings.enabled,
                onChanged: settings.loaded
                    ? (value) => unawaited(_toggle(context, ref, value))
                    : null,
              ),
              onTap: settings.loaded
                  ? () => unawaited(_toggle(context, ref, !settings.enabled))
                  : null,
            ),
            if (settings.enabled)
              UtilityRow(
                key: const ValueKey<String>('opknapper-reminder-time'),
                title: OpknapperStrings.reminderTime,
                status: Text(settings.timeLabel),
                showChevron: true,
                onTap: () => unawaited(_pickTime(context, ref)),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final enabled = await ref
        .read(opknapperRemindersProvider.notifier)
        .setEnabled(value);
    if (!value || enabled || !context.mounted) return;
    // Permission was refused: say where to change it.
    final opened = await ref
        .read(localNotificationServiceProvider)
        .openSystemSettings();
    if (!opened && context.mounted) {
      AdaptiveSnackBar.show(
        context,
        message: OpknapperStrings.permissionDenied,
        type: AdaptiveSnackBarType.warning,
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await showAdaptiveTimePicker(
      context,
      initial: ref.read(opknapperRemindersProvider).time,
      title: OpknapperStrings.reminderPickerTitle,
    );
    if (picked == null) return;
    await ref.read(opknapperRemindersProvider.notifier).setTime(picked);
  }
}
