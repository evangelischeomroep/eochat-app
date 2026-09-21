import 'package:checks/checks.dart';
import 'package:conduit/core/models/model.dart';
import 'package:conduit/l10n/app_localizations.dart';
import 'package:conduit/l10n/conduit_localizations.dart';
import 'package:conduit/shared/theme/app_theme.dart';
import 'package:conduit/shared/theme/tweakcn_themes.dart';
import 'package:conduit/shared/theme/theme_extensions.dart';
import 'package:conduit/shared/widgets/conduit_components.dart';
import 'package:conduit/shared/widgets/horizontal_overflow_fade.dart';
import 'package:conduit/shared/widgets/model_list_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _reasoningModel = Model(
  id: 'reasoning-model',
  name: 'Reasoning model',
  supportedParameters: ['reasoning'],
  metadata: {
    'info': {
      'meta': {
        'description': 'Denkt langer na over lastige vragen.\nTweede regel hoort niet in de lijst.',
        'tags': [
          {'name': 'reasoning'},
        ],
      },
    },
  },
);

Future<ConduitThemeExtension> _pumpTile(
  WidgetTester tester, {
  required bool isSelected,
}) async {
  late ConduitThemeExtension theme;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(TweakcnThemes.conduit),
      localizationsDelegates: conduitLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            theme = context.conduitTheme;
            return ConduitCard(
              child: ModelListTile(
                model: _reasoningModel,
                isSelected: isSelected,
                onTap: () {},
              ),
            );
          },
        ),
      ),
    ),
  );
  return theme;
}

void main() {
  testWidgets('subtitle is the one-line model description, not the tags', (
    tester,
  ) async {
    await _pumpTile(tester, isSelected: false);

    // Fork: ForkOverrides.modelSelectorShowsDescription replaces the tag
    // chip row with the Open WebUI description, clipped to a single line.
    final subtitle = tester.widget<Text>(
      find.text('Denkt langer na over lastige vragen.'),
    );
    check(subtitle.maxLines).equals(1);
    check(subtitle.overflow).equals(TextOverflow.ellipsis);
    expect(find.byType(HorizontalOverflowFade), findsNothing);
    expect(find.text('reasoning'), findsNothing);
  });

  testWidgets('selected row highlight paints against the card surface', (
    tester,
  ) async {
    final theme = await _pumpTile(tester, isSelected: true);
    final highlighted = Color.alphaBlend(
      theme.buttonPrimary.withValues(alpha: 0.1),
      theme.cardBackground,
    );
    final surfaceHighlighted = Color.alphaBlend(
      theme.buttonPrimary.withValues(alpha: 0.1),
      theme.surfaceBackground,
    );

    check(highlighted).not((it) => it.equals(surfaceHighlighted));

    // The highlight itself paints against the card surface.
    final tile = find.byType(ModelListTile);
    final containers = tester.widgetList<Container>(
      find.descendant(of: tile, matching: find.byType(Container)),
    );
    final rowBackgrounds = containers
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color);
    check(rowBackgrounds).contains(highlighted);
  });
}
