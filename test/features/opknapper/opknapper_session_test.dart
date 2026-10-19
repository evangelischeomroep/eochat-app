import 'package:checks/checks.dart';
import 'package:conduit/features/opknapper/services/opknapper_session.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final game = Uri.parse('https://ai.eo.nl/opknapper');

  group('isOpknapperSignedInPage', () {
    test('counts a page of the game host', () {
      check(
        isOpknapperSignedInPage(
          Uri.parse('https://ai.eo.nl/opknapper?open=post'),
          game,
        ),
      ).isTrue();
      check(isOpknapperSignedInPage(Uri.parse('https://AI.eo.nl/'), game))
          .isTrue();
    });

    test('skips sign-in endpoints, other hosts and plain http', () {
      for (final page in [
        'https://ai.eo.nl/.auth/login/aad/callback',
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
        'https://ai.test.eo.nl/opknapper',
      ]) {
        check(isOpknapperSignedInPage(Uri.parse(page), game)).isFalse();
      }
      final local = Uri.parse('http://localhost:5173/opknapper');
      check(isOpknapperSignedInPage(local, local)).isFalse();
    });
  });

  test("opknapperSessionCookies keeps only the host's Easy Auth parts", () {
    final cookies = [
      Cookie(name: 'AppServiceAuthSession', value: 'a', domain: 'ai.eo.nl'),
      Cookie(name: 'AppServiceAuthSession1', value: 'b', domain: '.ai.eo.nl'),
      Cookie(name: 'AppServiceAuthSession', value: 'c', domain: 'eo.nl'),
      Cookie(name: 'AppServiceAuthSession', value: 'd'),
      Cookie(name: 'AppServiceAuthSession2', value: ''),
      Cookie(name: 'Nonce', value: 'n', domain: 'ai.eo.nl'),
    ];
    check(
      opknapperSessionCookies(cookies, 'AI.eo.nl').map((c) => c.value),
    ).deepEquals(['a', 'b', 'd']);
  });

  test('a kept sign-in is dropped only for another known account', () {
    check(
      opknapperSessionBelongsToSomeoneElse(
        keptFor: 'a@eo.nl',
        current: 'b@eo.nl',
      ),
    ).isTrue();
    check(
      opknapperSessionBelongsToSomeoneElse(
        keptFor: 'A@eo.nl',
        current: ' a@EO.nl ',
      ),
    ).isFalse();
    check(
      opknapperSessionBelongsToSomeoneElse(keptFor: 'a@eo.nl', current: null),
    ).isFalse();
    check(
      opknapperSessionBelongsToSomeoneElse(keptFor: null, current: 'a@eo.nl'),
    ).isFalse();
  });
}
