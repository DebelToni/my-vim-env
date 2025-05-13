#!/usr/bin/env bash
set -e

DOTDIR="$HOME/my-vim-env"
if [[ "$(uname)" == "Darwin" ]]; then
	DOTDIR="$HOME/Documents/my-vim-env"
else
	echo "$(uname)"
fi

declare -A links=(
  ["$DOTDIR/zsh/.zshrc"]="$HOME/.zshrc"
  ["$DOTDIR/tmux/.tmux.conf"]="$HOME/.tmux.conf"
  ["$DOTDIR/nvim"]="$HOME/.config/nvim"
  ["$DOTDIR/zsh/.zshenv"]="$HOME/.zshenv"
  ["$DOTDIR/zsh/.zprofile"]="$HOME/.zprofile"
  ["$DOTDIR/tmux/"]="$HOME/.tmux"
)

for src in "${!links[@]}"; do
  dest="${links[$src]}"
  mkdir -p "$(dirname "$dest")"
  ln -sfv "$src" "$dest"
done
