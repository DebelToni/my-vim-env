# ~/.zshrc — interactive-shell setup

# 1) pull in login-shell exports/env first
[[ -f ~/.zprofile ]] && source ~/.zprofile

# 2) Oh My Zsh setup (exactly once)
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# ─── Bootstrap Oh My Zsh plugins if missing ────────────────────────────────────
CUSTOM_PLUGINS="${ZSH:-$HOME/.oh-my-zsh}/custom/plugins"

# zsh-autosuggestions
if [[ ! -d $CUSTOM_PLUGINS/zsh-autosuggestions ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    $CUSTOM_PLUGINS/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [[ ! -d $CUSTOM_PLUGINS/zsh-syntax-highlighting ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    $CUSTOM_PLUGINS/zsh-syntax-highlighting
fi

# (add more plugins here the same way)



plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# 3) Powerlevel10k instant-prompt & config
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# 4) Ghostty vs Apple Terminal theme/plugins
if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
  # extra plugins/theme if in Ghostty
  ZSH_THEME="powerlevel10k/powerlevel10k"
  plugins+=(zsh-syntax-highlighting)
fi

# 5) OS-specific tweaks & aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
  alias bat="bat"
  [[ -d "/opt/homebrew/opt/swift/bin" ]] && export PATH="/opt/homebrew/opt/swift/bin:$PATH"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  alias bat="batcat"
  export PATH="/opt/nvim/:$PATH"
  export PATH="/opt/swift/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH"
  alias cmd=/mnt/c/Windows/System32/cmd.exe
fi

# 6) Aliases & functions
alias inv='nvim $(fzf -m --preview="batcat --color=always {}")'
alias py='python3'
alias lgit='lazygit'
alias ldocker='lazydocker'
alias cdu='cd ../'
alias c='clear'
# alias brlines="find ./ -type f -print0 | xargs -0 cat | wc -l"
brlines() {
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    git ls-files --others --exclude-standard --cached | xargs cat | wc -l
  else
    find ./ -type f -print0 | xargs -0 cat | wc -l
  fi
}


nvim() {
  case "$1" in
    zsh) command nvim ~/.zshrc ;;
    tmux) command nvim ~/.tmux.conf ;;
    *) command nvim "$@" ;;
  esac
}

vi() {
  nvim "$@" && clear
}

cls() {
  clear && ls
}

makc() {
  make && ls
}

# your custom source() wrapper (left intact)
# source() {
#   if [[ "$1" == "zsh" ]]; then
#     builtin source ~/.zshrc
#     echo "Sourced ~/.zshrc"
#   elif [[ "$1" == "tmux" ]]; then
#     tmux source-file ~/.tmux.conf
#     echo "Sourced ~/.tmux.conf"
#   else
#     builtin source "$@"
#   fi
# }

# zoxide, thefuck, fzf, and cheat.sh integration
eval "$(zoxide init --cmd cd zsh)"
eval "$(thefuck --alias)"
eval "$(thefuck --alias fk)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

cheat() {
  if (( $# < 1 )); then
    echo "Usage: cheat <language> <query words> [ ?Q ]"
    return 1
  fi
  local lang=$1; shift
  local query=$(IFS=+; echo "$*")
  curl "cht.sh/${lang}/${query}"
}

mancheat() {
  cheat "$@" | less
}

vimouse(){
	cd ~/Documents/python/viMouse
	source ../py/bin/activate
	python vimMouse.py
}

# Optional auto-start tmux+resurrect (commented out)
# if [[ -z "$TMUX" ]]; then
#   tmux new-session \; run-shell "~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
# fi

# [[ -f ~/.zprofile ]] && source ~/.zprofile
# # Detect Ghostty vs. Apple Terminal (and other emulators)
# if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
# # ———————— Open-in-Neovim bridge for Ghostty ————————
#   LOCKFILE="/tmp/ghostty_nvim_$USER"
#
#   if [[ -f "$LOCKFILE" ]]; then
#     # read & open each file in nvim
#     while IFS= read -r file; do
#       nvim "$file"
#     done < "$LOCKFILE"
#     # cleanup so future Ghostty launches are normal
#     rm -f "$LOCKFILE"
#     # after quitting nvim, fall back to interactive shell
#     unset LOCKFILE
#     # return
#   fi
# # ———————————————————————————————————————————————
#
#   # inside Ghostty → use Powerlevel10k + extra plugins
#   ZSH_THEME="powerlevel10k/powerlevel10k"
#   plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
# else
#   # inside Apple Terminal (or anything else) → keep it simple
#   ZSH_THEME="robbyrussell"
#   plugins=(git)
# fi
#
# export ZSH="$HOME/.oh-my-zsh"
# source $ZSH/oh-my-zsh.sh
#
# # load your Powerlevel10k config only if in Ghostty
# if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
#   [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
# fi
#
# # …the rest of your aliases, functions, sdkman, nvm etc. all go here unchanged…
#
# # ~/.zshrc
# # — Interactive‐shell setup: prompt, plugins, aliases, functions
#
# # instant-prompt cache for Powerlevel10k
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi
#
# # OS-specific tweaks
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   # macOS Homebrew ‘bat’
#   alias bat="bat"
#
#   # (Optionally) guard Swift if you install via Homebrew
#   if [[ -d "/opt/homebrew/opt/swift/bin" ]]; then
#     export PATH="/opt/homebrew/opt/swift/bin:$PATH"
#   fi
#
# elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#   # Ubuntu ‘batcat’
#   alias bat="batcat"
#
#   # Your custom Neovim path on WSL2
#   export PATH="/opt/nvim/:$PATH"
#
#   # Ubuntu Swift install path
#   export PATH="/opt/swift/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH"
#
#   # Windows-cmd alias (WSL2)
#   alias cmd=/mnt/c/Windows/System32/cmd.exe
# fi
#
# # If you come from bash you might have to change your $PATH.
# # export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
#
# export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="powerlevel10k/powerlevel10k"
#
# plugins=(
#   git
#   zsh-autosuggestions
# )
#
# source $ZSH/oh-my-zsh.sh
#
# # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
#
# # THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
# export SDKMAN_DIR="$HOME/.sdkman"
# export GEM_PATH="/var/lib/gems/3.0.0:$GEM_PATH"
# [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
# [ -f ~/.bashrc ] && source ~/.bashrc
#
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
#
# # alias adjustments and functions
# alias inv='nvim $(fzf -m --preview="batcat --color=always {}")'
# alias py='python3'
#
# nvim() {
#   case "$1" in
#     zsh) command nvim ~/.zshrc ;;
#     tmux) command nvim ~/.tmux.conf ;;
#     *) command nvim "$@" ;;
#   esac
# }
#
# vi() {
#   nvim "$@" && clear
# }
#
# cls() {
#   clear && ls
# }
#
# makc() {
#   make && ls
# }
#
# alias cdu='cd ../'
# alias c='clear'
#
# source() {
#   if [[ "$1" == "zsh" ]]; then
#     builtin source ~/.zshrc
#     echo "Sourced ~/.zshrc"
#   elif [[ "$1" == "tmux" ]]; then
#     tmux source-file ~/.tmux.conf
#     echo "Sourced ~/.tmux.conf"
#   else
#     builtin source "$@"
#   fi
# }
#
# alias lgit='lazygit'
# alias ldocker='lazydocker'
#
# eval "$(zoxide init --cmd cd zsh)"
#
# alias rpi-tmux='tmux new-window "ssh -t toni@192.168.100.193 tmux attach-session -t default"'
#
# # Automatically start tmux and run tmux-resurrect if not already in tmux
# # if [[ -z "$TMUX" ]]; then
# #   tmux new-session \; run-shell "~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
# # fi
#
# eval $(thefuck --alias)
# eval $(thefuck --alias fk)
#
# # Setup auto install todo:
# # 1. Install zsh
# # 2. Install oh-my-zsh
# # 3. Install powerlevel10k
# # 4. Install zsh-autosuggestions
# # 5. Install zsh-syntax-highlighting
# # 6. Install fzf
# # 7. Install bat
# # 8. Install tmux
# # 9. Install tmux-resurrect
# # 10. Install tmux-continuum
# # 11. Install zoxide
# # 12. Install nvim
# # 13. Install sdkman
# # 15. Install lazygit
# # 16. Install lazydocker
# # 17. Install thefuck
# # 18. Install yazi
# # 19. Install glow - https://github.com/charmbracelet/glow
#
# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
#
# cheat() {
#   # Ensure at least one argument (the language) is given
#   if (( $# < 1 )); then
#     echo "Usage: cheat <language> <query words> [ ?Q ]"
#     return 1
#   fi
#
#   local lang=$1
#   shift
#
#   # Join the remaining arguments with plus signs.
#   local query
#   query=$(IFS=+; echo "$*")
#
#   # Build the URL; note that if no query is provided, this will simply show the cheat sheet for the language.
#   local url="cht.sh/${lang}/${query}"
#
#   # Call curl to fetch the cheat sheet.
#   curl "$url"
# }
#
# mancheat() {
#   # Ensure at least one argument (the language) is given
#   if (( $# < 1 )); then
#     echo "Usage: cheat <language> <query words> [ ?Q ]"
#     return 1
#   fi
#
#   local lang=$1
#   shift
#
#   # Join the remaining arguments with plus signs.
#   local query
#   query=$(IFS=+; echo "$*")
#
#   # Build the URL; note that if no query is provided, this will simply show the cheat sheet for the language.
#   local url="cht.sh/${lang}/${query}"
#
#   # Call curl to fetch the cheat sheet.
#   curl "$url" | less
# }
#
# alias brlines="find ./ -type f -print0 | xargs -0 cat | wc -l"
#

