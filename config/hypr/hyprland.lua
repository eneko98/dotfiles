-- Hyprland configuration, in Lua.
-- Since Hyprland 0.55 hyprlang is deprecated and the config file is
-- hyprland.lua. Reference: https://wiki.hypr.land/Configuring/Start/
--
-- Deliberately minimal: this commit is only "a compositor that can open a
-- terminal". Bar, wallpaper, notifications and the colour theme each arrive in
-- their own later commit, so every line here should be explainable on its own.

local terminal = "kitty"

-- Every colour below comes from theme.lua, which is the palette the wallpaper
-- was reduced to. require() finds it because Hyprland puts the config directory
-- first in package.path, so plain require("theme") resolves
-- ~/.config/hypr/theme.lua -- no path juggling needed.
local theme = require("theme")

-- theme.lua stores plain #rrggbb, because that is what kitty and everything else
-- wants. Hyprland's own syntax is rgba(RRGGBBAA), so the conversion happens here,
-- once, instead of in the palette.
local function rgba(hex, alpha)
    return "rgba(" .. hex:gsub("#", "") .. (alpha or "ff") .. ")"
end

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

        -- The touchpad. These are written out even where they match the
        -- default, so the intent is visible and a future default cannot change
        -- it silently. natural_scroll is a taste call: false is traditional
        -- (sliding down scrolls down); flip it to true for content to follow
        -- your fingers. scroll_method no longer exists in this version -- the
        -- two-finger gesture is not configurable any more.
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
            disable_while_typing = true,
            tap_and_drag = true,
        },
    },
    misc = {
        -- No built-in wallpaper and no Hyprland logo behind the windows.
        -- A real wallpaper arrives later.
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        -- What Hyprland paints before the wallpaper is up, and what shows through
        -- if the wallpaper is ever missing. The photograph's shadow colour, so
        -- there is no flash of grey at login.
        background_color = rgba(theme.bg0),
    },
})

--------------------------------
---- COLOURS (from theme) ------
--------------------------------
-- The active border is where the accent colour is always visible, so it is gold,
-- drifting to the brighter gold the photograph actually produced (#f3c562) --
-- one hue, so it reads as a shine rather than two colours arguing.
--
-- Inactive windows get a dim warm grey at 60 % opacity instead of a second hue:
-- focus should be readable at a glance, and the dimmer the unfocused windows the
-- more the wallpaper shows through. Teal is deliberately not used here -- see
-- the palette notes in theme.lua.
hl.config({
    general = {
        col = {
            active_border = { colors = { rgba(theme.gold), rgba(theme.ansi.bright_yellow) }, angle = 45 },
            inactive_border = rgba(theme.fg2, "99"),
        },
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
---- GESTURES ----
------------------
-- Three-finger horizontal swipe switches workspaces, the gesture Hyprland
-- ships. `action = "workspace"` is the built-in swipe; the field also takes a
-- Lua function, so a custom gesture is a function here rather than a new
-- option somewhere. (The old gestures:workspace_swipe booleans are gone in
-- 0.56 -- the gesture is declared, not enabled.)
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

------------------
---- KEYBINDS -----
------------------
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
-- The launcher. $HOME rather than ~, because the command goes through sh -c.
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("fuzzel"))
-- The file manager, opened directly in a terminal. Closing yazi closes kitty.
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " yazi"))
-- Lock the session. hyprlock itself, not loginctl: hypridle already catches the
-- DBus lock event for the idle and sleep paths, and this way the key still works
-- if that daemon is ever stopped.
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Workspaces. Workspace 1..10, but the tenth key is "0", hence i % 10.
-- Unbound keys would otherwise be free keys, so all twenty get a bind: switch
-- with SUPER + <n>, send the focused window with SUPER + SHIFT + <n>.
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Cycle through the workspaces that actually exist, rather than the fixed
-- numbers: e+1 is "the next existing one". Same binding Hyprland ships.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Hardware keys. Brightness and volume reach the compositor as XF86 keysyms and
-- nothing handles them by default, so they are bound here. Volume is
-- wireplumber's wpctl; -l 1.0 stops the key from pushing past 100%.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- Brightness is brightnessctl, which can write the backlight as this user.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q set 5%+"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"))

-- Media keys, through playerctl, which talks to whatever MPRIS player is
-- running (mpv, Firefox, Spotify...). Play and Pause are separate keysyms on
-- some keyboards, so both are bound. With no player these just exit non-zero.
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("playerctl stop"))

-- Wi-Fi. Not on the laptop's own key: that one is already handled by the
-- kernel's built-in rfkill-input handler, so binding it here would toggle twice.
-- See config/hypr/scripts/wifi-toggle.
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/wifi-toggle"))

-- Clipboard history: fuzzel over `cliphist list`. The watcher that stores
-- copies is config/systemd/user/cliphist.service.
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/clipboard"))

-- Session menu: lock, log out, suspend, reboot or power off from a list.
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/session-menu"))

-- Screenshots: the whole screen, an area you drag over, or the focused window.
-- The helper script writes the file, copies it to the clipboard, and explains
-- what "the focused window" actually captures. Hyprland runs these through a
-- shell, so $HOME is expanded -- verified, not assumed.
local screenshot = "$HOME/.config/hypr/scripts/screenshot"

hl.bind("Print", hl.dsp.exec_cmd(screenshot))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(screenshot .. " area"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(screenshot .. " window"))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
-- Escape hatch back to the TTY. This goes through uwsm on purpose: the session
-- is no longer just a compositor, it is a set of systemd units, and killing the
-- compositor directly would yank it out from under its clients and skip the
-- ordered shutdown. See the uwsm wiki page, "Session termination".
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("uwsm stop"))
