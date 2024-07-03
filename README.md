# aravk_nvim_utils

Currently contains my utility functions for Termdebug and Code copying

## Setup using lazy.nvim

```lua
return {
  "aravind2612krishna/aravk_nvim_utils",
  keys = {
    {
      "<leader>td",
      function()
        local termdebug = require "aravk_nvim_utils.termdebug"
        if termdebug then termdebug.setupdbg() end
      end,
      mode = "n",
      desc = "Setup termdebug and start it",
    },
    {
      "<leader>sc",
      function()
        local smartcopy = require "aravk_nvim_utils.smartcodecopy"
        if smartcopy then smartcopy.copy_with_context() end
      end,
      mode = { "n", "v" },
      desc = "Copy code with context information",
    },
  },
}
```

## License MIT
