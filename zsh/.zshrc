# ~/.zshrc — interactive-shell setup

# 1) pull in login-shell exports/env first
[[ -f ~/.zprofile ]] && source ~/.zprofile
export ZSH="$HOME/.oh-my-zsh"

# Auto-attach to tmux session "AI" when SSH'ing into this macOS host.
# - interactive shells only
# - only over SSH
# - don't nest tmux inside tmux
if [[ "$OSTYPE" == "darwin"* ]] \
  && [[ $- == *i* ]] \
  && [[ -n "${SSH_CONNECTION}${SSH_CLIENT}${SSH_TTY}" ]] \
  && [[ -z "${TMUX}" ]]; then
  if command -v tmux >/dev/null 2>&1; then
    tmux attach -t AI 2>/dev/null || tmux new -s AI
  fi
fi

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

HISTSIZE=1000000         # Number of commands in memory per session
SAVEHIST=1000000         # Number of commands to save to file
HISTFILE=~/.zsh_history  # File where history is saved


plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf-tab)

source $ZSH/oh-my-zsh.sh

bindkey -v

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

export EDITOR="nvim"

# 5) OS-specific tweaks & aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
  alias arxiv="~/Documents/arxiv"
  export PATH="$HOME/bin:$PATH"
  eval "$(zoxide init --cmd cd zsh)"
  alias killAnyDesk="sudo pkill -9 -f AnyDesk"
  alias bat="bat"
  alias codexa="codex --dangerously-bypass-approvals-and-sandbox"
  alias o="opencode"
  alias coc="~/.config/opencode"
  # alias cf='codex --dangerously-bypass-approvals-and-sandbox --model gpt-5.2 -c model_reasoning_effort=low exec'

  alias copilota=" copilot --allow-all-tools --allow-all-paths --add-dir --resume"
  alias cr="codex --dangerously-bypass-approvals-and-sandbox resume"
  # alias openg="open --url $(git remote get-url origin)"
  [[ -d "/opt/homebrew/opt/swift/bin" ]] && export PATH="/opt/homebrew/opt/swift/bin:$PATH"
  # alias tailscale=/Applications/Tailscale.app/Contents/MacOS/Tailscale # fixed on installing binary in bath throught the tailscale pannel
  # function ls() {
  #  local depth=0
  #
  # if [[ $1 =~ ^[0-9]+$ ]]; then
  #   depth=$1
  #   shift
  # fi
  #
  # command eza -l -b \
  #   --no-permissions \
  #   --no-user \
  #   --time-style=relative \
  #   --sort=modified \
  #   --tree \
  #   --level="$depth" \
  #   "${@:-.}"
  # }

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  alias nvidia-smi="/mnt/c/Documents\ and\ Settings/All\ Users/NVIDIA\ Corporation/NVIDIA\ app/UpdateFramework/ota-artifacts/grd/post-processing/aa811dd5940cca149f351159ffb1fcb1/Display.Driver/nvidia-smi"
  alias bat="batcat"
  export PATH="/opt/nvim/:$PATH"
  export PATH="/opt/swift/swift-6.0.3-RELEASE-ubuntu22.04/usr/bin:$PATH"
  alias cmd=/mnt/c/Windows/System32/cmd.exe
fi

# 6) Aliases & functions
alias r2='s5cmd --endpoint-url "$R2_ENDPOINT"'
alias n='nvim'
alias psql-size='psql -U postgres -h localhost -p 5432 -c "SELECT d.datname AS database, pg_size_pretty(pg_database_size(d.datname)) AS size FROM pg_database d WHERE NOT d.datistemplate ORDER BY pg_database_size(d.datname) DESC;"'

# pgtops: list biggest tables in every non-template DB

# pgtops: show biggest relations per non-template DB (robust)

# Put this in ~/.bashrc or ~/.zshrc

pg-table-sizes-all(){ psql -U postgres -h localhost -p 5432 -At -c "SELECT datname FROM pg_database WHERE NOT datistemplate;" | while read -r db; do echo "=== $db ==="; psql -U postgres -h localhost -p 5432 -d "$db" -c "SELECT n.nspname AS schema, c.relname AS table, pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size, pg_total_relation_size(c.oid) AS total_bytes FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind IN ('r','p','m') AND n.nspname NOT IN ('pg_catalog','information_schema') ORDER BY total_bytes DESC${1:+ LIMIT $1};"; done; }

typ() {
    if [ -z "$1" ]; then
        echo "Usage: typ <file.typ>"
        return 1
    fi
    
    local typfile="$1"
    local pdffile="${typfile%.typ}.pdf"
    local port=12345
    local tailscale_ip=$(tailscale ip -4)
    local url="http://${tailscale_ip}:${port}/${pdffile}"
    
    # Cleanup function
    cleanup() {
        echo -e "\n\nStopping processes..."
        kill $typst_pid $server_pid 2>/dev/null
        exit 0
    }
    
    trap cleanup INT TERM
    
    # Start typst watch
    typst watch "$typfile" &
    typst_pid=$!
    
    # Start Python HTTPS server
    python3 -m http.server "$port" &
    server_pid=$!
    
    # Wait a moment for server to start
    sleep 1
    
    # Copy URL to clipboard via OSC52 through tmux
    printf "\033Ptmux;\033\033]52;c;$(printf "%s" "$url" | base64)\a\033\\" > /dev/tty
    
    echo "✓ Typst watching: $typfile"
    echo "✓ Server running on port $port"
    echo "✓ URL copied to clipboard: $url"
    echo ""
    echo "Press Ctrl+C to stop"
    
    # Wait for both processes
    wait
}

r2comp() {
  local bucket="${1:-s3://giant-data}"
  local endpoint="${R2_ENDPOINT}"

  if [[ -z "$endpoint" ]]; then
    echo "R2_ENDPOINT is not set" >&2
    return 1
  fi

  # temp files for sorted lists
  local tmp_remote tmp_local
  tmp_remote="$(mktemp -t r2_remote.XXXXXX)" || return 1
  tmp_local="$(mktemp -t r2_local.XXXXXX)" || { rm -f "$tmp_remote"; return 1; }

  # --- build remote list: "SIZE KEY"
  s5cmd --endpoint-url "$endpoint" ls "${bucket}/*" \
    | awk 'NF >= 4 && $3 ~ /^[0-9]+$/ {
             size=$3
             $1=$2=$3=""
             sub(/^ +/, "")
             print size " " $0
           }' \
    | sort > "$tmp_remote"

  # --- build local list: "SIZE RELATIVE_PATH"
  python3 - << 'PY' > "$tmp_local"
import os

for root, dirs, files in os.walk('.'):
    for name in files:
        path = os.path.join(root, name)
        rel = os.path.relpath(path, '.')
        size = os.path.getsize(path)
        print(f"{size} {rel}")
PY

  sort -o "$tmp_local" "$tmp_local"

  echo "== In bucket but missing locally (by name+size) =="
  comm -23 "$tmp_remote" "$tmp_local" || true

  echo
  echo "== Local extra files not in bucket (by name+size) =="
  comm -13 "$tmp_remote" "$tmp_local" || true

  rm -f "$tmp_remote" "$tmp_local"
}


eza-ls() {
  if [ $# -eq 0 ]; then
    # plain `ls` → no recursion
    command eza --tree --level=0 --no-permissions --no-user --time-style=relative --sort=modified --git --icons -b -l "$@"
  else
    # `ls some/dir` → one-level recursion into that dir
    command eza --tree --level=1 --no-permissions --no-user --time-style=relative --sort=modified --git --icons -b -l "$@"
  fi
}

# then alias or symlink it as your new `ls`
alias ls='eza-ls'

alias inv='nvim $(fzf -m --preview="bat --color=always {}")'
alias py='python3'
alias lgit='lazygit'
alias ldocker='lazydocker'
alias cdu='cd ../'
alias cduu='cd ../../'
alias c='clear -x'
alias update-giant='rm *.* && cp -r ~/Documents/ml/SUPER-GIANT/v1/model/*.* . && cp ~/Documents/ml/SUPER-GIANT/Model_Overview.md .'
cdf() {
  local target
  # pick a file or directory
  target=$(fzf) || return      # cancel on ESC/CTRL-C
  # if it’s a directory, cd there; otherwise cd to its dirname
  if [[ -d "$target" ]]; then
    cd -- "$target" || return
  else
    cd -- "$(dirname -- "$target")" || return
  fi
}
cpf() {
  if [[ -z $1 || ! -d $1 ]]; then
    echo "Usage: cpf <target-dir>"
    return 1
  fi
  local files
  # multi-select with null delimiters
  files=$(fzf -m --print0) || return
  # copy each into the target
  printf '%s\0' "$files" | xargs -0 -I{} cp -- {} "$1"
}
mvf() {
  if [[ -z $1 || ! -d $1 ]]; then
    echo "Usage: mvf <target-dir>"
    return 1
  fi
  local files
  # multi-select with null delimiters
  files=$(fzf -m --print0) || return
  # copy each into the target
 /printf '%s\0' "$files" | xargs -0 -I{} mv -- {} "$1"
}
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
eval "$(thefuck --alias)"
eval "$(thefuck --alias fk)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
setopt extended_glob # some fzf
setopt globstarshort


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

drawit(){
	cd ~/Documents/python/drawIT
	source ~/v/py/bin/activate
	python drawit.py
}

export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
[[ -f ~/.config/secrets.zsh ]] && source ~/.config/secrets.zsh

# Commands starting with a space won't be saved to history
setopt HIST_IGNORE_SPACE
# Reduce noise & duplicates
setopt HIST_REDUCE_BLANKS HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS

# opencode
export PATH=/Users/antonhristov/.opencode/bin:$PATH
