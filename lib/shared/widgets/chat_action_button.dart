import 'package:material_ui/material_ui.dart';
import 'package:conduit/shared/theme/theme_extensions.dart';
import 'package:conduit/core/services/haptic_service.dart';

class ChatActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ChatActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.conduitTheme;
    final handleTap = onTap == null
        ? null
        : () {
            ConduitHaptics.selectionClick();
            onTap!();
          };

    // Fork: footer glyphs sit in secondary ink at the standard 20pt extent
    // so they read as one quiet family under the answer text.
    final foreground = handleTap == null
        ? theme.iconSecondary.withValues(alpha: 0.45)
        : theme.iconSecondary;

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: Semantics(
        button: true,
        enabled: handleTap != null,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handleTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Icon(icon, size: IconSize.md, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
