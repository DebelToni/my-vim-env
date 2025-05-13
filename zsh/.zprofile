# ~/.zprofile — login-shell setup: PATH, brew, SDKMAN, NVM, etc.

# macOS: Homebrew environment
if [[ "$OSTYPE" == "darwin"* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="/opt/homebrew/bin:$PATH"

# Linux (WSL2 Ubuntu): ensure ~/.local/bin and custom installs come first
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
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
