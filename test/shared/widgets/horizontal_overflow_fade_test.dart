import 'package:checks/checks.dart';
import 'package:conduit/shared/widgets/horizontal_overflow_fade.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'overflow fade masks the child alpha instead of painting a colour',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 40,
            child: HorizontalOverflowFade(child: SizedBox.expand()),
          ),
        ),
      );

      // Fork: a painted overlay can only match an opaque surface. The mask has
      // no colour of its own, so it sits on glass, cards and highlights alike.
      final fade = find.byType(HorizontalOverflowFade);
      final mask = tester.widget<ShaderMask>(
        find.descendant(of: fade, matching: find.byType(ShaderMask)),
      );
      check(mask.blendMode).equals(BlendMode.dstIn);
      check(
        tester.widgetList<DecoratedBox>(
          find.descendant(of: fade, matching: find.byType(DecoratedBox)),
        ),
      ).isEmpty();
    },
  );
}
