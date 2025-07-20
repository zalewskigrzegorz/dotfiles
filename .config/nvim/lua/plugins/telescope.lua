return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  config = function()
    require("telescope").setup({
      defaults = {
        layout_config = {
          prompt_position = 'top',
        },
        sorting_strategy = 'ascending',
      },
    })
    require("telescope").load_extension("fzf")
  end,
  keys = {
    {
      "<leader>fh",
      function()
        require("telescope.builtin").find_files({ hidden = true, file_ignore_patterns = { "%.git/", "node_modules/", "%.DS_Store" } })
      end,
      desc = "Find Hidden Files",
    },
    {
      "<leader>f/",
      function()
        require("telescope.builtin").live_grep({ 
          additional_args = function() 
            return { "--hidden" } 
          end,
          file_ignore_patterns = { "%.git/", "node_modules/", "%.DS_Store" } 
        })
      end,
      desc = "Grep Hidden Files",
    },
  },
}