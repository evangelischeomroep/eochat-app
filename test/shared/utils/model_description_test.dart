import 'package:checks/checks.dart';
import 'package:conduit/core/models/model.dart';
import 'package:conduit/shared/utils/model_description.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers the top-level description, reduced to its first line', () {
    const model = Model(
      id: 'a',
      name: 'A',
      description: '  Snelle assistent voor dagelijks werk.\n\nMeer tekst.',
    );
    check(singleLineModelDescription(model))
        .equals('Snelle assistent voor dagelijks werk.');
  });

  test('falls back to the Open WebUI info.meta.description path', () {
    const model = Model(
      id: 'a',
      name: 'A',
      metadata: {
        'info': {
          'meta': {'description': '## Redeneermodel\nVoor lastige vragen.'},
        },
      },
    );
    check(singleLineModelDescription(model)).equals('Redeneermodel');
  });

  test('strips list markers and collapses whitespace', () {
    const model = Model(
      id: 'a',
      name: 'A',
      description: '- Geschikt   voor\tbeeld en tekst',
    );
    check(singleLineModelDescription(model))
        .equals('Geschikt voor beeld en tekst');
  });

  test('returns null when every candidate is blank', () {
    const model = Model(
      id: 'a',
      name: 'A',
      description: '  \n ',
      metadata: {
        'info': {
          'meta': {'description': ''},
        },
      },
    );
    check(singleLineModelDescription(model)).isNull();
  });
}
