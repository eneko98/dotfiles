# Aliases for the interactive shell.
#
# `ls` and `cat` are the two commands typed without thinking, so they point at
# the modern replacements: lsd for colours and Nerd Font icons, bat for syntax
# highlighting. `cat` keeps cat's behaviour -- plain style, no pager -- so it
# stays safe in pipes and redirections. Use `bat` itself when you want line
# numbers and a pager.

alias ls='lsd'
alias ll='lsd -l'
alias la='lsd -A'
alias lt='lsd --tree'
alias cat='bat --style=plain --paging=never'

# bat's default theme has hardcoded colours of its own. `ansi` makes it use the
# terminal's 16 colours instead, which are this desktop's palette.
export BAT_THEME='ansi'

# --- paru, the AUR helper ------------------------------------------------------
# The oh-my-zsh archlinux plugin only creates its yay aliases when yay is
# installed, and this machine uses paru, so the equivalent set lives here. None
# of the names shadow a real command: `ps` and `pr` are left alone on purpose.

alias pupg='paru -Syu'         # upgrade the repos and the AUR in one run
alias pupd='paru -Sy'          # refresh the databases only
alias pmir='paru -Syy'         # force a full refresh
alias pin='paru -S'            # install, from the repos or the AUR
alias pdep='paru -S --asdeps'  # install as a dependency, not as explicit
alias pse='paru -Ss'           # search both the repos and the AUR
alias pinfo='paru -Si'         # show package details
alias prem='paru -Rns'         # remove, with dependencies and config
alias ploc='paru -Qi'          # details for an installed package
alias plocs='paru -Qs'         # search installed packages
alias pqe='paru -Qe'           # list explicitly installed packages
alias porph='paru -Qtd'        # list orphaned packages
alias pclean='paru -Sc'        # clean the package cache
alias pclr='paru -Scc'         # clean the whole cache
