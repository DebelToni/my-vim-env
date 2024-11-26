SetEmojiAndPaste(emojiChars, emojiName) {
    ClipSaved := ClipboardAll 
    Clipboard := emojiChars   

    ClipWait, 1 
    if ErrorLevel
    {
        MsgBox, Failed to set clipboard to the %emojiName% emoji.
        Clipboard := ClipSaved
        return
    }

    Send, ^v  
    Clipboard := ClipSaved  
}

#!v::  
    SetEmojiAndPaste(Chr(0xD83C) . Chr(0xDF0B), "Vulkan")
return

#!1::
    SetEmojiAndPaste(Chr(0xD83D) . Chr(0xDD34), "Red Circle")
return

#!2::
    SetEmojiAndPaste(Chr(0xD83D) . Chr(0xDFE1), "Yellow Circle")
return

#!3::
    SetEmojiAndPaste(Chr(0xD83D) . Chr(0xDFE2), "Green Circle")
return
#!k::
    SetEmojiAndPaste(Chr(0xD83D) . Chr(0xDC34), "Kon")
return
#!b::
    SetEmojiAndPaste(Chr(0xD83E) . Chr(0xDD22), "Vommit")
return
#!e::
    SetEmojiAndPaste(Chr(0xD83C) . Chr(0xDF93), "Education Cap")
return
#!n::
    SetEmojiAndPaste(Chr(0xD83E) . Chr(0xDD13), "Nerd")
return
#!x::
    SetEmojiAndPaste(Chr(0xD83D) . Chr(0xDE45) . Chr(0xD83C) . Chr(0xDFFF), "No Niga")
return
#!p::
    SetEmojiAndPaste(Chr(0xD83D) . Chr(0xDE4F), "Pray")
return
#!4::
    SetEmojiAndPaste("asd", "word")
return
