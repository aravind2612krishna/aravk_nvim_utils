-- aravk_nvim_utils/gdb_viewer/init.lua
-- Opens a scratch buffer with processed GDB output:
--   - Noise lines (threads, BFD warnings, dnf suggestions) collapsed into
--     single placeholder lines with virtual-text annotation
--   - Redundant lines removed (hwString members, HW_HASH_SHIFT)
--   - Template types simplified (std::__cxx11::basic_string<...> => std::string, etc.)
--   - Base-class GDB wrappers stripped (<std::string> = "val" => "val")

local M = {}

-- ---------------------------------------------------------------------------
-- Type substitutions
-- ---------------------------------------------------------------------------
local SUBSTITUTIONS = {
  {
    pat = "std::__cxx11::basic_string%s*<%s*char%s*,%s*std::char_traits%s*<%s*char%s*>%s*,%s*std::allocator%s*<%s*char%s*>%s*>",
    rep = "std::string",
  },
  {
    pat = "std::vector%s*<(.-)%s*,%s*std::allocator%s*<.->%s*>",
    rep = "std::vector<%1>",
  },
  {
    pat = "std::map%s*<(.-)%s*,%s*std::less%s*<.->%s*,%s*std::allocator%s*<.->%s*>",
    rep = "std::map<%1>",
  },
  { pat = "hwString", rep = "str" },
}

-- Lines matching these patterns are dropped entirely
local REMOVE_LINE_PATTERNS = {
  "^%s*members of hwString:%s*$",
  "^%s*static HW_HASH_SHIFT%s*=%s*%d+%s*$",
}

-- Lines matching these patterns are grouped into fold placeholders
local FOLD_LINE_PATTERNS = {
  "%[New Thread",
  "%[Thread .* exited%]",
  "%[New LWP",
  "warning: BFD:",
  "^Missing rpms, try:",
  "^%s*dnf ",
  "%[Detaching after vfork",
}

-- Strip GDB base-class wrapper: leading spaces + <TypeName> = value  =>  leading spaces + value
local function strip_base_wrapper(line)
  local indent, value = line:match("^(%s*)<[^>]+>%s*=%s*(.+)$")
  if indent and value then
    return indent .. value
  end
  return line
end

-- ---------------------------------------------------------------------------
-- Core processing
-- ---------------------------------------------------------------------------
local function process_lines(raw_lines)
  local out = {}
  local folds = {}   -- list of { line_idx (1-based in out), count }
  local fold_count = 0

  local function flush_fold()
    if fold_count > 0 then
      table.insert(out, string.format(
        "  ~~~ %d lines hidden [threads / BFD warnings / noise] ~~~",
        fold_count
      ))
      table.insert(folds, { idx = #out, count = fold_count })
      fold_count = 0
    end
  end

  for _, raw in ipairs(raw_lines) do
    local is_noise = false
    for _, pat in ipairs(FOLD_LINE_PATTERNS) do
      if raw:find(pat) then
        is_noise = true
        break
      end
    end

    if is_noise then
      fold_count = fold_count + 1
    else
      flush_fold()

      local remove = false
      for _, pat in ipairs(REMOVE_LINE_PATTERNS) do
        if raw:match(pat) then
          remove = true
          break
        end
      end

      if not remove then
        local line = raw
        for _, sub in ipairs(SUBSTITUTIONS) do
          line = line:gsub(sub.pat, sub.rep)
        end
        line = strip_base_wrapper(line)
        table.insert(out, line)
      end
    end
  end

  flush_fold()
  return out, folds
end

-- ---------------------------------------------------------------------------
-- Buffer / window helpers
-- ---------------------------------------------------------------------------
local function find_gdb_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:find("term://") and name:find("gdb") then
        return buf
      end
    end
  end
  return nil
end

local viewer_buf = nil
local viewer_ns  = nil

local function get_viewer_buf()
  if viewer_buf and vim.api.nvim_buf_is_valid(viewer_buf) then
    return viewer_buf
  end
  viewer_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(viewer_buf, "GDB Viewer")
  vim.bo[viewer_buf].buftype    = "nofile"
  vim.bo[viewer_buf].bufhidden  = "wipe"
  vim.bo[viewer_buf].filetype   = "gdbviewer"
  vim.bo[viewer_buf].modifiable = false
  return viewer_buf
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------
function M.refresh()
  local gdb_buf = find_gdb_buf()
  if not gdb_buf then
    vim.notify("GDB Viewer: no GDB terminal buffer found", vim.log.levels.WARN)
    return
  end

  local raw_lines = vim.api.nvim_buf_get_lines(gdb_buf, 0, -1, false)
  local processed, folds = process_lines(raw_lines)

  local buf = get_viewer_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, processed)
  vim.bo[buf].modifiable = false

  -- Virtual text on fold placeholder lines
  if not viewer_ns then
    viewer_ns = vim.api.nvim_create_namespace("gdb_viewer")
  end
  vim.api.nvim_buf_clear_namespace(buf, viewer_ns, 0, -1)

  for _, fold in ipairs(folds) do
    local lnum = fold.idx - 1  -- 0-based
    vim.api.nvim_buf_set_extmark(buf, viewer_ns, lnum, 0, {
      virt_text     = { { string.format(" (%d lines)", fold.count), "Comment" } },
      virt_text_pos = "eol",
      hl_mode       = "combine",
    })
    vim.api.nvim_buf_add_highlight(buf, viewer_ns, "Comment", lnum, 0, -1)
  end

  vim.notify(string.format("GDB Viewer: %d lines (%d noise groups collapsed)",
    #processed, #folds), vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------
function M.open()
  local buf = get_viewer_buf()

  -- Reuse existing window
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      M.refresh()
      return
    end
  end

  vim.cmd("botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].wrap   = false
  vim.wo[win].number = true

  vim.keymap.set("n", "r", M.refresh,
    { buffer = buf, desc = "GDB Viewer: refresh" })
  vim.keymap.set("n", "q", function() vim.cmd("close") end,
    { buffer = buf, desc = "GDB Viewer: close" })

  M.refresh()
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------
function M.setup(opts)
  opts = opts or {}

  vim.api.nvim_create_user_command("GdbView",
    function() M.open() end, { desc = "Open GDB Viewer" })
  vim.api.nvim_create_user_command("GdbViewRefresh",
    function() M.refresh() end, { desc = "Refresh GDB Viewer" })

  local key = opts.keymap or "<leader>gv"
  vim.keymap.set("n", key, M.open, { desc = "Open GDB Viewer" })
end

return M
