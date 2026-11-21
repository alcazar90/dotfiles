export PATH="$HOME/.local/bin:$PATH"

# ── Prompt with git branch ─────────────────────────
autoload -Uz vcs_info add-zsh-hook
add-zsh-hook precmd vcs_info
setopt PROMPT_SUBST
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{#CE5D97}(%b)%f'
PROMPT='%F{#92BFDB}%~%f${vcs_info_msg_0_} ❯ '

# ── Completado e historial (antes lo configuraba Oh My Zsh) ──
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # ignora mayúsculas

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS

# ── Search web from the terminal ──
_ws() { local url="$1"; shift; open "${url}${(j:+:)@}"; }
google() { _ws "https://www.google.com/search?q=" "$@"; }

# ── Aliases ─────────────────────────────────────────
alias vsh="vim ~/.zshrc"
alias rsh="source ~/.zshrc"

# git
alias gs="git status"
alias gpullo="git pull origin"
alias gpusho="git push origin"
alias gco="git checkout"
alias gcm="git commit -m"

# python
alias pipf='pip freeze | grep'
alias pipi='pip install'

# python x uv
alias pyls='uv python list'
alias pycask='uv python install'

# ── uv ──────────────────────────────────────────────
# Corporate mode (optional) - uncomment on a corp machine behind a TLS proxy/Artifactory.
# Uses the OS cert store (avoids `invalid peer certificate: UnknownIssuer`) and picks up the
# Artifactory extra index from ~/.pip/pip.conf (single source of truth), so set that up first.
# export UV_SYSTEM_CERTS=1
# export UV_EXTRA_INDEX_URL="$(sed -n 's/^extra-index-url *= *//p' ~/.pip/pip.conf 2>/dev/null)"

# Set the global `python`/`python3` version via uv (installs it, links the
# shims in uv's bin dir, and pins it as uv's global default)
pyglobal() {
    [[ -z "$1" ]] && { echo "uso: pyglobal <version>"; return 1; }
    uv python install "$1" --default && uv python pin --global "$1"
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

