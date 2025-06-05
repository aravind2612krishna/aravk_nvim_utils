local M = {}

M.addmd = false
M.addhtml = false

M.opts = {
  -- The keymap to copy the code
  keymap = '<leader>sc',
  addFunction = true,
}

local function get_current_context_from_lsp()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if LSP is attached to the current buffer
  local clients = vim.lsp.buf_get_clients(bufnr)
  if vim.tbl_isempty(clients) then
    print('No LSP clients attached to the current buffer')
    return
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params() }

  -- Send the request to the language server
  vim.lsp.buf_request(
    bufnr,
    'textDocument/documentSymbol',
    params,
    function(err, result, ctx, config)
      if err then
        print('Error: ', err)
        return
      end

      if not result or vim.tbl_isempty(result) then
        print('No symbols found')
        return
      end

      local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
      local context = {}

      -- Helper function to find the context recursively
      local function find_context(symbols)
        for _, symbol in ipairs(symbols) do
          if
            symbol.range.start.line <= current_line and symbol.range['end'].line >= current_line
          then
            table.insert(context, symbol.name)
            if symbol.children then
              find_context(symbol.children)
            end
          end
        end
      end

      find_context(result)

      -- Print the context
      print('Current context: ' .. table.concat(context, ' -> '))
    end
  )
end

-- Function to get the current function declaration
local function get_function_declaration()
  local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
  if not ok then
    return nil
  end
  local node = ts_utils.get_node_at_cursor()
  local rootfound = nil
  while node do
    if
      node:type() == 'function_definition'
      or node:type() == 'translation_unit'
      or node:type() == 'ERROR'
    then
      rootfound = node
      -- vim.print(node:type())
      break
    end
    node = node:parent()
  end
  if rootfound then
    for namedChild in rootfound:iter_children() do
      -- node = rootfound:named_child(1)
      -- vim.print(namedChild:type())
      if
        namedChild
        and (
          namedChild:type() == 'function_declarator'
          or namedChild:type() == 'declarator'
          or namedChild:type() == 'name'
        )
      then
        return namedChild
      end
    end
  end
  return nil
end

local function get_function_decl_lines()
  local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
  local func_decl_lines = ''
  if not ok then
    return func_decl_lines
  end
  local node = ts_utils.get_node_at_cursor()
  local rootfound = nil
  while node do
    if
      node:type() == 'function_definition'
      or node:type() == 'class_specifier'
      or node:type() == 'translation_unit'
      or node:type() == 'ERROR'
    then
      rootfound = node
      -- vim.print(node:type())
      break
    end
    node = node:parent()
  end
  if
    rootfound
    and (rootfound:type() == 'function_definition' or rootfound:type() == 'class_specifier')
  then
    local startline = rootfound:start()
    local endline = rootfound:named_child(rootfound:named_child_count() - 1):start()
    if endline >= startline then
      -- Get all lines between startline and endline in func_decl_lines, with line numbers
      local lines = vim.api.nvim_buf_get_lines(0, startline, endline, false)
      for i, line in ipairs(lines) do
        func_decl_lines = func_decl_lines .. (startline + i) .. ': ' .. line .. '\n'
      end
    end
  end
  return func_decl_lines
end

-- Function to get the text of a node
local function get_node_text(node, with_line_numbers)
  with_line_numbers = with_line_numbers or false
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  if with_line_numbers then
    for i, line in ipairs(lines) do
      line = string.format('%d: %s', start_row + i - 1, line) .. '\n'
    end
  end

  if #lines == 0 then
    return ''
  end
  lines[#lines] = string.sub(lines[#lines], 1, end_col)
  lines[1] = string.sub(lines[1], start_col + 1)
  return table.concat(lines, '\n')
end

-- Copied from codesnap
local function get_whole_lines(from, to)
  local lines = {}
  if from == to then
    table.insert(lines, vim.api.nvim_buf_get_lines(0, from - 1, from, false)[1])
  else
    for i = from, to do
      table.insert(lines, vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1])
    end
  end
  return table.concat(lines, '\n')
end

local function get_selected_text_realtime()
  local start_pos = vim.fn.getpos('v')
  local end_pos = vim.fn.getpos('.')

  -- We switch the start and end positions if the start is after the end line or character
  -- This way we can always select from the top down and from left to right
  if start_pos[2] > end_pos[2] or start_pos[3] > end_pos[3] then
    start_pos, end_pos = end_pos, start_pos
  end

  if vim.api.nvim_get_mode().mode == 'V' then
    return get_whole_lines(start_pos[2], end_pos[2])
  end

  if start_pos[2] == end_pos[2] then
    return vim.api
      .nvim_buf_get_lines(0, start_pos[2] - 1, start_pos[2], false)[1]
      :sub(start_pos[3], end_pos[3] - 1)
  end

  local selected_text = {}
  for i = start_pos[2], end_pos[2] do
    local line_text = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if i == start_pos[2] then
      line_text = line_text:sub(start_pos[3])
    end
    -- If select last line, there need to get column of current cursor
    if i == end_pos[2] then
      line_text = line_text:sub(1, end_pos[3] - 1)
    end
    table.insert(selected_text, line_text)
  end

  return selected_text
end

local function split_string(input_str, delimiter)
  local result = {}
  for match in (input_str .. delimiter):gmatch('(.-)' .. delimiter) do
    table.insert(result, match)
  end
  return result
end

function M.copy_to_clipboard(outcontent)
  if M.addhtml then
    vim.fn.system('xclip -selection clipboard -t text/html', outcontent)
  elseif os.getenv('SSH_CONNECTION') then
    vim.fn.setreg('*', outcontent)
    require('vim.ui.clipboard.osc52').copy('*')(split_string(outcontent, '\n'))
  else
    vim.fn.setreg('+', outcontent)
  end
  vim.notify('Copied : ' .. outcontent, vim.log.levels.WARN)
end

function M.append_git_link(outcontent, start_line, lines, callback)
  local ok, gitlinker = pcall(require, 'gitlinker')
  if ok then
    local hl_group = "NvimGitLinkerHighlightTextObject"
    local highlight = require("gitlinker.highlight")
    if not highlight.hl_group_exists(hl_group) then
      gitlinker.setup({})
    end
    gitlinker.link({
      router_type = 'current_branch',
      action = function(url)
        outcontent = outcontent .. url .. '\n'
        M.copy_to_clipboard(outcontent)
        if callback then callback(outcontent) end
      end,
      highlight_duration = 0,
      parameters = {
        lstart = start_line,
        lend = start_line + #lines - 1,
      },
    })
    return true
  end
  return false
end

-- Function to print information
function M.copy_with_context()
  local addmd = M.addmd
  M.addhtml = not addmd
  if vim.fn.executable('xclip') ~= 1 then
      M.addhtml = false
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':.')

  local lines = vim.fn.getline("'<", "'>")
  local start_line = vim.fn.getpos('v')[2]

  local llcc = '' -- linewise comment character
  local ftc = nil
  local ok = nil
  if vim.version().major >= 0 and vim.version().minor >= 11 then
    ftc = nil
    ok = nil
  else
    ok, ftc = pcall(require, 'Comment.ft') -- For older versions
  end
  local buffer_ft = vim.api.nvim_buf_get_option(0, 'filetype')
  if ok and ftc and buffer_ft then
    local cchar = ftc.get(buffer_ft)
    if cchar then
      llcc = string.gsub(cchar[1], '%%s', ' ')
    end
  else
    local commentstring = vim.bo.commentstring
    if commentstring == '' then
      commentstring = '// ' -- Default to a common comment format
    else
      commentstring = string.gsub(commentstring, '%%s', ' ')
    end
    llcc = commentstring
  end

  local linesep = llcc .. '---------------- \n'

  local outcontent = ''
  if addmd then
    outcontent = outcontent .. '```' .. buffer_ft .. '\n'
  end

  if file_name then
    if M.addhtml then
      outcontent = outcontent .. '<i>'
    end
    outcontent = outcontent .. llcc .. 'File: ' .. file_name
    if M.addhtml then
      outcontent = outcontent .. '</i>'
    else
      outcontent = outcontent .. '\n' .. linesep
    end
  end

  if M.addhtml then
    outcontent = outcontent .. '<pre><code class="language-' .. buffer_ft .. '">\n'
  end
  local func_decl_lines = get_function_decl_lines()
  func_decl_lines = func_decl_lines or ''
  if func_decl_lines ~= '' then
    outcontent = outcontent .. func_decl_lines
    outcontent = outcontent .. linesep
  end

  for i, line in ipairs(lines) do
    outcontent = outcontent .. string.format('%d: %s', start_line + i - 1, line) .. '\n'
  end

  if addmd then
    outcontent = outcontent .. '```' .. '\n'
  elseif M.addhtml then
    outcontent = outcontent .. '</code></pre>'
  else
    outcontent = outcontent .. linesep
  end

  -- Check if gitlinker is available and add a git link
  if not M.append_git_link(outcontent, start_line, lines) then
    M.copy_to_clipboard(outcontent)
  end
end

-- Create a command to call the function
-- vim.api.nvim_create_user_command("PrintFunctionInfo", function()
-- 	M.print_info()
-- end, { range = true })

function M.setup(opts)
  -- Merge tables
  if opts ~= nil then
    for k, v in pairs(opts) do
      M.opts[k] = v
    end
  end

  vim.api.nvim_create_user_command(
    'CopyContext',
    M.copy_with_context,
    { nargs = '*', range = '%' }
  )
  if M.opts.keymap then
    vim.keymap.set(
      { 'n', 'x' },
      M.opts.keymap,
      '<cmd>CopyContext<cr>',
      { silent = true, desc = 'Copy code with context' }
    )
  end
end

function M.deactivate()
  -- Clear autocommands, keymaps, etc.
  vim.keymap.unset({ 'n', 'x' }, M.opts.keymap)
  vim.api.nvim_del_user_command('CopyContext')
end

return M
