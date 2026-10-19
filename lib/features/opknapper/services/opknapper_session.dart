// Fork-only (EOchat): keeps the game signed in when the app restarts.
//
// ai.eo.nl signs a colleague in through App Service Authentication (Easy
// Auth), whose cookie, AppServiceAuthSession, never carries an expiry. WebKit
// keeps such a session cookie only while the app runs, as a browser keeps it
// until it quits, and Microsoft's own sign-in cookie is a session cookie too
// unless the colleague chose to stay signed in. So every cold start meant
// signing in to the game again. Once the game has loaded signed in, the same
// cookie is written back with an expiry, and the web view's store keeps it on
// disk.
//
// The server stays the judge: it accepts the cookie as long as its sign-in
// lifetime allows (14 days, set by ai-hub-webapp's
// scripts/set-sign-in-lifetime.sh), then sends the colleague to Microsoft
// once, and the new cookie is kept in turn. Signing out of EOchat clears the
// whole web view store, this cookie with it. Switching to another EOchat
// account doesn't, so the kept sign-in remembers whose it is and is dropped
// before anyone else opens the game.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:conduit_core/utils/debug_logger.dart';

import '../../../platform/webview_cookie_helper.dart';
import '../opknapper_config.dart';

const String _scope = 'opknapper/session';

/// Easy Auth's session cookie. A large session is split over
/// `AppServiceAuthSession1`, `2`, …, so every part counts.
const String opknapperSessionCookiePrefix = 'AppServiceAuthSession';

/// Whether [page] is a page of the game's own host, past Easy Auth's sign-in
/// endpoints: a page there that loads means a signed-in colleague.
@visibleForTesting
bool isOpknapperSignedInPage(Uri page, Uri game) =>
    page.scheme == 'https' &&
    game.scheme == 'https' &&
    page.host.isNotEmpty &&
    page.host.toLowerCase() == game.host.toLowerCase() &&
    !page.path.startsWith('/.auth/');

/// The game host's own Easy Auth cookies among [cookies].
@visibleForTesting
List<Cookie> opknapperSessionCookies(List<Cookie> cookies, String host) => [
  for (final cookie in cookies)
    if (cookie.name.startsWith(opknapperSessionCookiePrefix) &&
        webViewCookieBelongsToExactHost(cookie.domain, host.toLowerCase()) &&
        (cookie.value?.toString() ?? '').isNotEmpty)
      cookie,
];

/// Whether a sign-in kept for [keptFor] must go before [current] opens the
/// game: only when both accounts are known and differ, so an account that is
/// still loading doesn't cost anyone their sign-in.
@visibleForTesting
bool opknapperSessionBelongsToSomeoneElse({String? keptFor, String? current}) {
  final kept = keptFor?.trim().toLowerCase() ?? '';
  final now = current?.trim().toLowerCase() ?? '';
  return kept.isNotEmpty && now.isNotEmpty && kept != now;
}

abstract final class OpknapperSession {
  static const String _ownerKey = 'opknapper.session.owner';

  /// How long the phone keeps the cookie: longer than the server accepts it,
  /// and renewed each time the game loads.
  static const Duration keepFor = Duration(days: 90);

  /// Before the web view opens: drops a sign-in kept for another EOchat
  /// account ([account] is the current one's address), so the game never
  /// opens as someone else.
  static Future<void> prepare({required String? account}) async {
    final game = OpknapperConfig.gameUri;
    if (!isWebViewSupported || game.scheme != 'https') return;
    await WebViewCookieHelper.runSerializedDataOperation(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!opknapperSessionBelongsToSomeoneElse(
          keptFor: prefs.getString(_ownerKey),
          current: account,
        )) {
          return;
        }
        final cookies = opknapperSessionCookies(
          await CookieManager.instance().getCookies(
            url: WebUri('${game.origin}/'),
          ),
          game.host,
        );
        final dropped =
            await WebViewCookieHelper.deleteCookieIdentitiesForOriginUnlocked(
              game.origin,
              cookies.map(WebViewCookieHelper.cookieIdentity).toSet(),
            );
        if (dropped) await prefs.remove(_ownerKey);
        DebugLogger.auth(
          'Dropped the game sign-in kept for another account',
          scope: _scope,
          data: {'dropped': dropped},
        );
      } catch (error) {
        DebugLogger.warning(
          'session-drop-failed',
          scope: _scope,
          data: {'errorType': error.runtimeType.toString()},
        );
      }
    });
  }

  /// After [page] loaded: keeps the game's sign-in on disk, for [account].
  static Future<void> keep(Uri page, {required String? account}) async {
    final game = OpknapperConfig.gameUri;
    if (!isWebViewSupported || !isOpknapperSignedInPage(page, game)) return;
    await WebViewCookieHelper.runSerializedDataOperation(() async {
      try {
        final manager = CookieManager.instance();
        final url = WebUri('${game.origin}/');
        final cookies = opknapperSessionCookies(
          await manager.getCookies(url: url),
          game.host,
        );
        if (cookies.isEmpty) return;
        final expires = DateTime.now().add(keepFor).millisecondsSinceEpoch;
        var kept = 0;
        for (final cookie in cookies) {
          // Same cookie, same attributes, now with an expiry. A host-only
          // cookie stays host-only: a domain would make it a second cookie
          // beside the one Easy Auth set (and Android doesn't report one).
          final domain = cookie.domain;
          final written = await manager.setCookie(
            url: url,
            name: cookie.name,
            value: cookie.value.toString(),
            path: cookie.path ?? '/',
            domain: domain != null && domain.startsWith('.') ? domain : null,
            expiresDate: expires,
            isSecure: cookie.isSecure ?? true,
            isHttpOnly: cookie.isHttpOnly ?? true,
            sameSite: cookie.sameSite,
          );
          if (written) kept++;
        }
        final owner = account?.trim().toLowerCase() ?? '';
        if (kept > 0 && owner.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_ownerKey, owner);
        }
        DebugLogger.auth(
          'Kept the game sign-in',
          scope: _scope,
          data: {'cookies': kept},
        );
      } catch (error) {
        DebugLogger.warning(
          'session-keep-failed',
          scope: _scope,
          data: {'errorType': error.runtimeType.toString()},
        );
      }
    });
  }
}
