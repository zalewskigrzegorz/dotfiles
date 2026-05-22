local settings = require("settings")

-- Mocha Neon palette (Catppuccin Mocha + bumped accents)
-- Previous Dracula values preserved at bottom for 1-week rollback safety.
return {
    purple    = 0xff9580ff,   -- lavender
    black     = 0xff1e1e2e,   -- base
    white     = 0xfff0f0ff,   -- text bumped
    red       = 0xffff6b9d,   -- red bumped
    green     = 0xff50fa7b,   -- green bumped
    blue      = 0xff8be9fd,   -- sky bumped (info / cyan)
    yellow    = 0xffffd700,   -- gold bumped
    orange    = 0xffff8c42,   -- peach bumped
    magenta   = 0xffff80bf,   -- pink bumped
    grey      = 0xff7f849c,   -- overlay1
    light_grey= 0xffa6adc8,   -- subtext0
    dark_grey = 0xff45475a,   -- surface1
    bright_red = 0xffff6b9d,
    bright_green = 0xff50fa7b,
    transparent = 0x00000000,

    bar = {
        bg = 0xd01e1e2e,
        border = 0xff585b70
    },
    popup = {
        bg = 0xc01e1e2e,
        border = 0xffb347ff
    },
    bg1 = 0xff1e1e2e,
    bg2 = 0xff45475a,

    rainbow = {0xffff6b9d, 0xff50fa7b, 0xff9580ff, 0xffffd700, 0xffff8c42, 0xffff80bf, 0xff8be9fd, 0xffb347ff},

    with_alpha = function(color, alpha)
        if alpha > 1.0 or alpha < 0.0 then
            return color
        end
        return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
    end
}

--[[ PREVIOUS DRACULA PALETTE (kept for 1-week rollback safety):
return {
    purple = 0xff9580ff,
    black = 0xff22212c,
    white = 0xfff8f8f2,
    red = 0xffff9580,
    green = 0xff8aff80,
    blue = 0xff80ffea,
    yellow = 0xffffff80,
    orange = 0xffffca80,
    magenta = 0xffff80bf,
    grey = 0xff7970a9,
    light_grey = 0xffc6c6c2,
    dark_grey = 0xff454158,
    bright_red = 0xffffaa99,
    bright_green = 0xffa2ff99,
    transparent = 0x00000000,
    bar = { bg = 0xd022212c, border = 0xff504c67 },
    popup = { bg = 0xc022212c, border = 0xff9580ff },
    bg1 = 0xff22212c,
    bg2 = 0xff454158,
    rainbow = {0xffff9580, 0xff8aff80, 0xff9580ff, 0xffffff80, 0xffffca80, 0xffff80bf, 0xff80ffea, 0xffaa99ff},
}
]]
