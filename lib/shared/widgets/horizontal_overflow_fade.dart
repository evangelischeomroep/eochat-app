import 'package:flutter/widgets.dart';

/// A restrained trailing edge cue for horizontally scrollable utility rows.
///
/// Fork: masks the child's own alpha at the trailing edge instead of painting
/// a themed colour over it. A painted overlay can only match an opaque
/// surface; on iOS 26 the composer shell is translucent Liquid Glass, so the
/// overlay read as a tinted box beside the last pill in both light and dark.
/// Masking needs no colour at all and matches any backdrop by construction.
class HorizontalOverflowFade extends StatelessWidget {
  const HorizontalOverflowFade({
    super.key,
    required this.child,
    this.width = 28,
  });

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fadeStart = bounds.width <= width
            ? 0.0
            : 1 - (width / bounds.width);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x1AFFFFFF),
          ],
          stops: [0, fadeStart, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
