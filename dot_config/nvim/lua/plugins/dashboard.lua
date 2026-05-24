-- Snacks dashboard header — Mocha Neon heraldic unicorn (chafa braille render
-- from openclipart.org/detail/338103, CC0).
-- Two animated regions:
--   * SnacksDashUnicornBody  — whole body cycles through the 8 Mocha Neon
--                              accents (mauve → pink → lavender → cyan →
--                              green → gold → orange → red → mauve), 20s
--                              total cycle, smooth lerp between neighbours.
--   * SnacksDashUnicornFlame — speed-trail behind back hooves (right edge of
--                              body_lines[14] + body_lines[15]). Red → orange
--                              → gold flicker, 200ms per frame.
-- Horn stays static gold.

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    local palette = {
      horn  = "#FFD700",
      -- 8-stop color cycle for the body. Only colors that read clearly on
      -- the #1E1E2E base — surface / overlay / muted greys are skipped.
      cycle = {
        "#B347FF", -- mauve
        "#FF80BF", -- pink
        "#9580FF", -- lavender
        "#8BE9FD", -- cyan
        "#50FA7B", -- green
        "#FFD700", -- gold
        "#FF8C42", -- orange
        "#FF6B9D", -- red
      },
      flame = { "#FF6B9D", "#FF8C42", "#FFD700" },
    }

    vim.api.nvim_set_hl(0, "SnacksDashUnicornHorn", { fg = palette.horn, bold = true })

    local function hex(c) return tonumber(c, 16) end
    local function lerp_hex(c1, c2, t)
      local function l(a, b) return math.floor(a + (b - a) * t + 0.5) end
      return string.format("#%02x%02x%02x",
        l(hex(c1:sub(2, 3)), hex(c2:sub(2, 3))),
        l(hex(c1:sub(4, 5)), hex(c2:sub(4, 5))),
        l(hex(c1:sub(6, 7)), hex(c2:sub(6, 7))))
    end

    if _G.__SnacksDashUnicornTimers then
      for _, t in ipairs(_G.__SnacksDashUnicornTimers) do
        pcall(function() t:stop() end)
        pcall(function() t:close() end)
      end
    end
    _G.__SnacksDashUnicornTimers = {}
    local function start_timer(ms, fn)
      local t = vim.uv.new_timer()
      table.insert(_G.__SnacksDashUnicornTimers, t)
      t:start(0, ms, vim.schedule_wrap(fn))
    end

    -- Body color cycle: smooth lerp through every palette stop.
    -- 12 ticks per segment × 8 segments × 100ms = ~10s full cycle (2× speed).
    local seg_ticks = 12
    local total_ticks = #palette.cycle * seg_ticks
    local body_tick = 0
    start_timer(100, function()
      body_tick = (body_tick + 1) % total_ticks
      local seg = math.floor(body_tick / seg_ticks)
      local t = (body_tick % seg_ticks) / seg_ticks
      local c1 = palette.cycle[seg + 1]
      local c2 = palette.cycle[(seg + 1) % #palette.cycle + 1]
      vim.api.nvim_set_hl(0, "SnacksDashUnicornBody",
        { fg = lerp_hex(c1, c2, t), bold = true })
    end)

    -- Flame flicker: discrete red → orange → gold frame rotation, 200ms each.
    local flame_tick = 0
    start_timer(200, function()
      flame_tick = (flame_tick + 1) % 3
      vim.api.nvim_set_hl(0, "SnacksDashUnicornFlame",
        { fg = palette.flame[flame_tick + 1], bold = true })
    end)

    -- 32×16 braille unicorn. body_lines[14] + [15] carry trail splits.
    local horn = "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⡀⠀⢀⡠⠔⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"

    -- body_lines[14]: keep up to col 25, trail at cols 26-31.
    local b14_prefix = "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⢿⡟⡟⠇⠀⠀⠀⠀⠀⢠⣶⡿⡙⠄"
    local b14_trail  = "⣀⣀⣄⣄⠆⠂"

    -- body_lines[15]: keep up to col 23, trail at cols 24-31.
    local b15_prefix = "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠛⠁⠀⠀⠀⠀⠀⠀⢀⢾⣿⠉⠁"
    local b15_trail  = "⣶⣶⣦⣄⠆⠂⠁⠁"

    local body_lines = {
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
      "<<SPLIT_TRAIL_14>>",
      "<<SPLIT_TRAIL_15>>",
    }

    -- Build per-line sections (padding=0 so they stack tight like one block).
    local function plain(line)
      return { text = { { line, hl = "SnacksDashUnicornBody" } }, align = "center", padding = 0 }
    end
    local function chunks(c) return { text = c, align = "center", padding = 0 } end

    local sections = {
      chunks({ { horn, hl = "SnacksDashUnicornHorn" } }),
    }
    for _, line in ipairs(body_lines) do
      if line == "<<SPLIT_TRAIL_14>>" then
        table.insert(sections, chunks({
          { b14_prefix, hl = "SnacksDashUnicornBody"  },
          { b14_trail,  hl = "SnacksDashUnicornFlame" },
        }))
      elseif line == "<<SPLIT_TRAIL_15>>" then
        table.insert(sections, chunks({
          { b15_prefix, hl = "SnacksDashUnicornBody"  },
          { b15_trail,  hl = "SnacksDashUnicornFlame" },
        }))
      else
        table.insert(sections, plain(line))
      end
    end
    table.insert(sections, { padding = 1 })
    table.insert(sections, { section = "keys", gap = 1, padding = 1 })
    table.insert(sections, { section = "recent_files", icon = " ", padding = 1, limit = 3 })
    table.insert(sections, { section = "startup" })

    opts.dashboard = opts.dashboard or {}
    opts.dashboard.sections = sections
  end,
}
