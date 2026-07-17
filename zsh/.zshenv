if [[ -o interactive ]]; then
  source ~/.zshrc
fi

export PYTHONPYCACHEPREFIX="/Volumes/SSD/dev-artifacts/pycache"

if [[ "$(uname)" != "Darwin" ]]; then
	. "$HOME/.cargo/env"
	export PATH="$HOME/bin:$PATH"
fi
