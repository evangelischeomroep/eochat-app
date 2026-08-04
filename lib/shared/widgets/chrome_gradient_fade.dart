import 'package:flutter/widgets.dart';

import '../theme/theme_extensions.dart';

const double kConduitChromeFadeHeight = 30.0;

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
  });

  const ConduitChromeGradientFade.top({
    super.key,
    required this.contentHeight,
    this.fadeHeight = kConduitChromeFadeHeight,
  }) : edge = ConduitChromeFadeEdge.top;

  const ConduitChromeGradientFade.bottom({
    super.key,
    required this.contentHeight,
    this.fadeHeight = kConduitChromeFadeHeight,
  }) : edge = ConduitChromeFadeEdge.bottom;

  final ConduitChromeFadeEdge edge;
  final double contentHeight;
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    final baseColor = context.conduitTheme.surfaceBackground;
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
    final held = baseColor.withValues(alpha: 0.92);
    final clear = baseColor.withValues(alpha: 0.0);

    final isTop = edge == ConduitChromeFadeEdge.top;
    final colors = isTop
        ? [opaque, held, clear]
        : [clear, held, opaque];
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
              colors: colors,
              stops: stops,
            ),
          ),
        ),
      ),
    );
  }
}
