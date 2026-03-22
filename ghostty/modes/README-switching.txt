Ghostty mode switching

1) Open this file and edit:
   /Users/antonhristov/.config/ghostty/modes/active.conf

2) Enable one or more layers by adding lines:
   config-file = ./default.conf
   config-file = ./lightsaber.conf
   config-file = ./transparent_image.conf
   config-file = ./horse.conf
   config-file = ./complete_hackermode.conf

3) You can combine layers (example):
   config-file = ./default.conf
   config-file = ./transparent_image.conf
   config-file = ./lightsaber.conf

4) Reload Ghostty config with:
   Cmd+Shift+,

CLI quick switch:
  /Users/antonhristov/Documents/my-vim-env/bin/ghostty-switch-mode default lightsaber
  /Users/antonhristov/Documents/my-vim-env/bin/ghostty-switch-mode default transparent_image
  /Users/antonhristov/Documents/my-vim-env/bin/ghostty-switch-mode default horse
  /Users/antonhristov/Documents/my-vim-env/bin/ghostty-switch-mode default transparent_image complete_hackermode

Notes:
- transparent_image mode uses:
  /Users/antonhristov/Documents/my-vim-env/ghostty/images/Ghostty_background.jpg
- horse layer uses:
  /Users/antonhristov/Documents/my-vim-env/ghostty/images/Ghostty_horse.jpg
- horse automatically includes transparent_image when selected via ghostty-switch-mode,
  so you can tune transparency values only in transparent_image.conf.
- horse integer controls live in:
  /Users/antonhristov/.config/ghostty/modes/horse.controls.conf
  Use triangle-size = 1..9 and triangle-count = 1..9.
- transparent_image mode forces a neutral black base background to avoid Catppuccin
  purple tint bleeding through in TUIs.
- On macOS, background-opacity changes can require full Ghostty restart.
