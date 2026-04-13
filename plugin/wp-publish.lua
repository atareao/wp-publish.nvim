if vim.fn.has("nvim-0.7.0") == 0 then
  return
end

vim.api.nvim_create_user_command("WPPublish", function()
    require("wp-publish").publish()
end, {})

local group = vim.api.nvim_create_augroup("WPPublishGroup", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = "*.md", -- Only for markdown files
    callback = function()
        require("wp-publish").update_timestamp()
    end,
})
