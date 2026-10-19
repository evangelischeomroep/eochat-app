import 'package:checks/checks.dart';
import 'package:conduit/features/chat/widgets/composer_active_tools_badge.dart';
import 'package:conduit/l10n/app_localizations.dart';
import 'package:conduit/l10n/conduit_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('stays a circle inside the 44pt single-line composer row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: conduitLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [ComposerActiveToolsBadge(count: 3)],
              ),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const ValueKey<String>('composer-active-tools-badge')),
    );
    check(size.height).equals(size.width);
    check(size.height).isLessThan(44);
  });
}
