import 'package:conduit/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

import '../../../shared/theme/theme_extensions.dart';

/// Fork: inline count inside the composer's `+` button, replacing the quick-pill
/// row (see `ForkOverrides.replaceComposerQuickPillsWithCounter`). Shows how
/// many tools, capabilities and integrations from the `+` menu are on.
class ComposerActiveToolsBadge extends StatelessWidget {
  const ComposerActiveToolsBadge({super.key, required this.count, this.color});

  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = context.conduitTheme;
    final label = AppLocalizations.of(context)!.composerActiveToolsCount(count);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('composer-active-tools-badge'),
        // Keep the count compact inside the shared outlined button.
        constraints: const BoxConstraints(
          minWidth: IconSize.chip,
          minHeight: IconSize.chip,
          maxHeight: IconSize.chip,
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTypography.labelSmallStyle.copyWith(
            color: color ?? theme.textPrimary,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
