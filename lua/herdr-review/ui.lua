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

---Open (or reuse) the review buffer for a parsed diff.
---@param files HerdrReview.File[]
---@return HerdrReview.View
function M.open(files)
  -- TODO: create scratch buf (buftype=nofile, bufhidden=wipe, filetype=diff),
  -- set lines, apply keymaps from config, open in a window.
  error("not implemented")
end

---Translate a visual selection into a source anchor range.
---@param buf integer
---@param first integer 1-indexed buffer line
---@param last integer
---@return { path: string, side: HerdrReview.Side, start_line: integer, end_line: integer }|nil, string|nil err
function M.selection_to_anchor(buf, first, last)
  -- TODO: look up view.map for each line, require a single (path, side),
  -- take min/max lnum. Error if the selection covers no diff lines.
  return nil, "not implemented"
end

---Prompt for comment text (multi-line scratch window), then hand it back.
---@param on_done fun(body: string|nil)
function M.input_comment(on_done)
  -- TODO: floating scratch buffer; <CR> in normal mode or :w accepts.
  on_done(nil)
end

---Paint signs/extmarks for every stored comment.
---@param comments HerdrReview.Comment[]
function M.mark_comments(comments)
  if not view then
    return
  end
  vim.api.nvim_buf_clear_namespace(view.buf, NS, 0, -1)
  -- TODO: reverse-map anchors to buffer lines, set extmarks + virt_text.
end

function M.close()
  view = nil
end

return M
