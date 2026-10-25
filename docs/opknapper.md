# Opknapper in EOchat

*Fork-only. Opknapper is EO's AI training game — a question a day, a klus a
week, around the EO building — built as a module of ai.eo.nl's webapp
(`ai-hub-webapp`, `opknapper/`). The app gives it a tab, signs it in, and adds
what a web page on an iPhone can't do itself. Written 15 Oct 2026.*

## What it is in the app

- **A tab,** *Game* (paw print), last in the bottom bar. It has no panel
  of its own: tapping it closes the sidebar and opens the game in the main
  pane. The daily notification lives in Instellingen → Meldingen, as
  *Stuur een melding bij nieuwe opdrachten* with a time, working days only.
- **The game page,** `/opknapper`, inside the drawer shell beside chat,
  notes and channels: the app's own top bar (sidebar button, title, reload)
  over a web view of `ForkOverrides.opknapperUrl`
  (a debug build uses the hub on this machine, `http://localhost:5173/opknapper`;
  a release build `https://ai.eo.nl/opknapper`; for the slice on test, build with
  `--dart-define=OPKNAPPER_URL=https://app-test-aihub.azurewebsites.net/opknapper`).
- **Released on 25 Oct 2026 at 18:00.** From `ForkOverrides.opknapperReleaseAt`
  (18:00 Dutch time, CET since summer time ends that night) the tab, page and
  reminder settings are there for everyone. An app left open shows the tab
  the moment it passes, or on its next return to the foreground. Reminders
  are on unless the user turns them off. `--dart-define=OPKNAPPER_RELEASED=true`
  releases it in one build regardless of the date.
- **Beta mode until then.** Before the release moment the game exists only
  in debug builds and on devices in beta mode. A tester turns it on by
  tapping the app version seven
  times in a row (Instellingen → Over → App-versie); a message confirms it,
  and a *Bètamodus* switch then shows on that page to turn it off (on iOS 26,
  where About is a native sheet, a haptic confirms it and the version row
  says "bètamodus"). Seven taps
  again turn it off too. Nothing hints at it beforehand. Before the release,
  turning beta mode off hides the tab, returns an open game to chat and
  cancels pending reminders. Beta mode is kept per device, so it survives
  updates and sign-outs. After the release it does not affect the game.

## Sign-in

ai.eo.nl sits behind App Service Authentication with Entra ID: an
unauthenticated request is sent to Microsoft and back, and the hub reads the
colleague from Easy Auth's headers. The game's web view uses the app's default
website data store — the same one the EOchat SSO sign-in used — so within one
run of the app Microsoft's session is still there and the game opens signed
in, no prompt.

Both cookies that hold that sign-in are session cookies: Easy Auth's
`AppServiceAuthSession` never carries an expiry, and Microsoft's is persistent
only for a colleague who chose to stay signed in. WebKit drops session cookies
when the app quits, so after every restart the game asked for a sign-in again
(TestFlight, 19 Oct 2026). Now `OpknapperSession`
(`services/opknapper_session.dart`) writes `AppServiceAuthSession*` back with
a 90-day expiry whenever a page of the game's host loads, and the store keeps
it on disk. The server decides how long it counts: `login.cookieExpiration` on
the App Service, 14 days, set with ai-hub-webapp's
`scripts/set-sign-in-lifetime.sh` (the default, 8 hours, would ask every
morning). Logout clears the whole store, this cookie with it; switching to
another EOchat account drops it before the game opens (whose it is sits in
preferences, `opknapper.session.owner`).

When a sign-in is needed after all (the first time, or once the 14 days are
up), the page rewrites Microsoft's authorize request with the colleague's
EOchat address as `login_hint` and `domain_hint=eo.nl`, so there's no account
picker; at most the password and MFA, once. The web view uses the SSO page's
mobile Safari user agent, plus ` EOchatApp/Opknapper`.

Navigation stays inside for the game's host and Microsoft's sign-in hosts.
A link to `chat.eo.nl` (a guide's start link, `?q=` the prompt) opens a new
EOchat chat in the app with the prompt typed; anything else opens in the
browser.

## Reminders

A new opdracht comes each working day. A web view can't take Web Push, so the
app schedules local notifications itself, with no server
(ai-hub-webapp 50, T32's first step).

- **A rolling window:** the next five working days at the chosen time, Dutch
  clock (`Europe/Amsterdam`), rebuilt whenever the game is opened (`seen`) or
  a dagbrief is answered (`answered`, which drops today's). A colleague who
  stays away a week stops hearing from the app until they come back — an
  invitation, never a broadcast.
- **Mondays: the week's notification** at 09:00, when the game's week turns
  (*Met welke collega ben jij gematcht?*), in place of the daily one, also
  when today's question is already answered.
- **Launch: once, Monday 26 Oct 2026 at 14:00** (the game's first Monday,
  after the AI team's morning check), in place of that day's reminders. Scheduled from the first start of the
  build on, also before the release, so it reaches colleagues who don't open
  the app over the weekend. Its tap opens the game as is.
- **On by default,** until the colleague turns it off in Meldingen or the
  page does (`reminders`). Turning it on asks the OS for permission; with the
  default on, the game asks once on its first open (`seen`). A refused
  permission leaves the choice on.
- **A daily tap** opens `/opknapper?open=post`, the weekly and launch taps
  `/opknapper`; if the game is already open the page
  gets an `eochat:open` event instead of a reload.
- Ids `0x4F500000 + day`, so they never collide with message notifications,
  and an account switch (which cancels every notification) is repaired on the
  next start.
- Android needs flutter_local_notifications' scheduled receivers, added to
  the manifest.

## The bridge

The page sees `window.EOchatApp` (`{bridge, platform, handler}`) before its
own scripts run, and calls
`window.flutter_inappwebview.callHandler('eochat', {action, ...})` once
`flutterInAppWebViewPlatformReady` has fired. Only the game's own origin, main
frame, is answered. Unknown actions answer `{ok: false}`.

| action | sends | does |
| --- | --- | --- |
| `hello` | — | `{app, version, platform, bridge, reminders}` |
| `seen` | — | renews the reminder window |
| `answered` | — | today's dagbrief is in; drops today's reminder |
| `reminders` | `enabled`, `time` (`HH:mm`) | turns the reminder on or off; `granted` |
| `haptic` | `style`: light · medium · heavy · selection · success · warning · error | a real haptic |
| `openChat` | `prompt` | a new EOchat chat, prompt typed |
| `openExternal` | `url` | the system browser |
| `shareFile` | `name`, `base64`, `mime` | the share sheet (the bewijs as PDF: a web view can't download a blob) |

The page's side is `opknapper/web/app-bridge.js` in ai-hub-webapp.

## Not done, and why

- **Signing the game in with EOchat's own token** (19 Oct): it would work,
  but only by letting the game's paths past Easy Auth and having the hub
  check Open WebUI tokens itself — a second sign-in system on ai.eo.nl.
  Keeping Easy Auth's cookie is one setting and one file.
- **Push from the server** (an upvote, a klus on a day of its own): needs the
  push entitlement, an APNs key and a device token per colleague (50, T32).
- **The page kept alive across tabs:** leaving `/opknapper` disposes the web
  view; coming back reloads behind the game's own curtain.
- **Built without a compiler.** Neither the Mac's sandbox nor the cloud had
  Flutter, so this was written against the packages' sources (flutter_inappwebview
  6.2.0-beta.3, flutter_local_notifications 22.3.1, timezone 0.11) and never
  analysed or run. First: `flutter pub get`, `flutter analyze`, the sidebar
  widget tests (a new tab may change a destination count), then a device.
