#NoEnv 
SendMode Input  
SetWorkingDir %A_ScriptDir% 

CapsDownTime := 0
CapsIsHeld := false
speed := 50
Treshold := 200*-1

NeovimWindow := "ahk_exe WindowsTerminal.exe" ;app name for the terminal

*CapsLock::
    CapsDownTime := A_TickCount
    SetTimer, CapsLockHold, %Treshold%
    Return

*CapsLock Up::
    SetTimer, CapsLockHold, Off 
    ;ToolTip, % "Time: " . (A_TickCount - CapsDownTime)
    ;Sleep, 500
    ;ToolTip
    If (!CapsIsHeld) {
        ;tap
        Send {Esc}
    } Else {
        ; hold; 
        CapsIsHeld := false
        Send {Ctrl Up}
    }
    Return

CapsLockHold:
    If ((A_TickCount - CapsDownTime) > Treshold*-1) { 
        CapsIsHeld := true
        If WinActive(NeovimWindow) {
            Send {Ctrl Down}
        } Else {
        }
    }
    Return

#If WinActive(NeovimWindow) && CapsIsHeld
    *CapsLock Up::
        Send {Ctrl Up}
        CapsIsHeld := false
        Return
#If

; outside of terminal
#If !WinActive(NeovimWindow) && CapsIsHeld
    h::Left
    j::Up
    k::Down
    l::Right
    +H::Left
    +J::Up
    +K::Down
    +L::Right
    ;i::Home
    ;a::End
    o:: Send {Home}{Enter}
    +O:: Send {End}{Enter}{Up}
    I::Home
    A::End
    v::RShift
    .::Move_mouse_down()
    /::Move_mouse_right()
    m::Move_mouse_left()
    ,::Move_mouse_up()
    b:: Send ^{Left} ; beginning of the word
    w:: Send ^{Right} ; end of the word
    e:: Send ^+{Right} ; end of the word and select
    y:: Send {Ctrl down}c{Ctrl up}
    p:: Send {Ctrl down}v{Ctrl up}
   ;d:: Send {Ctrl down}x{Ctrl up}
	d::
        if (isDoublePress) {
            ; Reset double press state and perform double-press action
            isDoublePress := false
            SetTimer, ResetPressState, Off
            Send {Home}{Shift down}{End}{Shift up}{Ctrl down}x{Ctrl up}{Delete}
        } else {
            ; Set double press state and timer
            isDoublePress := true
            SetTimer, ResetPressState, -200
            ; Perform the first action (Ctrl+X)
            Send ^x
        }
	return

    1::speed = 10
    2::speed = 25
    3::speed = 50
    4::speed = 100
    5::speed = 150
    Space::Click
    Alt::Click Right



isDoublePress := false
pressTimer := 0

ResetPressState:
    isDoublePress := false
    Return




#If
Move_mouse_down()
{
    global speed
    MouseGetPos, xpos, ypos 
    MouseMove xpos, ypos + speed
return
}
;
Move_mouse_left()
{
    global speed
    MouseGetPos, xpos, ypos 
    MouseMove xpos - speed, ypos 
return
}
;
Move_mouse_right()
{
    global speed
    MouseGetPos, xpos, ypos 
    MouseMove xpos + speed, ypos 
return
}
;
Move_mouse_up()
{
    global speed
    MouseGetPos, xpos, ypos 
    MouseMove xpos, ypos - speed
return
}

; COMPILE MACRO - set compile terminal tab to 6 taskbar slot and 5 for your code window (or change the thingy)
; Also if you are outside of terminal (vim) it just opens the code and does not compile
#!z::  ; Win + Alt + z
  If WinActive(NeovimWindow){
     Send,{LWin down}6{LWin up}
    Sleep, 100

    Send {Up}
    Sleep, 100

    Send {Enter}
    Sleep, 100

    Send, {LWin down}5{LWin up}
    Sleep, 100
} else {
    Send, {LWin down}5{LWin up}
    Sleep, 100
}

return




;; Old version:
;*CapsLock::
;    Send {Blind}{Ctrl Down}
;    cDown := A_TickCount
;Return
;
;*CapsLock up::
;    If ((A_TickCount-cDown)<400)  ; (milliseconds)
;        Send {Blind}{Ctrl Up}{Esc}
;    Else
;        Send {Blind}{Ctrl Up}
;Return
