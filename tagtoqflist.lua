local ts = vim.fn.gettagstack(vim.fn.win_getid())
local items = {}
for i = #ts.items, 1, -1 do
  local tag = ts.items[i]
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
vim.fn.setqflist({}, ' ', {title = 'Tag Stack (from, reversed)', items = items})

local qflist = vim.fn.getqflist()
items = {}
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
local file = io.open("qflist_filenames.json", "w")
file:write(json)
file:close()
