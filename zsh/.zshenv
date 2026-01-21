if [[ -o interactive ]]; then
  source ~/.zshrc
fi

if [[ "$(uname)" != "Darwin" ]]; then
	. "$HOME/.cargo/env"
	export PATH="$HOME/bin:$PATH"
fi
