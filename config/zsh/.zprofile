# Login-shell startup.
#
# zsh reads this file only for *login* shells, which is exactly what makes it the
# right place to hand a TTY over to the desktop. /etc/zsh/zshenv is what points
# zsh at this directory in the first place.
#
# "uwsm check may-start" does all the safety work here. It only returns true when
# all of these hold:
#
#   - the shell really is a login shell
#   - the system has reached graphical.target
#   - no graphical session for this user is running already
#   - the current VT is tty1 (the default it checks for)
#
# So every other VT, and every shell that is not a fresh login, is left as an
# ordinary shell. That is what makes tty2 a reliable escape hatch.
#
# The command is lifted from the session entry Hyprland itself ships,
# /usr/share/wayland-sessions/hyprland-uwsm.desktop, so a session started from
# the TTY behaves identically to one started by a display manager.
if uwsm check may-start; then
    exec uwsm start -e -D Hyprland hyprland.desktop
fi
