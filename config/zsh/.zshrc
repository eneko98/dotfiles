# zsh configuration, for interactive shells.
#
# zsh is pointed at this directory by /etc/zsh/zshenv (see the README) rather
# than reading ~/.zshrc, which is why nothing here lives in $HOME. The runtime
# state and cache below follow the same idea.

# --- oh-my-zsh ---------------------------------------------------------------
# Cloned into XDG_DATA_HOME instead of the usual ~/.oh-my-zsh.
export ZSH="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"

# Generated files are cache, not config. This has to exist before oh-my-zsh
# looks at it: if the directory is not writable it silently falls back to its
# own location.
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

# Where compinit writes its dump. Left alone, oh-my-zsh puts it at
# $ZDOTDIR/.zcompdump-*, i.e. a generated file appearing inside this config
# directory.
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-${HOST}"

# The only editor installed on this machine.
export EDITOR="nvim"
export VISUAL="nvim"

# History is state. oh-my-zsh only falls back to ~/.zsh_history while this is
# unset, so it has to be set before oh-my-zsh is sourced.
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

# Empty on purpose. oh-my-zsh only sources a theme `if [[ -n "$ZSH_THEME" ]]`,
# so an empty value hands the prompt to us -- config/zsh/prompt.zsh, sourced
# below. The 143 bundled themes stay unused: each decides for itself what
# deserves colour, and this desktop's palette is a small, deliberate set of
# meanings that the prompt has to follow. oh-my-zsh is still here for its
# completion and its plugins, which are independent of the theme.
ZSH_THEME=""

# "archlinux" ships with oh-my-zsh; "git" is oh-my-zsh's own default, kept
# because this repo leans on git constantly. The other three are Arch packages
# and are sourced by hand at the bottom, since oh-my-zsh only looks for plugins
# inside its own plugin directories.
plugins=(git archlinux)

# Completion definitions from the zsh-completions package. Must be added to
# fpath before oh-my-zsh runs compinit.
fpath=(/usr/share/zsh/plugins/zsh-completions/src $fpath)

source "$ZSH/oh-my-zsh.sh"

# --- the prompt ---------------------------------------------------------------
# Ours, and it has to come after oh-my-zsh so that nothing overwrites PROMPT.
# It is loaded before the two plugin files below only because those are about
# input handling; the "syntax-highlighting last" rule further down concerns ZLE
# widgets, which prompt.zsh does not touch -- it sets PROMPT/RPROMPT, reads the
# palette from the generated theme.zsh, and adds one precmd hook.
source "$ZDOTDIR/prompt.zsh"

# --- aliases ------------------------------------------------------------------
source "$ZDOTDIR/aliases.zsh"

# --- directory jumping and fuzzy finding -------------------------------------
# zoxide learns where you cd, so `z foo` jumps to the most likely directory.
eval "$(zoxide init zsh)"

# fzf key bindings and completion. These install ZLE widgets, so they must be
# sourced before zsh-syntax-highlighting.
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# --- yazi --------------------------------------------------------------------
# Wrapper that cd's into the directory yazi was last in when you quit.
function y() {
    local tmp
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [[ -n "$cwd" ]] && [[ "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd" || return
    fi
    rm -f -- "$tmp"
}

# --- plugins installed as Arch packages --------------------------------------
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Sourced last on purpose: this one wraps the ZLE widgets that the plugins
# above install.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
