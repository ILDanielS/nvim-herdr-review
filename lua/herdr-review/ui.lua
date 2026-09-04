--- Scratch-buffer rendering, buffer-line -> source-anchor mapping, and marks.
local config = require("herdr-review.config")
local diff = require("herdr-review.diff")
local M = {}

local NS = vim.api.nvim_create_namespace("herdr-review")

---@class HerdrReview.View
---@field buf integer
---@field win integer|nil
---@field files HerdrReview.File[]
---@field map table<integer, { path: string, side: HerdrReview.Side, lnum: integer }|nil> buffer lnum -> anchor
local view = nil

M.ns = NS

---@return HerdrReview.View|nil
function M.current()
  return view
end

---@param buf integer
---@return boolean
function M.is_review_buf(buf)
  return view ~= nil and view.buf == buf
end

---Turn parsed files into buffer lines plus the line->anchor map.
---@param files HerdrReview.File[]
---@return string[] lines, table map
function M.render_lines(files)
  local lines, map = {}, {}
  for _, file in ipairs(files) do
    table.insert(lines, ("── %s"):format(file.path))
    for _, hunk in ipairs(file.hunks) do
      table.insert(lines, hunk.header)
      for _, dl in ipairs(hunk.lines) do
        local sigil = dl.kind == "add" and "+" or dl.kind == "del" and "-" or " "
        table.insert(lines, sigil .. dl.text)
        local side, lnum = diff.anchor_of(dl)
        map[#lines] = { path = file.path, side = side, lnum = lnum }
      end
    end
    table.insert(lines, "")
  end
  return lines, map
end

---@param buf integer
local function apply_keymaps(buf)
  local keys = config.get().keymaps
  local function map(mode, lhs, rhs, desc)
    if lhs and lhs ~= false then
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
    end
  end
  -- `:` from visual mode inserts the '<,'> range, so the range command sees it.
  map("x", keys.comment, ":HerdrReviewComment<CR>", "Comment on selection")
  map("n", keys.comment, "<Cmd>HerdrReviewComment<CR>", "Comment on line")
  map("n", keys.submit, "<Cmd>HerdrReviewSubmit<CR>", "Send comments to Herdr")
  map("n", keys.refresh, "<Cmd>HerdrReviewRefresh<CR>", "Recompute the diff")
  map("n", keys.close, function()
    M.close()
  end, "Close the review")
end

---Open (or reuse) the review buffer for a parsed diff.
---@param files HerdrReview.File[]
---@return HerdrReview.View
function M.open(files)
  local lines, map = M.render_lines(files)
  if #lines == 0 then
    lines = { "-- no changes against the base branch --" }
  end

  local buf = (view and vim.api.nvim_buf_is_valid(view.buf)) and view.buf
    or vim.api.nvim_create_buf(false, true)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  -- "hide", not "wipe": a refresh or a detour into a file buffer must not
  -- destroy the buffer the stored anchors are painted onto.
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "diff"
  vim.api.nvim_buf_set_name(buf, "herdr-review://diff")

  local win = view and view.win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)
  vim.wo[win].number = false
  vim.wo[win].signcolumn = "yes"
  vim.wo[win].wrap = false

  apply_keymaps(buf)
  view = { buf = buf, win = win, files = files, map = map }
  return view
end

---Translate a visual selection into a source anchor range.
---@param buf integer
---@param first integer 1-indexed buffer line
---@param last integer
---@return { path: string, side: HerdrReview.Side, start_line: integer, end_line: integer, context: string[], origin: string }|nil, string|nil err
function M.selection_to_anchor(buf, first, last)
  if not view or view.buf ~= buf then
    return nil, "not the review buffer"
  end
  first, last = math.min(first, last), math.max(first, last)

  local path, side, lo, hi
  local context = {}
  for l = first, last do
    local a = view.map[l]
    if a then
      if not path then
        path, side = a.path, a.side
      elseif a.path ~= path then
        return nil, "selection spans more than one file"
      elseif a.side ~= side then
        return nil, "selection mixes added and removed lines; select one side"
      end
      lo = math.min(lo or a.lnum, a.lnum)
      hi = math.max(hi or a.lnum, a.lnum)
      table.insert(context, vim.api.nvim_buf_get_lines(buf, l - 1, l, false)[1])
    end
  end
  if not path then
    return nil, "selection covers no diff lines"
  end
  return {
    path = path,
    side = side,
    start_line = lo,
    end_line = hi,
    context = context,
    origin = "diff",
  }
end

---Prompt for comment text in a floating scratch window.
---@param on_done fun(body: string|nil)
---@param opts { initial: string|nil, title: string|nil }|nil
function M.input_comment(on_done, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  if opts.initial and opts.initial ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(opts.initial, "\n", { plain = true }))
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = math.min(72, math.max(40, vim.o.columns - 10)),
    height = 6,
    style = "minimal",
    border = "rounded",
    title = opts.title or " comment — <CR> accept, q cancel ",
  })

  local done = false
  local function finish(body)
    if done then
      return
    end
    done = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    on_done(body)
  end

  vim.keymap.set("n", "<CR>", function()
    finish(vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")))
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", function()
    finish(nil)
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    finish(nil)
  end, { buffer = buf, nowait = true })
  vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
    buffer = buf,
    callback = function()
      finish(vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")))
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      finish(nil)
    end,
  })

  vim.cmd.startinsert()
end

---@param body string
---@return string
local function label(body)
  local head = vim.split(body, "\n", { plain = true })[1] or ""
  return #head > 48 and (head:sub(1, 47) .. "…") or head
end

---@param buf integer
---@param row integer 0-indexed
---@param last_row integer 0-indexed
---@param text string|nil virt_text, only on the first row of a comment
local function paint(buf, row, last_row, text)
  vim.api.nvim_buf_set_extmark(buf, NS, row, 0, {
    end_row = last_row,
    sign_text = "▌",
    sign_hl_group = "DiagnosticSignInfo",
    line_hl_group = "CursorLine",
    virt_text = text and { { "  " .. text, "Comment" } } or nil,
    virt_text_pos = "eol",
  })
end

---Paint signs/extmarks for every stored comment in the review buffer.
---@param comments HerdrReview.Comment[]
function M.mark_comments(comments)
  if not view or not vim.api.nvim_buf_is_valid(view.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(view.buf, NS, 0, -1)

  -- One pass over the map, not one per comment.
  local rows = {}
  for blnum, a in pairs(view.map) do
    local k = ("%s:%s:%d"):format(a.path, a.side, a.lnum)
    rows[k] = math.min(rows[k] or blnum, blnum)
  end

  for _, c in ipairs(comments) do
    local first_row, last_row
    for lnum = c.start_line, c.end_line do
      local blnum = rows[("%s:%s:%d"):format(c.path, c.side, lnum)]
      if blnum then
        first_row = math.min(first_row or blnum, blnum)
        last_row = math.max(last_row or blnum, blnum)
      end
    end
    if first_row then
      paint(view.buf, first_row - 1, last_row - 1, label(c.body))
    end
  end
end

---Paint marks for comments anchored in an ordinary file buffer.
---@param buf integer
---@param comments HerdrReview.Comment[]
function M.mark_file_buf(buf, comments)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  local total = vim.api.nvim_buf_line_count(buf)
  for _, c in ipairs(comments) do
    if c.start_line <= total then
      paint(buf, c.start_line - 1, math.min(c.end_line, total) - 1, label(c.body))
    end
  end
end

---Drop every mark this plugin owns, in the review buffer and in any file
---buffer that has been painted. Marks live per-buffer, so clearing the store
---has to reach all of them, not just the one on screen.
function M.clear_marks()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    end
  end
end

local repaint_group = nil

---Repaint file-buffer marks on entry. Extmarks die with the buffer; the store
---is the source of truth, so re-derive them instead of trying to keep them.
function M.ensure_repaint()
  if repaint_group then
    return
  end
  repaint_group = vim.api.nvim_create_augroup("HerdrReviewMarks", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost" }, {
    group = repaint_group,
    callback = function(args)
      local store = require("herdr-review.store")
      if store.count() == 0 or M.is_review_buf(args.buf) then
        return
      end
      local source = require("herdr-review.source")
      local path = source.buf_path(args.buf)
      if not path then
        return
      end
      M.mark_file_buf(args.buf, store.get(path))
    end,
  })
end

function M.close()
  -- The review buffer took over a window the user already had, so wipe the
  -- buffer and let that window fall back to whatever it was showing before.
  -- Closing the window would take the user's own split with it.
  if view and vim.api.nvim_buf_is_valid(view.buf) then
    vim.api.nvim_buf_delete(view.buf, { force = true })
  end
  view = nil
end

return M
