-- nvim half of the ChmaraX/herdr-nvim herdr plugin (installed by
-- run_onchange_after_34-herdr-plugins-sync). The herdr half gives the sidebar
-- (prefix+e) and the agent-touched file picker (prefix+o); this half adds the
-- code annotations you send back to the agent.
--
-- Defaults, all under <leader>a: ac = comment line/selection, al = list,
-- as = paste into the agent's input, aS = paste and submit.
return {
    "ChmaraX/herdr-nvim",
    -- Outside a herdr pane there is no agent to talk to, so don't load it (the
    -- lab has herdr too, hence the env check rather than an OS check).
    cond = function()
        return vim.env.HERDR_PANE_ID ~= nil
    end,
    opts = {},
}
