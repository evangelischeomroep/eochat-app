# Verifying on the iOS Simulator

Everything here lives in `scripts/sim/` next to this skill. Copy the folder
to a scratch directory or run it in place; nothing writes into the repo
except screenshots you choose to keep.

## One-time setup

- Device: iPhone 17 Pro, iOS 26, UDID `25726C04-D2A9-4CB2-9EBC-3E1F4C4EA49A`
  (check `xcrun simctl list devices` if it was recreated). App bundle
  `nl.eo.eochat.debug`.
- Accessibility permission for the terminal host (Zed, Terminal, VS Code)
  under System Settings → Privacy & Security → Accessibility, otherwise
  `press.sh` and `axdump` return nothing. Lennart granted it for Zed.
- Build `simtap` once: `scripts/sim/build.sh` (needs Xcode's `swiftc`).
- Sign-in: SSO only (see pitfalls). Lennart logs in manually once; the
  session persists.

## Run the app

```bash
scripts/sim/run-app.sh            # boots the simulator, nohup flutter run, log path printed
```

Wait until the log shows `Flutter run key commands`. Kill with the pid file
the script writes. Hot reload is not available through nohup; rebuild.

## Scripts

| Script | Use |
|---|---|
| `shot.sh <name> [light\|dark]` | Screenshot (optionally after switching appearance) to `shots/<name>-<theme>.png` plus a 900px copy. Switching appearance dismisses menus; capture first. |
| `crop.sh <name> <theme> <y_pt> <h_pt>` | Crop a device-point band from a shot (composer sits around y 760–874) and downscale it for reading. |
| `calibrate.sh "<label>" <x_pt> <y_pt>` | Compute the screen offset from a control's accessibility frame and store it in `.offset`. Run once per session and again whenever the Simulator window moved. Example: `calibrate.sh "Meer" 46 818` (the composer + button). |
| `tap.sh <x_pt> <y_pt>` | CGEvent click at device points using `.offset`. For Flutter widgets. |
| `press.sh "<label>"` | `AXPress` on the first accessibility element whose description contains the label; falls back to a click at its centre. For UIKit menus, sheet rows, switches. |
| `axdump.sh` | Dump the accessibility tree with positions (slow on long lists). |
| `type.sh "<text>"` / `key.sh <code>` | Keyboard input via CGEvent. |

Device points: iPhone 17 Pro is 402×874 pt, screenshots are 3×. A 900px
downscaled shot maps `y_pt ≈ y_px × 874 / 900`.

## Coordinates that were stable across sessions

| Control | Device pt |
|---|---|
| Hamburger (chat header) | 38, 86 |
| Avatar in sidebar (opens settings sheet) | 37, 87 |
| Settings sheet: Chats row | 120, 382 |
| Chats page: "Snelkoppelingen in chat" | 155, 267 |
| Native sheet back button | 37, 100 |
| Native sheet close (X) | 364, 100 |
| Composer + button (idle) | 46, 818 |
| Composer X while panel open | 46, 544 |
| First "Recent" chat in sidebar | 60, 435 |

Re-shoot and re-derive if the layout changed; these are hints, not truth.

## Typical check for a composer item

```bash
cd scripts/sim
./calibrate.sh "Meer" 46 818
./shot.sh before light; ./shot.sh before dark
# ... make the change, rebuild ...
./shot.sh after light; ./shot.sh after dark
./crop.sh after light 740 134; ./crop.sh after dark 740 134
```

Read the crops with the image reader and compare against the user's
screenshot. Report what was verified and what was not (for example
"recording state not captured, window on another Space").
