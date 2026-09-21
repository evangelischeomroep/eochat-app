on walk(el, depth, acc)
  if depth > 26 then return acc
  tell application "System Events"
    try
      set r to role of el
      set d to ""
      try
        set d to description of el as text
      end try
      set v to ""
      try
        set v to value of el as text
      end try
      if r is in {"AXButton", "AXStaticText", "AXTextField", "AXTextArea", "AXCheckBox", "AXMenuItem", "AXPopUpButton", "AXImage"} then
        set p to position of el
        set s to size of el
        set acc to acc & r & " | " & d & " | " & v & " | " & (item 1 of p) & "," & (item 2 of p) & " " & (item 1 of s) & "x" & (item 2 of s) & (ASCII character 10)
      end if
      set kids to UI elements of el
    on error
      set kids to {}
    end try
  end tell
  repeat with c in kids
    set acc to my walk(c, depth + 1, acc)
  end repeat
  return acc
end walk
tell application "System Events" to tell process "Simulator" to set w to window 1
return my walk(w, 0, "")
