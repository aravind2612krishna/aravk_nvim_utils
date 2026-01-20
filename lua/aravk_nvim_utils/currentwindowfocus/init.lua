local currwinfocus = {}
currwinfocus.opts = {
    hl_focussedBorder = 'Question',
    hl_unfocussedBorder = 'Folded',
    hl_source = 'WinSeparator',
}

function currwinfocus.setup(opts)
    opts = vim.tbl_deep_extend('force', currwinfocus.opts, opts or {})
    -- Create an autocmd group
    local group = vim.api.nvim_create_augroup('CurrentWindowFocus', { clear = true })

    -- On WinLeave, update winhighlight to use unfocused border highlight
    vim.api.nvim_create_autocmd('WinLeave', {
        group = group,
        callback = function()
            if vim.wo.winhighlight:find(opts.hl_source) then
                vim.wo.winhighlight =
                    vim.wo.winhighlight:gsub(opts.hl_focussedBorder, opts.hl_unfocussedBorder)
            else
                vim.wo.winhighlight = vim.wo.winhighlight
                    .. ','
                    .. opts.hl_source
                    .. ':'
                    .. opts.hl_unfocussedBorder
            end
        end,
    })

    -- On WinEnter, update winhighlight to use focused border highlight
    vim.api.nvim_create_autocmd('WinEnter', {
        group = group,
        callback = function()
            if vim.wo.winhighlight:find(opts.hl_source) then
                vim.wo.winhighlight =
                    vim.wo.winhighlight:gsub(opts.hl_unfocussedBorder, opts.hl_focussedBorder)
            else
                vim.wo.winhighlight = vim.wo.winhighlight
                    .. ','
                    .. opts.hl_source
                    .. ':'
                    .. opts.hl_focussedBorder
            end
        end,
    })
end

return currwinfocus
