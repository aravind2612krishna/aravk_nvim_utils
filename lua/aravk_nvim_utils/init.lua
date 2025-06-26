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

function aravk_nvim_utils.deactivate()
    -- aravk_nvim_utils
end

return aravk_nvim_utils
