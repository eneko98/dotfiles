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
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

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

------------------
---- KEYBINDS -----
------------------
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- Escape hatch. The session is started by hand from a TTY for now, so there
-- has to be a clean way back to it.
hl.bind(mainMod .. " + M", hl.dsp.exit())
