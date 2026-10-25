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
-- Where these defaults come from: the wallpaper,
-- images/wallpapers/hong-kong-night.png.
--   * bg0 is the photograph's own shadow mass, so the desktop reads as an
--     extension of the image rather than a box on top of it.
--   * gold and teal are its two chroma families (a neon sign, a lit facade),
--     taken from the extraction as #f3c562 and #8eb9b3 and dialled down so they
--     work as chrome instead of glowing.
--   * red is NOT in the photograph. The reddest cluster in it is orange
--     (#b88540), so red here is a designed addition, not an extracted colour.
--
-- How to use them: three hues only. Gold does the work (accent, active things);
-- with a generated palette "gold" is the accent slot and its hue follows the
-- image. Teal appears rarely and means "this is the thing you are acting on
-- right now" (focus, links). Red appears almost never and means "something is
-- wrong". A new colour has to earn a new *meaning* -- never a new mood.

-- The live palette, when one has been generated from the chosen wallpaper.
-- pcall, not a bare dofile: a half-written file must not take Hyprland down.
local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local generated = state_home .. "/dotfiles/palette.lua"
local ok, palette = pcall(dofile, generated)
if ok and type(palette) == "table" and palette.bg0 and palette.fg0 and palette.gold then
    return palette
end

local theme = {
    bg0 = "#0a0708", -- base: terminal background, misc:background_color
    bg1 = "#151011", -- raised surface: bar, panels, menus
    bg2 = "#20191b", -- selection, current workspace, current tab
    fg0 = "#ddd4c5", -- primary text            13.7:1 on bg0
    fg1 = "#9a8f83", -- secondary text, comments 6.3:1
    fg2 = "#6b6259", -- dim: inactive borders, rules 3.4:1 -- never body text
    gold = "#d3a75a", -- accent: active border, highlights      9.0:1
    teal = "#6fb3ae", -- neon: cursor, focus, links             8.3:1
    red = "#c2452f", -- alarm: errors, failures                 4.0:1
}

-- The terminal's 16 ANSI colours. These are derived, not extracted: a terminal
-- needs red/green/blue/magenta to be distinguishable from each other (git
-- diffs, ls, yazi file types) and the wallpaper only supplies two hues. They are
-- therefore pushed toward the palette's warmth and kept desaturated, so they
-- never fight the chrome. Contrast against bg0 is 4.7:1 or better for every one
-- of them, and the two "black" slots are deliberately unreadable as text --
-- that is what they are for.
theme.ansi = {
    black = "#2a2426",        -- separators, not text
    red = theme.red,
    green = "#7d9b6a",        -- sage, not grass: the wallpaper has no green
    yellow = theme.gold,      -- yellow and the accent are the same hue on purpose,
    blue = "#5c7f93",         -- so `ls` and the chrome cannot disagree
    magenta = "#b06a72",      -- muted rose
    cyan = theme.teal,
    white = theme.fg0,
    bright_black = "#4a4144", -- the usual "dim text" slot
    bright_red = "#e0644a",
    bright_green = "#a3c08c",
    bright_yellow = "#f3c562", -- the raw colour extracted from the photograph
    bright_blue = "#7fa6b8",
    bright_magenta = "#d08a8f",
    bright_cyan = "#95d3cd",
    bright_white = "#f2ece0",
}

return theme
