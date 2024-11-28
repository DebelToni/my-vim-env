#NoEnv 
SendMode Input  
SetWorkingDir %A_ScriptDir% 

CapsDownTime := 0
CapsIsHeld := false
speed := 50
Treshold := 200*-1

NeovimWindow := "ahk_exe WindowsTerminal.exe" ;app name for the terminal

Mode := "INSERT"

Gui, +AlwaysOnTop +ToolWindow -Caption +E0x80000
Gui, Color, 0000FF
Gui, Show, x10 y10 w20 h20 NoActivate, ModeOverlay  
WinSet, Transparent, 150, ModeOverlay  

UpdateModeOverlay() {
    global Mode
    if (Mode = "NORMAL" && !WinActive(NeovimWindow)) {
	    WinSet, Transparent, 150, ModeOverlay
    } else {
	    WinSet, Transparent, 0, ModeOverlay
    }
}


*CapsLock::
    CapsDownTime := A_TickCount
    SetTimer, CapsLockHold, %Treshold%
	if(!WinActive(NeovimWindow)) {
     	if (Mode = "INSERT") {
            Mode := "NORMAL"
        } else {
            ;Mode := "INSERT"
        }
    }else{
		    Mode := "INSERT"
		    ;Mode := "NORMAL"
	}
    UpdateModeOverlay()
    Return
*CapsLock Up::
    SetTimer, CapsLockHold, Off 
    If (!CapsIsHeld && WinActive(NeovimWindow)) {
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
#If !WinActive(NeovimWindow) && (Mode = "NORMAL") 
    h::Left
    j::Up
    k::Down
    l::Right
    +H::Left
    +J::Up
    +K::Down
    +L::Right
    i:: Mode := "INSERT", UpdateModeOverlay()
	a::
	{
	Send {Right}
	Mode := "INSERT"
	UpdateModeOverlay()
	return
	}
    o:: Send {Home}{Enter}
    +O:: Send {End}{Enter}{Up}
    +I:: 
	{
	Send {Home}
	Mode := "INSERT"
	UpdateModeOverlay()
	return 
	}
    +A:: 
	{
	Send {End}
	Mode := "INSERT"
	UpdateModeOverlay()
	return 
	}
	v::
{
    if GetKeyState("Shift", "P"){
        Send, {Shift up}
    }else{
        Send, {Shift down}
    }
	return
}
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

