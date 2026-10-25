# Login-shell startup.
#
# The graphical session is started by the login screen now: greetd starts
# regreet, which lists the session entries; pick "Hyprland (uwsm-managed)" so
# the session stays a systemd user session. The old tty1 autologin and this
# file's `exec uwsm start` are gone, so a TTY login stays a shell on purpose —
# tty2 is the escape hatch when the login screen misbehaves.
#
# To start a session by hand from a TTY:
#   uwsm start -e -D Hyprland hyprland.desktop
