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
  static const String reminderTitle = 'Meldingen van de game';
  static String reminderSubtitle(String time) =>
      'Maandag om 09:00 en donderdag om $time';
  static const String reminderDailyTitle = 'Ook elke werkdag';
  static const String reminderDailySubtitle =
      'Een melding bij elke nieuwe vraag';
  static const String reminderOff = 'Uit';
  static const String reminderTime = 'Tijdstip';
  static const String reminderPickerTitle = 'Melding om';
  static const String reminderFootnote =
      'Op maandag begint er een nieuwe week in Opknapper, met een nieuwe '
      'Weekchallenge; op donderdag krijg je een seintje voordat de week om '
      'is. Je hebt altijd een week om alles af te maken, dus je hoeft '
      'niet elke dag te komen. Wil je toch bij elke nieuwe vraag een melding, '
      'zet dan "Ook elke werkdag" aan. Kom je een week niet langs, dan wordt '
      'het vanzelf stil.';
  static const String permissionDenied =
      'Meldingen staan uit voor EOchat. Zet ze aan in Instellingen.';
  static const String loadFailed = 'De game laadt niet.';
  static const String retry = 'Opnieuw';
  static const String reload = 'Herladen';
  static const String openInBrowser = 'Open in browser';
  static const String channelName = 'Opknapper';
  static const String channelDescription = 'Meldingen over de game';

  /// The daily option's notification, Tuesday, Wednesday and Friday; never
  /// urgent (T32's lean, R49).
  static const (String, String) dailyReminder = (
    'Er staat een nieuwe vraag klaar in de game!',
    'Je vindt hem in de postvakjes.',
  );

  /// Monday 09:00, when the game's week turns and a new weekbrief and
  /// ansichtkaart pairing are there.
  static const (String, String) weeklyReminder = (
    'Met welke collega ben jij gematcht?',
    'Er staat een nieuwe week klaar in de game. Met wie ga jij hem deze week '
        'voltooien?',
  );

  /// Thursday at the chosen time, before the week turns on Monday at 09:00.
  /// Says what may still wait, never that something was missed: it can't
  /// know what the colleague did.
  static const (String, String) weekEndReminder = (
    'De week is bijna om',
    'Kijk in je postvakjes of er nog iets op je wacht; '
        'maandag 9:00 verdwijnen ze.',
  );

  /// Once, on the game's first Monday, in place of that day's reminders.
  static const (String, String) launchReminder = (
    'Speel vanaf vandaag onze game Opknapper in de app!',
    'Word AI-vaardig en AI-wijs met leuke vragen, stellingen, puzzels en '
        'opdrachten. Elke werkdag en elke week nieuwe content.',
  );

  /// Times the settings offer for Thursday's and the daily notifications.
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
