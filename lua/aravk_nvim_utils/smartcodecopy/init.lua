local smartcodecopy = {}

smartcodecopy.opts = {
  -- The keymap to copy the code
  keymap = '<leader>sc',
  addFunction = true,
}

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
    local startline = rootfound:start()
    local endline = rootfound:named_child(rootfound:named_child_count() - 1):start()
    if endline >= startline then
      -- Get all lines between startline and endline in func_decl_lines, with line numbers
      local lines = vim.api.nvim_buf_get_lines(0, startline, endline, false)
      for i, line in ipairs(lines) do
        func_decl_lines = func_decl_lines .. (startline + i - 1) .. ': ' .. line .. '\n'
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
    for match in (input_str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

-- Function to print information
function smartcodecopy.copy_with_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':.')

  local lines = vim.fn.getline("'<", "'>")
  local start_line = vim.fn.getpos('v')[2]

  local linesep = '---------------- \n'
  local canhtml = false -- vim.fn.exepath("xclip")

  local outcontent = ''
  if file_name then
    outcontent = outcontent .. 'File: ' .. file_name .. '\n'
    outcontent = outcontent .. linesep
  end

  if canhtml then
    outcontent = outcontent .. '<pre>\n'
  end
  local func_decl_lines = get_function_decl_lines()
  func_decl_lines = func_decl_lines or ''
  if func_decl_lines ~= '' then
    outcontent = outcontent .. func_decl_lines
    outcontent = outcontent .. linesep
  end

  if canhtml then
    outcontent = outcontent .. '<hr>\n'
  end
  for i, line in ipairs(lines) do
    outcontent = outcontent .. string.format('%d: %s', start_line + i - 1, line) .. '\n'
  end

  if canhtml then
    outcontent = outcontent .. '</pre>\n'
  else
    outcontent = outcontent .. linesep
  end
  local tmpfile = os.tmpname()
  local handle = canhtml and io.open(tmpfile, 'w') or nil
  if handle then
    handle:write(outcontent)
    handle:close()
    local cmd = 'xclip -selection clipboard -l 10 -t text/html  ' .. tmpfile
    -- vim.print(cmd)
    os.execute(cmd)
    os.remove(tmpfile)
  else
    if os.getenv('SSH_CONNECTION') then
      vim.fn.setreg('*', outcontent)
      require('vim.ui.clipboard.osc52').copy('*')(split_string(outcontent, "\n"))
    else
      vim.fn.setreg('+', outcontent)
    end
  end
end

-- Create a command to call the function
-- vim.api.nvim_create_user_command("PrintFunctionInfo", function()
-- 	M.print_info()
-- end, { range = true })

function smartcodecopy.setup(opts)
  -- Merge tables
  for k, v in pairs(opts) do
    smartcodecopy.opts[k] = v
  end

  vim.api.nvim_create_user_command(
    'CopyContext',
    smartcodecopy.copy_with_context,
    { nargs = '*', range = '%' }
  )
  if smartcodecopy.opts.keymap then
    vim.keymap.set(
      { 'n', 'x' },
      smartcodecopy.opts.keymap,
      '<cmd>CopyContext<cr>',
      { silent = true, desc = 'Copy code with context' }
    )
  end
end

return smartcodecopy
