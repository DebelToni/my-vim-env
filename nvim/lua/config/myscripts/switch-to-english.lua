vim.api.nvim_create_autocmd("ModeChanged", {
	callback = function()
		local current_mode = vim.fn.mode()
		if current_mode:match("^n") then
			local cmd =
			[["/mnt/c/Program Files/AutoHotkey/AutoHotkey.exe" "C:\Users\anton\Documents\nvim\alt-shift.ahk"]]
			vim.fn.system(cmd)
		end
		if current_mode:match("^i") then
			local cmd =
			[["/mnt/c/Program Files/AutoHotkey/AutoHotkey.exe" "C:\Users\anton\Documents\nvim\alt-shift.ahk"]]
			vim.fn.system(cmd)
		end
	end,
})
-- The AHK script:
-- ; "/mnt/c/Program Files/AutoHotkey/AutoHotkey.exe" "/mnt/c/path/to/your/script.ahk"
-- ; Use the delay if you feel to or adjust timing but mostly works
-- hkl := DllCall("GetKeyboardLayout", "UInt", 0, "UInt")
-- LangID := hkl & 0xFFFF
-- if (LangID != 0x0409) { ; 0x0409 - US
-- 		Send, {Alt down}{Shift down}{Shift up}{Alt up}
-- 		; Send {Alt down}
-- 		; sleep, 100
-- 		; Send {Shift down}
-- 		; sleep, 100
-- 		; Send {Shift up}
-- 		; sleep, 100
-- 		; Send {Alt up}
-- 		; sleep, 100
-- 		FileAppend, 1, C:\Users\anton\Documents\nvim\BG.txt
-- }else{
-- 		if ( FileExist("C:\Users\anton\Documents\nvim\BG.txt") ) {
-- 				Send, {Alt down}{Shift down}{Shift up}{Alt up}
-- ; 				Send {Alt down}
-- ; 				sleep, 100
-- ; 				Send {Shift down}
-- ; 				sleep, 100
-- ; 				Send {Shift up}
-- ; 				sleep, 100
-- ; 				Send {Alt up}
-- ; 				sleep, 100
-- 				FileDelete, C:\Users\anton\Documents\nvim\BG.txt
-- 		}
-- }
-- ; 0x0402 - possibly bulgarian
-- ExitApp
-- 
