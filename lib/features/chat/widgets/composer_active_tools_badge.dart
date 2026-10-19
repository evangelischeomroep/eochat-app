import 'package:conduit/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

import '../../../shared/theme/theme_extensions.dart';

/// Fork: counter beside the composer's `+` button, replacing the quick-pill
/// row (see `ForkOverrides.replaceComposerQuickPillsWithCounter`). Shows how
/// many tools, capabilities and integrations from the `+` menu are on.
class ComposerActiveToolsBadge extends StatelessWidget {
  const ComposerActiveToolsBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = context.conduitTheme;
    final label = AppLocalizations.of(context)!.composerActiveToolsCount(count);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('composer-active-tools-badge'),
        // Fixed height: the compact composer row hands down a loose height,
        // and an aligned Container would stretch into an oval to fill it.
        constraints: const BoxConstraints(
          minWidth: IconSize.chip,
          minHeight: IconSize.chip,
          maxHeight: IconSize.chip,
        ),
        // A single digit fits the chip square; only wider counts need
        // padding, which turns the circle into a pill.
        padding: EdgeInsets.symmetric(horizontal: count < 10 ? 0 : Spacing.xs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.buttonPrimary,
          borderRadius: BorderRadius.circular(AppBorderRadius.round),
        ),
        child: Text(
          '$count',
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTypography.labelSmallStyle.copyWith(
            color: theme.buttonPrimaryText,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
