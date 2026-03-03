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
  ["$DOTDIR/zsh/.p10k.zsh"]="$HOME/.p10k.zsh"
  ["$DOTDIR/tmux/"]="$HOME/.tmux"
  ["$DOTDIR/bin/fast"]="$HOME/bin/fast"
  ["$DOTDIR/bin/fastc"]="$HOME/bin/fastc"
  ["$DOTDIR/bin/arxiv-src"]="$HOME/bin/arxiv-src"
  ["$DOTDIR/bin/opencode-editor-tmux"]="$HOME/bin/opencode-editor-tmux"
)

for src in "${!links[@]}"; do
  dest="${links[$src]}"
  mkdir -p "$(dirname "$dest")"
  ln -sfv "$src" "$dest"
done

executables=(
  "$DOTDIR/bin/fast"
  "$DOTDIR/bin/fastc"
  "$DOTDIR/bin/arxiv-src"
  "$DOTDIR/bin/opencode-editor-tmux"
)

for file in "${executables[@]}"; do
  [[ -f "$file" ]] && chmod +x "$file"
done
