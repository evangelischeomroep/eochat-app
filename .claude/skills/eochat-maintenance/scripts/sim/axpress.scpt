-- usage: osascript axpress.scpt "<label substring>" [press|center]
-- Coordinates are coerced to integers: the Dutch locale prints decimals with a comma otherwise.
on run argv
  set target to item 1 of argv
  set mode to "press"
  if (count of argv) > 1 then set mode to item 2 of argv
  tell application "System Events" to tell process "Simulator" to set w to window 1
  set found to my find(w, 0, target)
  if found is missing value then return "NOT FOUND: " & target
  tell application "System Events"
    set p to position of found
    set s to size of found
    set cx to ((item 1 of p) + (item 1 of s) / 2) as integer
    set cy to ((item 2 of p) + (item 2 of s) / 2) as integer
    if mode is "press" then
      try
        perform action "AXPress" of found
        return "pressed " & target & " at " & cx & " " & cy
      end try
    end if
    return "center " & cx & " " & cy
  end tell
end run
on find(el, depth, target)
  if depth > 26 then return missing value
  tell application "System Events"
    try
      set d to ""
      try
        set d to description of el as text
      end try
      if d contains target then return el
      set kids to UI elements of el
    on error
      set kids to {}
    end try
  end tell
  repeat with c in kids
    set r to my find(c, depth + 1, target)
    if r is not missing value then return r
  end repeat
  return missing value
end find
