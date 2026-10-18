# The prompt: ours, not an oh-my-zsh theme.
#
# ZSH_THEME is empty in .zshrc, so none of oh-my-zsh's 143 bundled themes is in
# play and nothing overwrites PROMPT behind our back. oh-my-zsh itself stays --
# it is here for completion and its plugins, not for its looks.
#
# The colours come from theme.zsh, which scripts/gen-theme.py generates out of
# config/hypr/theme.lua, the one palette this desktop has. There is deliberately
# no hex value in this file: the values are generated, so they cannot drift.
#
#        ~/repos/dotfiles ❯                                    main*
#        ^ where you are    ^ shell state          ^ git, furthest from reach
#
# One line, and git is pushed to the right edge instead of trailing the path, so
# a deep path and a long branch name never compete for the same space.
#
# Which colour goes where, following theme.lua's rules:
#   * the path is fg1: information, but not what you are looking at.
#   * the arrow is the accent, gold, because it is the one thing the eye should
#     land on -- and it turns red when the last command failed. Red appears
#     nowhere else in this prompt, so red can only ever mean "that failed".
#   * git is fg2, the dimmest text colour. Staged and unstaged changes are gold
#     `+` and `●`, and a gold ↑/↓ shows commits ahead/behind the upstream -- the
#     one non-failure thing worth pointing at.
#   * teal is not used here at all. The terminal cursor is already teal, and two
#     neon things three characters apart read as noise, not as emphasis.

source "$ZDOTDIR/theme.zsh"

autoload -Uz add-zsh-hook vcs_info

# vcs_info, not the git plugin's git_prompt_info: vcs_info runs inside the shell,
# whereas git_prompt_info forks `git` twice on every single prompt. On a 5.7 GB
# machine that is a cost paid thousands of times a session for one short string.
zstyle ':vcs_info:git:*' check-for-changes true
# Staged and unstaged are told apart by the glyph, not by colour, so gold keeps
# its single meaning: "this tree needs your attention". `+` is staged (queued),
# `●` is unstaged (still in the working tree).
zstyle ':vcs_info:git:*' stagedstr   "%F{$THEME_GOLD}+%f"
zstyle ':vcs_info:git:*' unstagedstr "%F{$THEME_GOLD}●%f"
zstyle ':vcs_info:git:*' formats     "%F{$THEME_FG2}%b%f%u%c"
# No actionformats: a rebase or merge in progress is not something this prompt
# claims to know about yet.

# Ahead/behind, appended to the branch. One `git rev-list` per prompt, and only
# in a repo that actually has an upstream -- the hook returns otherwise, so a
# local-only repo costs nothing extra.
zstyle ':vcs_info:git*+set-message:*' hooks git-aheadbehind
function +vi-git-aheadbehind() {
    local counts behind ahead marks=""
    counts="$(command git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)" || return
    read -r behind ahead <<< "$counts"  # rev-list separates the two with a tab
    (( ahead )) && marks+=" %F{$THEME_GOLD}↑${ahead}%f"
    (( behind )) && marks+=" %F{$THEME_GOLD}↓${behind}%f"
    hook_com[branch]+="${marks}"
}

# The arrow, chosen by the previous exit status. %(?.true.false) is zsh's own
# conditional, so no function runs per prompt just to ask "did that work?".
_prompt_ok="%F{$THEME_GOLD}❯%f"
_prompt_bad="%F{$THEME_RED}❯%f"

# %3~ is the last three path components, with ~ for home: enough to know where
# you are, short enough to leave the line to the command. Change to %~ for the
# full path.
PROMPT="%F{$THEME_FG1}%3~%f %(?.${_prompt_ok}.${_prompt_bad}) "

# Continuation lines (an unclosed quote, a for loop). Dim, so it cannot be
# mistaken for the real prompt.
PROMPT2="%F{$THEME_FG2}… %f"

# RPROMPT is filled by the precmd hook rather than by ${vcs_info_msg_0_} written
# into RPROMPT directly: that would require `setopt prompt_subst`, which turns
# every literal $ in a prompt into a substitution. zsh draws the prompt after the
# precmd hooks have run, so the value is always this command's.
_prompt_git() {
    vcs_info
    RPROMPT="${vcs_info_msg_0_}"
}
add-zsh-hook precmd _prompt_git
