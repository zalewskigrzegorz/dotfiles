-- Snacks dashboard header — Mocha Neon heraldic unicorn (chafa braille render
-- from openclipart.org/detail/338103, CC0). Subtle breathing animation:
-- whole body cycles mauve <-> pink over 4s, horn stays static gold.
--
-- If you want mane-specific animation later, split the art string per row
-- into chunks by column range and assign two highlight groups (one static,
-- one cycling). Region map: mane=lines 3-7 cols 0-7, tail=lines 2-7 cols
-- 25-31, horn=line 0 cols 10-17, body/legs=everything else.

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    local palette = {
      horn = "#FFD700", -- gold
      a    = "#B347FF", -- mauve (cycle start)
      b    = "#FF80BF", -- pink  (cycle end)
    }

    vim.api.nvim_set_hl(0, "SnacksDashUnicornHorn", { fg = palette.horn, bold = true })
    vim.api.nvim_set_hl(0, "SnacksDashUnicornBody", { fg = palette.a, bold = true })

    -- Triangle-wave color interpolation between mauve and pink, 4s cycle.
    -- Updates the SnacksDashUnicornBody highlight in place. 100ms tick keeps
    -- CPU negligible and motion smooth.
    local function hex(c) return tonumber(c, 16) end
    local function lerp(c1, c2, t) return math.floor(c1 + (c2 - c1) * t + 0.5) end
    local function color_at(t)
      local r = lerp(hex(palette.a:sub(2, 3)), hex(palette.b:sub(2, 3)), t)
      local g = lerp(hex(palette.a:sub(4, 5)), hex(palette.b:sub(4, 5)), t)
      local b = lerp(hex(palette.a:sub(6, 7)), hex(palette.b:sub(6, 7)), t)
      return string.format("#%02x%02x%02x", r, g, b)
    end

    -- Stop any previous timer (config reload safety).
    if _G.__SnacksDashUnicornTimer then
      pcall(function() _G.__SnacksDashUnicornTimer:stop() end)
      pcall(function() _G.__SnacksDashUnicornTimer:close() end)
    end
    local timer = vim.uv.new_timer()
    _G.__SnacksDashUnicornTimer = timer
    local tick = 0
    timer:start(0, 100, vim.schedule_wrap(function()
      tick = (tick + 1) % 40
      local t = tick < 20 and tick / 20 or (40 - tick) / 20
      vim.api.nvim_set_hl(0, "SnacksDashUnicornBody", { fg = color_at(t), bold = true })
    end))

    -- Two-section header: horn on its own line (static gold), body below
    -- (animated mauve <-> pink). Each section centers itself in the dashboard.
    -- 32×16 braille render (chafa from openclipart 338103). Biggest size
    -- before menu items risk falling off screen on a 1440-ish vertical
    -- terminal. Reduce to 28×14 / 24×12 here if you ever shrink the term.
    local horn = "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⡀⠀⢀⡠⠔⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
    local body = table.concat({
      "⠀⠀⠀⠀⢀⠀⠀⣀⣤⣤⣿⣶⣞⣤⠖⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
      "⠀⠀⠀⠀⠈⠻⣿⣟⣿⣿⣿⣿⣟⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢐⣹⠆",
      "⠈⢦⣀⣀⣤⣾⣿⣽⣿⣿⣿⠿⣿⡿⢷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⠾⠻⢧⡠",
      "⠀⠀⠈⠉⣰⣿⣿⣿⣿⣿⣿⡀⢰⣽⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣧⡾⠻⣆⠄",
      "⠀⠀⣀⡤⢿⡏⡿⢿⣿⣿⣿⣷⣌⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⡦⠝⠀⠀",
      "⠀⠀⠀⠀⣋⣈⡂⠸⣿⣿⣿⣿⣿⣷⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣷⣄⣠",
      "⠀⠀⠀⣰⠟⠛⠻⢿⣟⢿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣤⡀⠀⠀⠀⠀⠀⢸⣿⣯⠀⡀⠀",
      "⠀⠀⣾⡿⠂⠀⠀⠀⣡⣾⠟⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣦⣤⣤⣤⣾⣿⣛⠓⠛⠀",
      "⠀⠀⢾⣷⠄⠀⠀⡾⠟⠁⠀⠀⠀⣼⣿⣭⣟⢿⣿⣿⣿⣿⡆⢹⣿⣿⣿⠉⣻⡇⠀⠀",
      "⠀⠀⠈⢀⣀⣤⣾⠁⠀⠀⠀⠀⢸⣿⣿⣿⣿⠾⣿⣿⣿⣿⡇⠚⢕⠃⠸⠀⠈⠀⠀⠀",
      "⠀⠀⠐⠿⡿⠹⠙⠀⠀⠀⠀⠀⠀⠻⣿⣿⡁⠀⠙⢿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀",
      "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣷⡄⠀⠀⠈⠉⠛⢻⣿⠇⠀⠀⠀⠀⠀⠀",
      "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠛⠁⠀⠀⠀⠀⠀⣸⣏⠀⠀⠀⠀⠀⠀⠀",
      "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⢿⡟⡟⠇⠀⠀⠀⠀⠀⢠⣶⡿⡙⠄⠀⠀⠀⠀⠀⠀",
      "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠁⠀⠀⠀⠀⠀⠀⢀⢾⣿⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀",
    }, "\n")

    -- Sections: unicorn header (horn + animated body) → keys menu → 3 recent
    -- files → startup line. No projects section (user finds it noisy).
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.sections = {
      { text = { { horn, hl = "SnacksDashUnicornHorn" } }, align = "center" },
      { text = { { body, hl = "SnacksDashUnicornBody" } }, align = "center" },
      { padding = 1 },
      { section = "keys", gap = 1, padding = 1 },
      { section = "recent_files", icon = " ", padding = 1, limit = 3 },
      { section = "startup" },
    }
  end,
}
