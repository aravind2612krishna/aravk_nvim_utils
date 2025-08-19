local M = {}

M.source_window_id = nil

function M.run_until_line()
  local lno = vim.fn.line('.')
  local dbgcmd = 'until ' .. lno
  vim.fn.TermDebugSendCommand(dbgcmd)
end

function M.reverse_run_until()
  local lno = vim.fn.line('.')
  vim.fn.TermDebugSendCommand('tbreak ' .. lno)
  vim.fn.TermDebugSendCommand('reverse-continue')
end

function M.jump_back()
  local lno = vim.fn.line('.')
  vim.fn.TermDebugSendCommand('tbreak ' .. lno)
  vim.fn.TermDebugSendCommand('jump ' .. lno)
end

function M.set_delayed_breakpoint()
  local breakCmd = 'break ' .. vim.api.nvim_buf_get_name(0) .. ':' .. vim.fn.getpos('.')[2]
  vim.fn.TermDebugSendCommand(breakCmd)
end

function M.continue()
  vim.cmd('Continue')
end

function M.reverse_continue()
  vim.fn.TermDebugSendCommand('reverse-continue')
end

function M.reverse_next()
  vim.fn.TermDebugSendCommand('reverse-next')
end

function M.up_stack()
  vim.fn.TermDebugSendCommand('up')
end

function M.down_stack()
  vim.fn.TermDebugSendCommand('down')
end

function M.print_under_cursor()
  local dbgcmd = 'p ' .. vim.fn.expand('<cexpr>')
  vim.fn.TermDebugSendCommand(dbgcmd)
end

function M.evaluate()
  vim.cmd('Evaluate')
end

function M.attach_hwx()
  vim.fn.TermDebugSendCommand('pattach hwx')
end

function M.extract_star_commands()
  vim.fn.TermDebugSendCommand('extractStarCommandsFromLastOutput')
end

M.termdebug_keymaps = {
  { mode = 'n', lhs = '<leader>gu', rhs = M.run_until_line, opts = { desc = 'Gdb run until' } },
  {
    mode = 'n',
    lhs = '<leader>gru',
    rhs = M.reverse_run_until,
    opts = { desc = 'Gdb reverse run until' },
  },
  { mode = 'n', lhs = '<leader>jb', rhs = M.jump_back, opts = { desc = 'Gdb jump back' } },
  {
    mode = 'n',
    lhs = '<leader>gB',
    rhs = M.set_delayed_breakpoint,
    opts = { desc = 'Set gdb delayed breakpoint' },
  },
  {
    mode = 'n',
    lhs = '<leader>gc',
    rhs = M.continue,
    opts = { desc = 'Continue' },
  },
  {
    mode = 'n',
    lhs = '<leader>grc',
    rhs = M.reverse_continue,
    opts = { desc = 'Reverse Continue' },
  },
  { mode = 'n', lhs = '<M-j>', rhs = '<cmd>Over<CR>', opts = { desc = 'Step over (next)' } },
  { mode = 'n', lhs = '<CR>', rhs = '<cmd>Over<CR>', opts = { desc = 'Step over (next)' } },
  {
    mode = 'n',
    lhs = '<M-k>',
    rhs = M.reverse_next,
    opts = { desc = 'Reverse Step over (reverse-next)' },
  },
  { mode = 'n', lhs = '<leader>gk', rhs = M.up_stack, opts = { desc = 'Gdb up stack frame' } },
  {
    mode = 'n',
    lhs = '<leader>gj',
    rhs = M.down_stack,
    opts = { desc = 'Gdb down stack frame' },
  },
  { mode = 'n', lhs = '<M-l>', rhs = '<cmd>Step<CR>', opts = { desc = 'Step into' } },
  { mode = 'n', lhs = '<M-h>', rhs = '<cmd>Finish<CR>', opts = { desc = 'Step out of' } },
  { mode = 'n', lhs = '<leader>]', rhs = '<cmd>Step<CR>', opts = { desc = 'Step into' } },
  { mode = 'n', lhs = '<leader>[', rhs = '<cmd>Finish<CR>', opts = { desc = 'Step out of' } },
  {
    mode = { 'n', 'v' },
    lhs = '<leader>k',
    rhs = M.print_under_cursor,
    opts = { desc = 'Gdb print under cursor (expression)' },
  },
  { mode = { 'n', 'v' }, lhs = '\\', rhs = M.evaluate, opts = { desc = 'Evaluate expression' } },
  {
    mode = 'n',
    lhs = '<leader>ga',
    rhs = M.attach_hwx,
    opts = { desc = 'Attach to recent hwx process' },
  },
  {
    mode = 'n',
    lhs = '<leader>gb',
    rhs = '<cmd>Break<CR>',
    opts = { desc = 'Add a breakpoint (current line)' },
  },
  {
    mode = 'n',
    lhs = '<leader>ge',
    rhs = M.extract_star_commands,
    opts = { desc = 'Extract star commands from last output' },
  },
}

function M.mapkeys()
  for _, map in ipairs(M.termdebug_keymaps) do
    vim.keymap.set(map.mode, map.lhs, map.rhs, vim.tbl_extend('force', map.opts or {}, {}))
  end
end

function M.unmapkeys()
  for _, map in ipairs(M.termdebug_keymaps) do
    vim.keymap.del(map.mode, map.lhs)
  end
end

function M.setupdbg()
  vim.cmd.packadd('termdebug')
  vim.g.termdebug_wide = 1
  vim.cmd('Termdebug')
  vim.cmd('wincmd k')
  vim.api.nvim_win_close(0, false)
  vim.cmd('wincmd H')
  vim.cmd('wincmd l')

  if not vim.g['termdebug_config'] then
    vim.g.termdebug_config = {}
  end
  vim.g.termdebug_config['map_K'] = 0
  vim.g.termdebug_config['sign_decimal'] = 1

  vim.cmd('hi debugPC term=reverse ctermbg=darkgrey guibg=darkblue')
  vim.cmd('hi debugBreakpoint term=reverse ctermbg=blue guibg=red')

  for _, map in ipairs(M.termdebug_keymaps) do
    vim.keymap.set(map.mode, map.lhs, map.rhs, map.opts)
  end

  -- Execute the Source command and take note of the source window id
  vim.cmd('Source')
  M.source_window_id = vim.api.nvim_get_current_win()

  -- Add an autocommand to map keys when the source window is switched to
  local group = vim.api.nvim_create_augroup('TermdebugKeymaps', { clear = true })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = group,
    callback = function()
      if vim.api.nvim_get_current_win() == M.source_window_id then
        M.mapkeys()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinLeave', {
    group = group,
    callback = function()
      if vim.api.nvim_get_current_win() == M.source_window_id then
        M.unmapkeys()
      end
    end,
  })
end

return M
