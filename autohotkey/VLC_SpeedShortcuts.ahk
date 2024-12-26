#NoEnv                   ; Recommended for performance
; #Warn                  ; Enable for debugging if desired
SendMode Input           ; Faster, more reliable
SetWorkingDir %A_ScriptDir%

#IfWinActive ahk_exe vlc.exe

; Function: SetSpeed(speed)
; Resets playback to 1.0x, then sends the "]" key enough times
; to increment speed in 0.1x steps until reaching 'speed'.
SetSpeed(speed) {
    presses := (speed - 1.0) / 0.1  ; (desired - 1.0) / 0.1 = # of ] needed
    SendInput, =                   ; Reset to normal speed
    Sleep, 5
    Loop, %presses%
    {
        SendInput, ]
        Sleep, 5
    }
}

; --- 1 => 1.5x speed ---
$*1::
    SetSpeed(1.5)
    KeyWait, 1
return

$*1 up::
    SendInput, =
return

; --- 2 => 2x speed ---
$*2::
    SetSpeed(2.0)
    KeyWait, 2
return

$*2 up::
    SendInput, =
return

; --- 3 => 3x speed ---
$*3::
    SetSpeed(3.0)
    KeyWait, 3
return

$*3 up::
    SendInput, =
return

; --- 4 => 4x speed ---
$*4::
    SetSpeed(4.0)
    KeyWait, 4
return

$*4 up::
    SendInput, =
return

; --- 5 => 5x speed ---
$*5::
    SetSpeed(5.0)
    KeyWait, 5
return

$*5 up::
    SendInput, =
return

#If
