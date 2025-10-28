local M =  {}


function M.tagstack_to_qflist()
    local ts = vim.fn.gettagstack(vim.fn.win_getid())
    local items = {}
    -- for i = #ts.items, 1, -1 do
    --   local tag = ts.items[i]
    for _, tag in ipairs(ts.items or {}) do
        local from = tag.from
        local filename = from and vim.fn.bufname(from[1]) or nil
        local lnum = from and from[2] or 1
        local col = from and from[3] or 1
        table.insert(items, {
            filename = filename,
            lnum = lnum,
            col = col,
            text = tag.tagname,
        })
    end
    vim.fn.setqflist({}, ' ', { title = 'Tag Stack (from, reversed)', items = items })
end

function M.export_tagstack(filename)
    if not filename then
        filename = "tagstack.json"
    end
    local qflist = vim.fn.getqflist()
    local items = {}
    for _, item in ipairs(qflist) do
        table.insert(items, {
            filename = item.bufnr and vim.fn.bufname(item.bufnr) or item.filename,
            lnum = item.lnum,
            col = item.col,
            text = item.text,
            type = item.type,
        })
    end
    local json = vim.fn.json_encode(items)
    local file = io.open(filename, "w")
    if file then
        file:write(json)
        file:close()
    end
end

function M.import_tagstack(filename)
    if not filename then
        filename = "tagstack.json"
    end
    local file = io.open(filename, "r")
    if not file then
        print("Could not open file: " .. filename)
        return
    end
    local json = file:read("*a")
    file:close()
    local items = vim.fn.json_decode(json)
    -- local qflist_items = {}
    -- for _, item in ipairs(items) do
    --     table.insert(qflist_items, {
    --         filename = item.filename,
    --         lnum = item.lnum,
    --         col = item.col,
    --         text = item.text,
    --         type = item.type,
    --     })
    -- end
    vim.fn.setqflist({}, ' ', { title = 'Imported Tag Stack', items = items })
end

function M.setup()
    _G.TagStackUtils = require('aravk_nvim_utils.tagstackutils')
end

return M
