-- Hyprland configuration, in Lua.
-- Since Hyprland 0.55 hyprlang is deprecated and the config file is
-- hyprland.lua. Reference: https://wiki.hypr.land/Configuring/Start/
--
-- Deliberately minimal: this commit is only "a compositor that can open a
-- terminal". Bar, wallpaper, notifications and the colour theme each arrive in
-- their own later commit, so every line here should be explainable on its own.

local terminal = "kitty"

-----------------
---- MONITOR -----
-----------------
-- Empty output means "whatever monitor is connected". Preferred mode and
-- automatic positioning are fine for a single built-in laptop panel.
--
-- Scale is pinned to 1 deliberately. The stock config uses "auto", which lets
-- Hyprland derive a scale from the panel's PPI; this 1080p panel reports
-- 310x170 mm (~158 PPI), so auto picked 1.5. That does not add detail -- there
-- are no more physical pixels to show -- it just draws everything 1.5x larger
-- and shrinks the usable desktop to 1280x720. At scale 1 the panel is driven
-- natively at its full 1920x1080.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

----------------
---- CURSOR -----
----------------
-- Set explicitly, and not as a stylistic preference: this system had no cursor
-- theme installed at all (no /usr/share/icons/*/cursors existed), so there was
-- nothing to draw. adwaita-cursors was installed for this commit; a cursor that
-- matches the theme can replace it later.
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")

------------------
---- KEYBOARD -----
------------------
hl.config({
    input = {
        -- The machine's vconsole keymap is "es" too.
        kb_layout = "es",
    },
    misc = {
        -- No built-in wallpaper and no Hyprland logo behind the windows.
        -- A real wallpaper arrives later.
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
    },
})

----------------
---- LAYOUT ----
----------------
-- New windows open to the right of (or below) the focused one. The default,
-- force_split = 0, places them relative to the mouse instead: a new terminal
-- lands on the left whenever the cursor happens to sit in the left half of the
-- window. 1 forces left/top, 2 forces right/bottom.
hl.config({
    dwindle = {
        force_split = 2,
    },
})

------------------
---- KEYBINDS -----
------------------
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- Escape hatch back to the TTY. This goes through uwsm on purpose: the session
-- is no longer just a compositor, it is a set of systemd units, and killing the
-- compositor directly would yank it out from under its clients and skip the
-- ordered shutdown. See the uwsm wiki page, "Session termination".
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("uwsm stop"))
