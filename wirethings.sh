#!/usr/bin/env bash
set -e

DOTDIR="$HOME/my-vim-env"

declare -A links=(
  ["$DOTDIR/zsh/.zshrc"]="$HOME/.zshrc"
  ["$DOTDIR/tmux/.tmux.conf"]="$HOME/.tmux.conf"
  ["$DOTDIR/nvim"]="$HOME/.config/nvim"
  ["$DOTDIR/zsh/.zshenv"]="$HOME/.zshenv"
  ["$DOTDIR/zsh/.zprofile"]="$HOME/.zprofile"
)

for src in "${!links[@]}"; do
  dest="${links[$src]}"
  mkdir -p "$(dirname "$dest")"
  ln -sfv "$src" "$dest"
done
