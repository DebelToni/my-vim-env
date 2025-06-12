# ~/.zprofile — login-shell setup: PATH, brew, SDKMAN, NVM, etc.

# macOS: Homebrew environment
if [[ "$OSTYPE" == "darwin"* ]]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
	export PATH="/opt/homebrew/bin:$PATH"
	# export PATH="/opt/homebrew/opt/postgresql@17:$PATH"
	export PATH="$(brew --prefix postgresql@17)/bin:$PATH"
	# echo "OS: $OSTYPE"
	#tkiinter
	# export PATH="/opt/homebrew/opt/tcl-tk/bin:$PATH"          # run-time
	# export LDFLAGS="-L/opt/homebrew/opt/tcl-tk/lib"           # linker
	# export CPPFLAGS="-I/opt/homebrew/opt/tcl-tk/include"      # compiler headers
	# export PKG_CONFIG_PATH="/opt/homebrew/opt/tcl-tk/lib/pkgconfig"  # pkg-config
	# export LDFLAGS="-L$(brew --prefix tcl-tk)/lib \
	#  -L$(brew --prefix openssl@3)/lib \
	#  -L$(brew --prefix readline)/lib \
	#  -L$(brew --prefix xz)/lib \
	#  -L$(xcrun --show-sdk-path)/usr/lib"
	#
	# export CPPFLAGS="-I$(brew --prefix tcl-tk)/include \
	#  -I$(brew --prefix openssl@3)/include \
	#  -I$(brew --prefix readline)/include \
	#  -I$(brew --prefix xz)/include"
	#
	# export PKG_CONFIG_PATH="$(brew --prefix tcl-tk)/lib/pkgconfig:\ $(brew --prefix openssl@3)/lib/pkgconfig"



# Linux (WSL2 Ubuntu): ensure ~/.local/bin and custom installs come first
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi

# SDKMAN (works on both)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# NVM (works on both)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]       && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# Ensure Homebrew in PATH if installed
if command -v brew &>/dev/null; then
  eval "$(brew shellenv)"
fi

# # ~/.zprofile
# # — Login‐shell setup: PATH, SDKMAN, NVM, etc.
#
# # macOS: Homebrew environment
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   eval "$(/opt/homebrew/bin/brew shellenv)"
#   export PATH="/opt/homebrew/bin:$PATH"
#
# # Linux (WSL2 Ubuntu): ensure ~/.local/bin and custom installs come first
# elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#   export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
#
#   # Ruby gems (Ubuntu default)
#   export GEM_PATH="/var/lib/gems/3.0.0:$GEM_PATH"
# fi
#
# # SDKMAN (works on both)
# export SDKMAN_DIR="$HOME/.sdkman"
# [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
#
# # NVM (works on both)
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ]       && source "$NVM_DIR/nvm.sh"
# [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
#
# if command -v brew &>/dev/null; then
#   eval "$(brew shellenv)"
# fi
#
