# Opknapper in EOchat

*Fork-only. Opknapper is EO's AI training game — a question a day, a klus a
week, around the EO building — built as a module of ai.eo.nl's webapp
(`ai-hub-webapp`, `opknapper/`). The app gives it a tab, signs it in, and adds
what a web page on an iPhone can't do itself. Written 15 Oct 2026.*

## What it is in the app

- **A tab,** *Game* (graduation cap), last in the bottom bar. It has no panel
  of its own: tapping it closes the sidebar and opens the game in the main
  pane. The daily notification lives in Instellingen → Meldingen, as
  *Stuur een melding bij nieuwe opdrachten* with a time, working days only.
- **The game page,** `/opknapper`, inside the drawer shell beside chat,
  notes and channels: the app's own top bar (sidebar button, title, reload)
  over a web view of `ForkOverrides.opknapperUrl`
  (a debug build uses the hub on this machine, `http://localhost:5173/opknapper`;
  a release build `https://ai.eo.nl/opknapper`; for the slice on test, build with
  `--dart-define=OPKNAPPER_URL=https://app-test-aihub.azurewebsites.net/opknapper`).
- **Beta mode until it's released.** While `ForkOverrides.opknapperReleased`
  is false (the default), the tab, the page and the reminders exist only on a
  device in beta mode. A tester turns it on by tapping the app version seven
  times in a row (Instellingen → Over → App-versie); a message confirms it,
  and a *Bètamodus* switch then shows on that page to turn it off (on iOS 26,
  where About is a native sheet, a haptic confirms it and the version row
  says "bètamodus"). Seven taps
  again turn it off too. Nothing hints at it beforehand. Turned off, the tab
  goes, an open game returns to chat and pending reminders are cancelled.
  Kept per device, so it survives updates and sign-outs.
- **Releasing it** is `opknapperReleased` to true in `fork_overrides.dart`
  (or `--dart-define=OPKNAPPER_RELEASED=true` for one build), then the usual
  TestFlight and App Store route. Beta mode stays for the next feature.

## Sign-in

ai.eo.nl sits behind App Service Authentication with Entra ID: an
unauthenticated request is sent to Microsoft and back, and the hub reads the
colleague from Easy Auth's headers. The game's web view uses the app's default
website data store — the same one the EOchat SSO sign-in used — so Microsoft's
session cookie is usually still there and the game opens signed in, no prompt.
When it isn't (the Microsoft session expired, or the SSO sign-in cleared
cookies for a fresh session), the page rewrites Microsoft's authorize request
with the colleague's EOchat address as `login_hint` and `domain_hint=eo.nl`,
so there's no account picker; at most the password and MFA, once. The web view
uses the SSO page's mobile Safari user agent, plus ` EOchatApp/Opknapper`.

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
- **Off by default.** Turned on in Meldingen, or by the page
  (`reminders`); turning it on asks iOS for permission.
- **A tap** opens `/opknapper?open=post`; if the game is already open the page
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

- **Push from the server** (an upvote, a klus on a day of its own): needs the
  push entitlement, an APNs key and a device token per colleague (50, T32).
- **The page kept alive across tabs:** leaving `/opknapper` disposes the web
  view; coming back reloads behind the game's own curtain.
- **Built without a compiler.** Neither the Mac's sandbox nor the cloud had
  Flutter, so this was written against the packages' sources (flutter_inappwebview
  6.2.0-beta.3, flutter_local_notifications 22.3.1, timezone 0.11) and never
  analysed or run. First: `flutter pub get`, `flutter analyze`, the sidebar
  widget tests (a new tab may change a destination count), then a device.
