return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  -- Load for markdown files or specifically for files in your Obsidian vault
  event = {
    "BufReadPre /Users/greg/Library/Mobile Documents/iCloud~md~obsidian/Documents/Knowlage/**.md",
    "BufNewFile /Users/greg/Library/Mobile Documents/iCloud~md~obsidian/Documents/Knowlage/**.md",
  },
  -- Fallback to loading for all markdown files if the above doesn't work
  ft = "markdown",
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",
    -- Optional dependencies
    "nvim-telescope/telescope.nvim",
    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "/Users/greg/Library/Mobile Documents/iCloud~md~obsidian/Documents/Knowlage",
        -- Optional, override certain settings.
        -- overrides = {
        --   notes_subdir = "notes",
        --   daily_notes = {
        --     folder = "notes/dailies",
        --   },
        -- },
      },
      -- {
      --   name = "work",
      --   path = "~/vault-work",
      -- },
    },
    picker = {
      name = "telescope.nvim",
    },
    templates = {
      subdir = "templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
    },
    -- Fix open command for nushell/macOS
    -- Set to true to open in foreground (avoids --background flag issues)
    open_app_foreground = true,
    -- Don't use custom open_cmd - let obsidian.nvim handle it with foreground mode
    -- see below for full list of options 👇
  },
  config = function(_, opts)
    require("obsidian").setup(opts)
    
    -- Workaround for open command with nushell
    -- Patch the open_app function to avoid --background flag issues
    local obsidian = require("obsidian")
    if obsidian.util and obsidian.util.open_app then
      local original_open_app = obsidian.util.open_app
      obsidian.util.open_app = function(path, foreground)
        -- Use vim.fn.system with /bin/sh to avoid shell-specific issues
        local escaped_path = vim.fn.shellescape(path)
        local cmd = string.format("/bin/sh -c \"open -a '/Applications/Obsidian.app' %s\"", escaped_path)
        vim.fn.system(cmd)
      end
    end
  end,

  -- Optional, configure keymaps. See README for more information.
  keys = {
    {
      "<leader>on",
      "<cmd>ObsidianNew<cr>",
      desc = "New Obsidian note",
      mode = "n",
    },
    {
      "<leader>oq",
      "<cmd>ObsidianQuickSwitch<cr>",
      desc = "Quick Switch",
      mode = "n",
    },
    {
      "<leader>os",
      "<cmd>ObsidianSearch<cr>",
      desc = "Search notes",
      mode = "n",
    },
    {
      "<leader>ot",
      "<cmd>ObsidianTemplate<cr>",
      desc = "Insert template",
      mode = "n",
    },
    {
      "<leader>ob",
      "<cmd>ObsidianBacklinks<cr>",
      desc = "Show backlinks",
      mode = "n",
    },
    {
      "<leader>ol",
      "<cmd>ObsidianLink<cr>",
      desc = "Create/edit link",
      mode = "n",
    },
    {
      "<leader>oln",
      "<cmd>ObsidianLinkNew<cr>",
      desc = "Create new link",
      mode = "n",
    },
    {
      "<leader>od",
      "<cmd>ObsidianToday<cr>",
      desc = "Open today's daily note",
      mode = "n",
    },
    {
      "<leader>oy",
      "<cmd>ObsidianYesterday<cr>",
      desc = "Open yesterday's daily note",
      mode = "n",
    },
    {
      "<leader>otd",
      "<cmd>ObsidianTomorrow<cr>",
      desc = "Open tomorrow's daily note",
      mode = "n",
    },
    {
      "<leader>op",
      "<cmd>ObsidianPasteImg<cr>",
      desc = "Paste image",
      mode = "n",
    },
    {
      "<leader>orf",
      "<cmd>ObsidianRename<cr>",
      desc = "Rename note",
      mode = "n",
    },
    {
      "<leader>oc",
      "<cmd>ObsidianFollowLink<cr>",
      desc = "Follow link under cursor",
      mode = "n",
    },
    -- Replace the above if you only want to set it for markdown files in your vault:
    -- { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New Obsidian note", mode = "n", ft = "markdown" },
    -- { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open Obsidian (in app)", mode = "n", ft = "markdown" },
    -- { "<leader>os", "<cmd>ObsidianQuickSwitch<cr>", desc = "Quick Switch", mode = "n", ft = "markdown" },
    -- { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search notes", mode = "n", ft = "markdown" },
    -- { "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert template", mode = "n", ft = "markdown" },

    -- You can also put the above in "on_attach" in opts. see below 👇
  },
}

