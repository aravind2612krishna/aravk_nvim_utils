-- Lazy load everything into utils.
local aravk_nvim_utils = setmetatable({}, {
  __index = function(t, k)
    local ok, val = pcall(require, string.format('aravk_nvim_utils.%s', k))

    if ok then
      rawset(t, k, val)
    end

    return val
  end,
})

return aravk_nvim_utils
