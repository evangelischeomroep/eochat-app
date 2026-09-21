import Foundation
import CoreGraphics
// usage: simtap click <x> <y> | simtap type <text> | simtap key <keycode>
let args = CommandLine.arguments
func post(_ e: CGEvent?) { e?.post(tap: .cghidEventTap); usleep(40_000) }
if args.count >= 4 && args[1] == "click" {
  let p = CGPoint(x: Double(args[2])!, y: Double(args[3])!)
  post(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left))
  post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left))
  post(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left))
} else if args.count >= 3 && args[1] == "type" {
  for ch in args[2].utf16 {
    var u = [UniChar(ch)]
    let d = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true); d?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u); post(d)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false); up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u); post(up)
  }
} else if args.count >= 3 && args[1] == "key" {
  let k = CGKeyCode(UInt16(args[2])!)
  post(CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: true)); post(CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: false))
} else { print("usage: simtap click x y | type text | key code"); exit(1) }
