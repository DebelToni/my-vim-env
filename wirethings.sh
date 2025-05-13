#!/usr/bin/env bash
set -e

DOTDIR="$HOME/Documents/my-vim-env"

declare -A links=(
  ["$DOTDIR/zsh/.zshrc"]="$HOME/.zshrc"
  ["$DOTDIR/tmux/.tmux.conf"]="$HOME/.tmux.conf"
  ["$DOTDIR/nvim"]="$HOME/.config/nvim"
)

for src in "${!links[@]}"; do
  dest="${links[$src]}"
  mkdir -p "$(dirname "$dest")"
  ln -sfv "$src" "$dest"
done
