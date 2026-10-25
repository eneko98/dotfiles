-- The palette: this file is the committed default.
--
-- Hyprland requires this file (config/hypr/hyprland.lua, `require("theme")`) and
-- paints its borders and its background from it. When a wallpaper has generated
-- one, the *active* palette is $XDG_STATE_HOME/dotfiles/palette.lua
-- (scripts/extract-palette.py) and the loader below returns it instead of the
-- table here; deleting that file, or running `extract-palette.py --reset`, comes
-- back to these values.
--
-- Nothing else reads Lua, so scripts/gen-theme.py writes the copies the other
-- programs need from the active palette, under $XDG_STATE_HOME/dotfiles/theme/
-- (not into the repository: the palette follows the wallpaper, which is machine
-- state). scripts/install.sh links each copy to the fixed path its program
-- expects. `scripts/gen-theme.py --check` reports a stale copy.
--
-- The default is the blue/violet palette the watchtower wallpaper produced,
-- curated here so a fresh clone (or `extract-palette.py --reset`) has it without
-- needing the image. A generated palette in XDG_STATE_HOME wins when a wallpaper
-- is picked.
--
-- How to use them: three hues only. `gold` is the accent slot -- the name is
-- historical; the default is a cyan blue (#5eadcc) -- and does the work (active
-- things). `teal` is the neon (#ab8bd2, a muted violet) and means "this is the
-- thing you are acting on right now" (focus, links). Red appears almost never and
-- means "something is wrong". A new colour has to earn a new *meaning* -- never
-- a new mood.

-- The live palette, when one has been generated from the chosen wallpaper.
-- pcall, not a bare dofile: a half-written file must not take Hyprland down.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local generated = state_home .. "/dotfiles/palette.lua"
local ok, palette = pcall(dofile, generated)
if ok and type(palette) == "table" and palette.bg0 and palette.fg0 and palette.gold then
    return palette
end

local theme = {
    bg0 = "#06060a", -- base: terminal background, misc:background_color
    bg1 = "#0e0e15", -- raised surface: bar, panels, menus
    bg2 = "#171621", -- selection, current workspace, current tab
    fg0 = "#d0d0da", -- primary text            13.2:1 on bg0
    fg1 = "#86859b", -- secondary text, comments 5.6:1
    fg2 = "#5f5f70", -- dim: inactive borders, rules 3.2:1 -- never body text
    gold = "#5eadcc", -- accent: active border, highlights      8.0:1
    teal = "#ab8bd2", -- neon: cursor, focus, links             7.1:1
    red = "#c6482f", -- alarm: errors, failures                 4.2:1
}

-- The terminal's 16 ANSI colours. The accent and the neon follow the palette;
-- green, blue and magenta are fixed, muted hues so a terminal keeps them
-- distinguishable from each other (git diffs, ls, yazi file types). Every slot
-- except the two "black" ones is contrast-checked against bg0, and those two are
-- deliberately unreadable as text -- that is what they are for.
theme.ansi = {
    black = "#201f28",        -- separators, not text
    red = theme.red,
    green = "#60864d",        -- fixed hue, not from the palette
    yellow = theme.gold,      -- the accent slot, whatever its hue
    blue = "#56819f",         -- fixed hue
    magenta = "#b06b77",      -- fixed muted rose
    cyan = theme.teal,        -- the neon
    white = theme.fg0,
    bright_black = "#3d3d4d",
    bright_red = "#d86f5a",
    bright_green = "#7da868",
    bright_yellow = "#85c1d8", -- the accent, lightened
    bright_blue = "#7b9fb7",
    bright_magenta = "#c5939c",
    bright_cyan = "#c6b0e0",
    bright_white = "#e1e1e7",
}

return theme
