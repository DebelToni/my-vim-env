My custom AHK utility macros for the best ***wsl + Vim*** experience

Features of toni_macro.ahk:
*(note that i use j for up and k for down)*

- Knows all the time if you have a cmd window focused so it can have custom functionalities based on that. Like:

- Binds CAPS key to tap-hold between ESC and CTRL   :in cmd

- While holding CAPS allows you to do these things  :outside of cmd
    - basic vim motion with h j k l
    - y for copy
    - p for paste
    - w for next word
    - b for prev word
    - v for selecting 
    - e end of word and select it
    - d for delete and copy (cut)
    - i for beggining of line (or I)
    - a for end of line (or R)

    - moves the mouse with m , . /  by speed'
    - the buttons 1 2 3 4 5 change the speed' (3 is default)
    - space for mouse left click 
    - alt for mouse right click 

*My personal favorite:*
- Win + Alt + Z     ->      checks if outside of inside terminal again for:
    - in cmd is set to go run/compile/both/other the code you are working on and returns to your vim editor - super useful in 2 monitor setups where compilation is on other monitor. It achieves it by:
        1. opens whatever is in you taskbar slot 6 (go customise it) 
        2. presses Up arrow for last executed command if slot 6 is a cmd set up for compiling or other needs
        3. presses enter
        4. goes back to taskbar slot 5 (which for me is my temrinal with vim but you can make it go to the last opened or different taskbar slot)

    - outside of cmd it opens your vim editor on taskbar 6 (you can make it dynamic with the window id) so you can start writing. This is useful if you dont know in which app alt+tab will send you and gets you working right away. It does that with win + 6
    
