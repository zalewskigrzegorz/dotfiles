-- Names and icons for leader keys that plugins map without a which-key group
-- (herdr-nvim, obsidian.nvim) or without an icon (LazyVim's Keywordprg), plus
-- the markdown checkbox toggle from config/autocmds.lua.
return {
    "folke/which-key.nvim",
    opts = {
        spec = {
            { "<leader>a", group = "agent", icon = { icon = "󰚩 ", color = "purple" } },
            { "<leader>o", group = "obsidian", icon = { icon = "󰠮 ", color = "purple" } },
            { "<leader>K", desc = "Keywordprg", icon = { icon = "󰋖 ", color = "azure" } },
            { "<leader>m", desc = "Toggle checkbox", icon = { icon = "󰄲 ", color = "green" }, mode = { "n", "x" } },
        },
    },
}
