; MinecraftHotbarScroll.ahk
; Remaps mouse side buttons (XButton1/XButton2) to scroll the hotbar in Minecraft.
; XButton1 (back) scrolls hotbar right (next slot)
; XButton2 (forward) scrolls hotbar left (previous slot)
; Uses {Blind} modifier to preserve Shift key state for stack splitting.

#NoEnv                   ; Recommended for performance
SendMode Input           ; Faster, more reliable
SetWorkingDir %A_ScriptDir%

; --- Minecraft-specific hotkeys (matches Java Edition) ---
#IfWinActive, ahk_exe javaw.exe

*XButton1::
    ; Scroll hotbar right (next slot)
    Send {Blind}{WheelDown}
return

*XButton2::
    ; Scroll hotbar left (previous slot)
    Send {Blind}{WheelUp}
return

; End context-sensitive remappings
#If
