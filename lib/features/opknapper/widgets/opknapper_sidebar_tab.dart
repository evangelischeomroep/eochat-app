// Fork-only (EOchat): the sidebar's Opknapper tab. Small on purpose: one row
// opens the game in the main pane, and the reminder lives here, where the
// app's own settings live, rather than inside the game.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/shared/widgets/platform_ui/platform_ui.dart';
import 'package:conduit_core/features/navigation/models/sidebar_navigation_model.dart';

import '../../../core/services/haptic_service.dart';
import '../../../shared/services/navigation_service.dart';
import '../../../shared/theme/theme_extensions.dart';
import '../../../shared/utils/platform_scroll_physics.dart';
import '../../../shared/widgets/adaptive_date_time_picker.dart';
import '../../../shared/widgets/sidebar_layout_contract.dart';
import '../../navigation/providers/sidebar_tab_scroll_registry.dart';
import '../../navigation/widgets/conversation_tile.dart';
import '../../notifications/services/local_notification_service.dart';
import '../opknapper_config.dart';
import '../services/opknapper_reminders.dart';

class OpknapperSidebarTab extends ConsumerStatefulWidget {
  const OpknapperSidebarTab({super.key});

  @override
  ConsumerState<OpknapperSidebarTab> createState() =>
      _OpknapperSidebarTabState();
}

class _OpknapperSidebarTabState extends ConsumerState<OpknapperSidebarTab>
    with
        AutomaticKeepAliveClientMixin,
        SidebarTabScrollRegistration<OpknapperSidebarTab> {
  final ScrollController _scrollController = ScrollController();
  bool _onGamePage = false;

  /// Held so dispose removes the listener from the router it was added to.
  late final Listenable _routeInformation =
      NavigationService.router.routeInformationProvider;

  @override
  SidebarTabId get sidebarTabId => SidebarTabId.opknapper;

  @override
  ScrollController get sidebarScrollController => _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _onGamePage = _isGamePath(_currentPath);
    _routeInformation.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _routeInformation.removeListener(_onRouteChanged);
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentPath =>
      NavigationService.router.routeInformationProvider.value.uri.path;

  static bool _isGamePath(String path) => path == OpknapperConfig.routePath;

  void _onRouteChanged() {
    final onGame = _isGamePath(_currentPath);
    if (onGame != _onGamePage) setState(() => _onGamePage = onGame);
  }

  void _openGame() {
    ConduitHaptics.selectionClick();
    closeSidebarDrawerIfOverlay(context);
    NavigationService.router.go(OpknapperConfig.routePath);
  }

  Future<void> _toggleReminder(bool value) async {
    final reminders = ref.read(opknapperRemindersProvider.notifier);
    final enabled = await reminders.setEnabled(value);
    if (value && !enabled && mounted) {
      // Permission was refused: say where to change it, once.
      final opened = await ref
          .read(localNotificationServiceProvider)
          .openSystemSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(OpknapperStrings.permissionDenied)),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final current = ref.read(opknapperRemindersProvider).time;
    final picked = await showAdaptiveTimePicker(
      context,
      initial: current,
      title: OpknapperStrings.reminderPickerTitle,
    );
    if (picked == null || !mounted) return;
    await ref.read(opknapperRemindersProvider.notifier).setTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.conduitTheme;
    final settings = ref.watch(opknapperRemindersProvider);

    final list = ListView(
      controller: _scrollController,
      primary: false,
      padding: EdgeInsets.only(
        top: sidebarTabContentTopPadding(context),
        bottom: sidebarTabContentBottomPadding(context),
      ),
      physics: platformAlwaysScrollablePhysics(context),
      children: [
        ChatStyleSidebarTile(
          key: const ValueKey<String>('opknapper-open-game'),
          selected: _onGamePage,
          onTap: _openGame,
          semanticLabel:
              '${OpknapperStrings.name}. ${OpknapperStrings.tagline}',
          child: SidebarListTileContent(
            title: OpknapperStrings.name,
            subtitle: OpknapperStrings.tagline,
            selected: _onGamePage,
            emphasizeTitle: true,
            leading: Icon(
              Platform.isIOS ? CupertinoIcons.hammer : Icons.handyman_outlined,
              size: IconSize.listItem,
              color: theme.iconPrimary,
            ),
            trailing: Icon(
              Platform.isIOS
                  ? CupertinoIcons.chevron_right
                  : Icons.chevron_right_rounded,
              size: IconSize.xs,
              color: theme.iconSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, Spacing.md, 16, 4),
          child: Text(
            OpknapperStrings.reminderSection,
            style: AppTypography.labelStyle.copyWith(
              color: theme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ChatStyleSidebarTile(
          key: const ValueKey<String>('opknapper-reminder-toggle'),
          selected: false,
          onTap: settings.loaded
              ? () => unawaited(_toggleReminder(!settings.enabled))
              : null,
          semanticLabel: OpknapperStrings.reminderTitle,
          child: SidebarListTileContent(
            title: OpknapperStrings.reminderTitle,
            subtitle: settings.enabled
                ? OpknapperStrings.reminderSubtitle(settings.timeLabel)
                : OpknapperStrings.reminderOff,
            selected: false,
            trailing: AdaptiveSwitch(
              value: settings.enabled,
              onChanged: settings.loaded
                  ? (value) => unawaited(_toggleReminder(value))
                  : null,
              semanticLabel: OpknapperStrings.reminderTitle,
            ),
          ),
        ),
        if (settings.enabled)
          ChatStyleSidebarTile(
            key: const ValueKey<String>('opknapper-reminder-time'),
            selected: false,
            onTap: () => unawaited(_pickTime()),
            semanticLabel:
                '${OpknapperStrings.reminderTime}: ${settings.timeLabel}',
            child: SidebarListTileContent(
              title: OpknapperStrings.reminderTime,
              selected: false,
              trailing: Text(
                settings.timeLabel,
                style: AppTypography.listTitleStyle.copyWith(
                  color: theme.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, Spacing.sm, 16, Spacing.md),
          child: Text(
            OpknapperStrings.reminderFootnote,
            style: AppTypography.bodySmallStyle.copyWith(
              color: theme.textSecondary.withValues(alpha: Alpha.secondary),
              height: 1.4,
            ),
          ),
        ),
      ],
    );

    final primary = PrimaryScrollController(
      controller: _scrollController,
      child: list,
    );
    return context.usesCupertinoChrome
        ? CupertinoScrollbar(controller: _scrollController, child: primary)
        : Scrollbar(controller: _scrollController, child: primary);
  }
}
