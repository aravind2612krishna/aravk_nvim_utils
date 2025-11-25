local M = {}
local ts_textobjects = nil

function M.setup()
    -- Helper to safely get the treesitter module
    M.ts_textobjects = require("nvim-treesitter-textobjects.nvim-treesitter.textobjects")
end

--- Performs a search for the word under the cursor, limited to the current function scope.
function M.search_current_function_word()
    if not M.ts_textobjects then
        vim.notify('Run setup() first', vim.log.levels.ERROR)
        return
    end

    -- 1. Get the word under the cursor
    local current_word = vim.fn.expand('<cword>')
    if current_word == '' then
        vim.notify('No word under cursor.', vim.log.levels.INFO)
        return
    end

    -- Escape magic regex characters in the word to ensure accurate search
    local escaped_word = vim.fn.escape(current_word, [[.^$~*[]\]])

    -- 2. Find the function node range
    -- We use the `af` (a-function) text object to reliably find the outer function boundary.
    local text_object = '@function.outer'
    local scope_range = M.ts_textobjects.select_textobject(text_object)

    if not scope_range then
        vim.notify('Could not find the current function scope.', vim.log.levels.WARN)
        return
    end

    -- The range is 0-indexed and [start_row, start_col, end_row, end_col]
    local start_line = scope_range[1] + 1 -- Convert 0-index to 1-index for Vim
    local end_line = scope_range[3]       -- Already on the end line

    -- 3. Construct and execute the scoped search command
    -- The search pattern uses `<` and `>` to ensure it's a whole-word match.
    -- The search command format is: {start_line},{end_line}/{pattern}
    local search_pattern = string.format([[\<%s\>]], escaped_word)
    local command = string.format(':%d,%d/%s<CR>', start_line, end_line, search_pattern)

    -- Execute the command
    vim.api.nvim_command(command)
    vim.notify(
        string.format(
            "Search started for '%s' scoped to lines %d through %d.",
            current_word,
            start_line,
            end_line
        ),
        vim.log.levels.INFO
    )
end

return M
