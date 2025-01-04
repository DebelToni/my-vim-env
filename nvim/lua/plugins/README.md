# My Plugins

- Important (for me) - nvim-silicon new version doesnt work on windows 10 wsl as of 2025 so you need to go to:
```
/home/USR/.local/share/nvim/lazy/nvim-silicon/lua/nvim-silicon/init.lua
```
and change line 313 from:
```
			table.insert(cmdline, "/bin/sh")
```
to:
```
            table.insert(cmdline, "/bin/bash")
```
