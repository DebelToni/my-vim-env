My custom AHK utility macros for the best ***wsl + Vim*** experience

Features of toni_macro.ahk:
*(note that i use j for up and k for down)*

- Knows all the time if you have a cmd window focused so it can have custom functionalities based on that. Like:

- Binds CAPS key to tap-hold between ESC and CTRL   :in cmd

From here I made 2 variations of integrating vim outside of terminal:
1. Uses normal mode keybinds that i added while holding CAPS - vim-everywhere-hold-caps.ahk
2. Actually switches between normal and insert mode with CAPS - vim-modes-integrated-windows.ahk. There is a little blue dot at the top of the screen to indicate if you are in normal mode outside of cmd (and gets dissabled in cmd).

-Either way the functions are the same - when in normal mode / holding CAPS outside of cmd:
    - i to toggle back to insert mode which is basic keyboard func
    - a to toggle back to insert and mode 1 space to the right
    - basic vim motion with h j k l
    - y for copy
    - p for paste
    - w for next word
    - b for prev word
    - v for selecting 
    - e end of word and select it
    - d for delete and copy (cut)
    - dd (200ms) for cut/delete line and go to the next
    - I for beggining of line and toggle to insert mode 
    - A for end of line and toggle to insert mode 
    - o for new line below
    - O for new line above

    - moves the mouse with m , . /  by speed'
    - the buttons 1 2 3 4 5 change the speed' (3 is default)
    - space for mouse left click 
    - alt for mouse right click 

    future addons:
    - probably disable the mouse functions and make it so you move with set amound with numbers and h j k l

*My personal favorite:*
- Win + Alt + Z     ->      checks if outside of inside terminal again for:
    - in cmd is set to go run/compile/both/other the code you are working on and returns to your vim editor - super useful in 2 monitor setups where compilation is on other monitor. It achieves it by:
        1. opens whatever is in you taskbar slot 6 (go customise it) 
        2. presses Up arrow for last executed command if slot 6 is a cmd set up for compiling or other needs
        3. presses enter
        4. goes back to taskbar slot 5 (which for me is my temrinal with vim but you can make it go to the last opened or different taskbar slot)

    - outside of cmd it opens your vim editor on taskbar 6 (you can make it dynamic with the window id) so you can start writing. This is useful if you dont know in which app alt+tab will send you and gets you working right away. It does that with win + 6
    
