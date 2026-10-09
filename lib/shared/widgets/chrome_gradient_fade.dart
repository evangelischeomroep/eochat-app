import 'package:flutter/widgets.dart';

import '../theme/theme_extensions.dart';

const double kConduitChromeFadeHeight = 24.0;

enum ConduitChromeFadeEdge { top, bottom }

/// Gradient-only chrome edge used when custom Flutter bars replace native bars.
///
/// This intentionally does not blur. It gives transparent custom chrome the
/// same soft scroll-edge separation as the adaptive bars while keeping the
/// underlying content readable.
class ConduitChromeGradientFade extends StatelessWidget {
  const ConduitChromeGradientFade({
    super.key,
    required this.edge,
    required this.contentHeight,
    this.fadeHeight = kConduitChromeFadeHeight,
    this.backgroundColor,
    this.solidBehindChrome = false,
  });

  const ConduitChromeGradientFade.top({
    super.key,
    required this.contentHeight,
    this.fadeHeight = kConduitChromeFadeHeight,
    this.backgroundColor,
    this.solidBehindChrome = false,
  }) : edge = ConduitChromeFadeEdge.top;

  const ConduitChromeGradientFade.bottom({
    super.key,
    required this.contentHeight,
    this.fadeHeight = kConduitChromeFadeHeight,
    this.backgroundColor,
  }) : edge = ConduitChromeFadeEdge.bottom,
       solidBehindChrome = false;

  final ConduitChromeFadeEdge edge;
  final double contentHeight;
  final double fadeHeight;
  final Color? backgroundColor;

  /// Keeps the fade near-opaque across [contentHeight] and only softens it
  /// in the [fadeHeight] strip beyond, like iOS's "hard" scroll-edge style.
  /// For bars with a title over scrolling rows, where the default ramp lets
  /// text read through behind the title.
  final bool solidBehindChrome;

  @override
  Widget build(BuildContext context) {
    final baseColor = backgroundColor ?? context.conduitTheme.surfaceBackground;
    final height = contentHeight + fadeHeight;
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    // The gradient spans `contentHeight + fadeHeight`, but only the fade band
    // should ramp. Deriving the stop from the actual ratio keeps the scrim
    // near-opaque across the whole chrome band regardless of how tall the
    // safe-area inset makes it; hardcoded stops let content stay legible
    // behind the controls on taller devices.
    final contentStop = (contentHeight / height).clamp(0.0, 1.0).toDouble();

    final opaque = baseColor.withValues(alpha: 1.0);
    // Fork: 0.92 painted a distinct block behind the app bar in dark mode;
    // 0.7 reads as a soft scrim while keeping the controls legible.
    final held = baseColor.withValues(alpha: 0.7);
    final clear = baseColor.withValues(alpha: 0.0);

    final isTop = edge == ConduitChromeFadeEdge.top;
    final colors = isTop ? [opaque, held, clear] : [clear, held, opaque];
    final stops = isTop
        ? [0.0, contentStop, 1.0]
        : [0.0, 1.0 - contentStop, 1.0];

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Fork: solidBehindChrome stays fully opaque across the
              // content band (same ratio-derived stop as the default ramp)
              // instead of easing to the softer `held` alpha, so a title
              // over scrolling rows stays legible.
              colors: solidBehindChrome
                  ? (isTop ? [opaque, opaque, clear] : [clear, opaque, opaque])
                  : colors,
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}
