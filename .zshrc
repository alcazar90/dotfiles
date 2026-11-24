# ── Prompt with git branch ─────────────────────────
autoload -Uz vcs_info add-zsh-hook
add-zsh-hook precmd vcs_info
setopt PROMPT_SUBST
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{#CE5D97}(%b)%f'
PROMPT='%F{#92BFDB}%~%f${vcs_info_msg_0_} ❯ '

# ── Completado e historial (antes lo configuraba Oh My Zsh) ──
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(-w+1wk) ]]; then compinit
else compinit -C; fi

# Colores para ls y el menú de completado
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabag
export LS_COLORS='di=38;5;39:ln=38;5;51:so=38;5;48:pi=38;5;47:do=38;5;220:bd=38;5;45;1:cd=38;5;210;1:or=red;1:ex=38;5;220;1:su=38;5;196;4:sg=38;5;190;4:tw=38;5;48;4:st=38;5;220;4'

zmodload zsh/complist
zstyle ':completion:*' menu select {long,complete,history}-list
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # ignora mayúsculas

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_EXPIRE_DUPS_FIRST \
      HIST_REDUCE_BLANKS HIST_FCNTL_LOCK HIST_VERIFY EXTENDED_HISTORY

# ── Search web from the terminal ──
# URL-encode a string (RFC 3986: A-Z a-z 0-9 - _ . ~ kept, rest -> %XX).
# Pure-zsh (no python dependency). Encodes each byte of the UTF-8 string.
urlencode() {
  local out="" s="$1" c off
  off=0
  while (( off < ${#s} )); do
    c="${s:$((off)):1}"
    if [[ $c == [a-zA-Z0-9\-_.~] ]]; then
      out+="$c"
    else
      out+=$(printf '%%%02X' "'$c")
    fi
    (( off++ ))
  done
  print -r -- "$out"
}
google() { open "https://www.google.com/search?q=$(urlencode "${(j: :)@}")"; }

# ── Aliases ─────────────────────────────────────────
alias vsh="vim ~/.zshrc"
alias rsh="source ~/.zshrc"

# git
alias gs="git status"
alias gpullo="git pull origin"
alias gpusho="git push origin"
alias gco="git checkout"
alias gcm="git commit -m"
alias glol="git log --oneline -n"

# python
alias pipf='pip freeze | grep'
alias pipi='pip install'

# python x uv
alias pyls='uv python list'
alias pycask='uv python install'

# ── uv ──────────────────────────────────────────────
# Set the global `python`/`python3` version via uv (installs it, links the
# shims in uv's bin dir, and pins it as uv's global default)
pyglobal() {
    [[ -z "$1" ]] && { echo "uso: pyglobal <version>"; return 1; }
    uv python install --quiet "$1" --default && uv python pin --global "$1"
    echo "→ python global: $(python3 --version)"
}

# ── Claude ──────────────────────────────────────────
# Cambia los settings de claude entre personal y corporativo
claude-mode() {
    local target=""
    case "$1" in
        corp) target=~/.claude/settings-corp.json ;;
        personal) target=~/.claude/settings-personal.json ;;
        *) echo "uso: claude-mode [corp|personal]"; return 1 ;;
    esac

    if [[ ! -f "$target" ]]; then
        echo "✗ no existe: $target"
        return 1
    fi

    ln -sf "$target" ~/.claude/settings.json
    echo "→ modo: $(readlink ~/.claude/settings.json)"
}

claude-whoami() {
    echo "→ modo: $(readlink ~/.claude/settings.json)"
}


# ── Plugins ─────────────────────────────────────────
# brew install zsh-autosuggestions fzf zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source <(fzf --zsh)
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

