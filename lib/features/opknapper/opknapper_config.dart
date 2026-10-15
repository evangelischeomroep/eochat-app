// Fork-only (EOchat): Opknapper, EO's AI training game, as a sidebar tab.
//
// The game itself is a web module of ai.eo.nl (ai-hub-webapp, `opknapper/`).
// The app shows it in a web view, signs it in with the colleague's EO account
// through ai.eo.nl's own Entra sign-in (App Service Authentication), and owns
// what a web view can't: local reminders for the daily letter, haptics, and
// handing a prompt to a new EOchat chat. Strings are Dutch on purpose: the
// game is Dutch only, and keeping them here keeps the ARB files upstream's.

import '../../core/config/fork_overrides.dart';

abstract final class OpknapperConfig {
  /// Shell route for the game page; lives beside chat, notes and channels.
  static const String routePath = '/opknapper';
  static const String routeName = 'opknapper';

  /// Name the page calls: `window.flutter_inappwebview.callHandler('eochat', {...})`.
  static const String bridgeHandlerName = 'eochat';

  /// Version of the bridge contract, so the page can tell what it may ask.
  static const int bridgeVersion = 1;

  static Uri get gameUri => Uri.parse(ForkOverrides.opknapperUrl.trim());

  /// The game's origin. Only messages from here reach the bridge.
  static String get gameOrigin => gameUri.origin;

  /// Hosts the web view may navigate to itself: the game and the Microsoft
  /// sign-in it passes through. Everything else opens outside the game.
  static bool isInGameHost(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == gameUri.host.toLowerCase()) return true;
    return _signInHosts.any((h) => host == h || host.endsWith('.$h'));
  }

  static const List<String> _signInHosts = [
    'login.microsoftonline.com',
    'login.microsoft.com',
    'login.live.com',
    'login.windows.net',
    'autologon.microsoftazuread-sso.com',
    'msauth.net',
    'msftauth.net',
    'aadcdn.msftauth.net',
    'device.login.microsoftonline.com',
  ];

  /// Microsoft's authorize endpoint, where a login hint saves the colleague
  /// the account picker.
  static bool isMicrosoftAuthorize(Uri uri) =>
      uri.host.toLowerCase() == 'login.microsoftonline.com' &&
      uri.path.toLowerCase().contains('/oauth2/') &&
      uri.path.toLowerCase().endsWith('/authorize');

  /// EOchat's own web address: a guide's start link opens a new chat in the
  /// app instead of the browser.
  static bool isEOchatWebLink(Uri uri) {
    final server = Uri.tryParse(ForkOverrides.normalizedPreconfiguredServerUrl);
    return server != null &&
        server.host.isNotEmpty &&
        uri.host.toLowerCase() == server.host.toLowerCase();
  }
}

/// What a colleague reads in the app around the game.
abstract final class OpknapperStrings {
  static const String name = 'Game';
  static const String gameName = 'Opknapper';
  static const String tagline = 'Dagelijks oefenen met AI';
  static const String searchHint = 'Zoeken';
  static const String reminderTitle = 'Stuur een melding bij nieuwe opdrachten';
  static String reminderSubtitle(String time) => 'Werkdagen om $time';
  static const String reminderOff = 'Uit';
  static const String reminderTime = 'Tijdstip';
  static const String reminderPickerTitle = 'Melding om';
  static const String reminderFootnote =
      'Elke werkdag staat er een nieuwe opdracht voor je klaar in Opknapper: '
      'een korte vraag, een oefening of een peiling, in een paar minuten '
      'gedaan. Je krijgt één melding per werkdag, alleen als er nog iets op '
      'je wacht. Kom je een week niet langs, dan wordt het vanzelf stil.';
  static const String permissionDenied =
      'Meldingen staan uit voor EOchat. Zet ze aan in Instellingen.';
  static const String loadFailed = 'De game laadt niet.';
  static const String retry = 'Opnieuw';
  static const String reload = 'Herladen';
  static const String openInBrowser = 'Open in browser';
  static const String channelName = 'Opknapper';
  static const String channelDescription = 'Meldingen bij nieuwe opdrachten';

  /// A calm line a working day; never urgent (T32's lean, R49).
  static const List<(String, String)> reminders = [
    ('Er ligt post voor je', 'Er staat een nieuwe opdracht voor je klaar.'),
    (
      'Nieuwe opdracht',
      'Een korte opdracht van twee minuten, in de postvakjes.',
    ),
    ('Post in de hal', 'De hond heeft je opdracht al gevonden.'),
    ('Je opdracht van vandaag', 'Een korte vraag ligt voor je klaar.'),
    ('Er ligt post voor je', 'Even langs de postvakjes?'),
  ];

  /// Times the settings offer for the daily notification.
  static List<String> timeChoices(String current) {
    final choices = <String>[
      for (var h = 7; h <= 12; h++) ...[
        '${h.toString().padLeft(2, '0')}:00',
        if (h < 12) '${h.toString().padLeft(2, '0')}:30',
      ],
    ];
    if (!choices.contains(current)) {
      choices
        ..add(current)
        ..sort();
    }
    return choices;
  }
}
