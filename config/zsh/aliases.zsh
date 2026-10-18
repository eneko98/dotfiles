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
