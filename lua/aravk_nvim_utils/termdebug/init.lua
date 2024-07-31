local termdebugutils = {}

function termdebugutils.setupdbg()
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

  vim.cmd('hi debugPC term=reverse ctermbg=darkgrey guibg=darkblue')
  vim.cmd('hi debugBreakpoint term=reverse ctermbg=blue guibg=red')

  vim.keymap.set('n', '<leader>gu', function()
    local lno = vim.fn.line('.')
    local dbgcmd = 'until ' .. lno
    vim.fn.TermDebugSendCommand(dbgcmd)
  end, { desc = 'Gdb run until' })
  vim.keymap.set('n', '<leader>jb', function()
    local lno = vim.fn.line('.')
    vim.fn.TermDebugSendCommand('tbreak ' .. lno)
    vim.fn.TermDebugSendCommand('jump ' .. lno)
  end, { desc = 'Gdb jump back' })
  vim.keymap.set('n', '<leader>gB', function()
    local breakCmd = 'break ' .. vim.api.nvim_buf_get_name(0) .. ':' .. vim.fn.getpos('.')[2]
    vim.fn.TermDebugSendCommand(breakCmd)
  end, { desc = 'Set gdb delayed breakpoint' })
  vim.keymap.set('n', '<leader>gc', function()
    vim.cmd('Continue')
  end, { desc = 'Continue' })
  vim.keymap.set('n', '<CR>', '<cmd>Over<CR>', { desc = 'Step over' })
  vim.keymap.set('n', '<leader>gk', function()
    vim.fn.TermDebugSendCommand('up')
  end, { desc = 'Up' })
  vim.keymap.set('n', '<leader>gj', function()
    vim.fn.TermDebugSendCommand('down')
  end, { desc = 'Down' })
  vim.keymap.set('n', '<leader>]', '<cmd>Step<CR>', { desc = 'Step into' })
  vim.keymap.set('n', '<leader>[', '<cmd>Finish<CR>', { desc = 'Step out of' })
  --"<cmd>call TermDebugSendCommand('p ' . expand("<cword>"))<CR>")
  vim.keymap.set('n', '<leader>k', function()
    local dbgcmd = 'p ' .. vim.fn.expand('<cexpr>')
    vim.fn.TermDebugSendCommand(dbgcmd)
  end, { desc = 'Gdb print under cursor' })
  vim.keymap.set({ 'n', 'v' }, '\\', function()
    vim.cmd('Evaluate')
  end, { desc = 'Evaluate' })
  vim.keymap.set('n', '<leader>ga', function()
    vim.fn.TermDebugSendCommand('pattach hwx')
  end, { desc = 'attach to recent hwx' })
  vim.keymap.set('n', '<leader>gb', '<cmd>Break<CR>', { desc = 'Add a breakpoint' })
  vim.keymap.set('n', '<leader>ge', function()
    vim.fn.TermDebugSendCommand('extractStarCommandsFromLastOutput')
  end, { desc = 'Run extractStarCommandsFromLastOutput' })
end

return termdebugutils
