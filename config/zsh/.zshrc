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

# History is state. oh-my-zsh only falls back to ~/.zsh_history while this is
# unset, so it has to be set before oh-my-zsh is sourced.
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

ZSH_THEME="robbyrussell"

# "archlinux" ships with oh-my-zsh; "git" is oh-my-zsh's own default, kept
# because this repo leans on git constantly. The other three are Arch packages
# and are sourced by hand at the bottom, since oh-my-zsh only looks for plugins
# inside its own plugin directories.
plugins=(git archlinux)

# Completion definitions from the zsh-completions package. Must be added to
# fpath before oh-my-zsh runs compinit.
fpath=(/usr/share/zsh/plugins/zsh-completions/src $fpath)

source "$ZSH/oh-my-zsh.sh"

# --- plugins installed as Arch packages --------------------------------------
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Sourced last on purpose: this one wraps the ZLE widgets that the plugins
# above install.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
