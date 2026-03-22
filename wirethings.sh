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
  ["$DOTDIR/ghostty"]="$HOME/.config/ghostty"
  ["$DOTDIR/zsh/.zshenv"]="$HOME/.zshenv"
  ["$DOTDIR/zsh/.zprofile"]="$HOME/.zprofile"
  ["$DOTDIR/zsh/.p10k.zsh"]="$HOME/.p10k.zsh"
  ["$DOTDIR/tmux"]="$HOME/.tmux"
  ["$DOTDIR/bin/fast"]="$HOME/bin/fast"
  ["$DOTDIR/bin/fastc"]="$HOME/bin/fastc"
  ["$DOTDIR/bin/arxiv-src"]="$HOME/bin/arxiv-src"
  ["$DOTDIR/bin/opencode-editor-tmux"]="$HOME/bin/opencode-editor-tmux"
  ["$DOTDIR/bin/opencode"]="$HOME/bin/opencode"
  ["$DOTDIR/bin/ghostty-switch-mode"]="$HOME/bin/ghostty-switch-mode"
)

link_path() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" || -f "$dest" ]]; then
    rm -f "$dest"
  elif [[ -d "$dest" ]]; then
    rm -rf "$dest"
  fi

  ln -sfnv "$src" "$dest"
}

for src in "${!links[@]}"; do
  dest="${links[$src]}"
  link_path "$src" "$dest"
done

executables=(
  "$DOTDIR/bin/fast"
  "$DOTDIR/bin/fastc"
  "$DOTDIR/bin/arxiv-src"
  "$DOTDIR/bin/opencode-editor-tmux"
  "$DOTDIR/bin/opencode"
  "$DOTDIR/bin/ghostty-switch-mode"
)

for file in "${executables[@]}"; do
  [[ -f "$file" ]] && chmod +x "$file"
done

mkdir -p "$HOME/.opencode/bin"
link_path "$DOTDIR/bin/opencode" "$HOME/.opencode/bin/opencode"
