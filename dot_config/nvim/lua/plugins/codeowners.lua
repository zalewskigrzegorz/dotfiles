return {
    "comatory/gh-co.nvim",
    cmd = {
        "GhCoWho",
        "GhCoWhos"
    },
    keys = {
        { "<leader>co", "<cmd>GhCoWho<cr>", desc = "  Show codeowners for open file" },
        { "<leader>cO", "<cmd>GhCoWhos<cr>", desc = "  Show codeowners for all open buffers" },
    },
}
