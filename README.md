# Dotfiles Configuration

This repository contains my personal dotfiles configuration for macOS and Linux systems. It includes configuration files for iTerm2, Oh-My-Zsh, pyenv, virtualenv, and SSH settings.

## Getting Started

Follow the specific instructions below to configure each component:

- iTerm2 + Oh-My-Zsh Installtion: https://catalins.tech/improve-mac-terminal/
- pyenv, virtualenv and using them with Jupyter: https://albertauyeung.github.io/2020/08/17/pyenv-jupyter.html
- Turn on the 1Password SSH agent: https://developer.1password.com/docs/ssh/get-started/#step-3-turn-on-the-1password-ssh-agent
- Modify caps lock key as esc: [Ubuntu](https://dev.to/yuyabu/how-to-use-caps-lock-key-as-esc-on-ubuntu-18-1g7l) | [macOS](https://vim.fandom.com/wiki/Map_caps_lock_to_escape_in_macOS)
- Claude skills: `ln -s ./dotfiles/skills ~/.claude/skills` - More info on official [Claude skills doc](https://code.claude.com/docs/en/skills)
- [uv](https://docs.astral.sh/uv/) for Python version and virtualenv management:
  - Install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
  - Install a Python version: `uv python install 3.12`
  - Create a project virtualenv: `uv venv` (defaults to `.venv`, picks up `.python-version` if present). Or you can directly specify the python version like `uv venv -p 3.12`.
  - Activate it: `source .venv/bin/activate`
  - Add/install deps: `uv add <package>` or `uv pip install -r requirements.txt`
  - Pin the Python version for a project: `uv python pin 3.12`
  - **Corporate machine only** (behind the corporate TLS proxy/Artifactory): set up `~/.pip/pip.conf` first (see pip docs for the `[global]`/`extra-index-url`/`trusted-host` format), then `.zshrc` sets `UV_SYSTEM_CERTS=1` (trust the OS cert store instead of uv's bundled one, needed or you'll get `invalid peer certificate: UnknownIssuer`) and exports `UV_EXTRA_INDEX_URL` from `~/.pip/pip.conf`'s `extra-index-url`, so `uv` resolves private packages through the same index as `pip`

