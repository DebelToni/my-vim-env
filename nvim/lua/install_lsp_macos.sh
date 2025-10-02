#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---
have() { command -v "$1" >/dev/null 2>&1; }
ensure_brew() {
  if ! have brew; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

echo ">>> Ensuring Homebrew"
ensure_brew

echo ">>> Installing core runtimes & tools"
brew install \
  llvm \
  lua-language-server \
  jdtls \
  node \
  fd \
  ripgrep

# clangd lives under llvm’s prefix; add to PATH if needed
LLVM_BIN="$(brew --prefix llvm)/bin"
if [[ ":$PATH:" != *":$LLVM_BIN:"* ]]; then
  echo "export PATH=\"$LLVM_BIN:\$PATH\"" >> "$HOME/.zshrc"
  echo "Added LLVM bin to PATH in ~/.zshrc"
fi

# Java environment
if ! /usr/libexec/java_home >/dev/null 2>&1; then
  brew install openjdk
  echo 'export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo ">>> Installing Node-based language servers (global)"
# Bash
npm -g i bash-language-server
# HTML/CSS/JSON (VSCode extracted servers)
npm -g i vscode-langservers-extracted
# JS/TS
npm -g i typescript typescript-language-server
# Python type checker (fast & reliable)
npm -g i pyright
# YAML
npm -g i yaml-language-server

echo ">>> Verifying binaries on PATH"
bins=(clangd lua-language-server jdtls node npm bash-language-server \
      vscode-html-language-server vscode-css-language-server \
      typescript-language-server pyright yaml-language-server)
missing=()
for b in "${bins[@]}"; do have "$b" || missing+=("$b"); done

if (( ${#missing[@]} )); then
  echo "Missing after install: ${missing[*]}"
  echo "Open a new shell (to pick up PATH changes) and re-run this script if needed."
else
  echo "All language servers present. ✅"
fi

echo "Done. You can now configure Neovim."

