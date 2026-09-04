--- Session-scoped comment store, keyed by source position.
--- Survives re-renders and diff refreshes: reconciliation happens by
--- (path, side, start_line, end_line), never by buffer line.
local M = {}

---@alias HerdrReview.Origin "diff"|"file"

---@class HerdrReview.Comment
---@field path string
---@field side HerdrReview.Side
---@field start_line integer
---@field end_line integer
---@field body string
---@field origin HerdrReview.Origin Where the anchor came from; "file" anchors survive refresh.
---@field context string[]|nil Diff lines captured at creation, for the prompt.
---@field created_at integer

---@type HerdrReview.Comment[]
local comments = {}

---@param c HerdrReview.Comment
---@return string
local function key(c)
  return table.concat({ c.path, c.side, c.start_line, c.end_line }, ":")
end

M._key = key

---Add or replace the comment at a position.
---@param c HerdrReview.Comment
function M.add(c)
  c.created_at = c.created_at or os.time()
  c.origin = c.origin or "diff"
  for i, existing in ipairs(comments) do
    if key(existing) == key(c) then
      comments[i] = c
      return c
    end
  end
  table.insert(comments, c)
  return c
end

---@param path string
---@param side HerdrReview.Side
---@param start_line integer
---@param end_line integer
---@return boolean removed
function M.remove(path, side, start_line, end_line)
  local k = key({ path = path, side = side, start_line = start_line, end_line = end_line })
  for i, existing in ipairs(comments) do
    if key(existing) == k then
      table.remove(comments, i)
      return true
    end
  end
  return false
end

---@param path string|nil filter
---@return HerdrReview.Comment[]
function M.get(path)
  if not path then
    return comments
  end
  return vim.tbl_filter(function(c)
    return c.path == path
  end, comments)
end

---Deterministic order for serialization: by path, then start_line, then side.
---@return HerdrReview.Comment[]
function M.ordered()
  local out = vim.deepcopy(comments)
  table.sort(out, function(a, b)
    if a.path ~= b.path then
      return a.path < b.path
    end
    if a.start_line ~= b.start_line then
      return a.start_line < b.start_line
    end
    return a.side < b.side
  end)
  return out
end

function M.count()
  return #comments
end

function M.clear()
  comments = {}
end

---Re-anchor comments after a diff refresh. Comments whose anchor no longer
---exists are dropped and returned so the caller can tell the user.
---
---Only `origin == "diff"` comments are validated. A comment made in a file
---buffer may sit on a line the diff never touched; that is not a stale anchor,
---so dropping it would lose valid feedback.
---@param files HerdrReview.File[]
---@return HerdrReview.Comment[] dropped
function M.reconcile(files)
  local diff = require("herdr-review.diff")
  local valid = {}
  for _, file in ipairs(files) do
    for _, hunk in ipairs(file.hunks) do
      for _, dl in ipairs(hunk.lines) do
        local side, lnum = diff.anchor_of(dl)
        if lnum then
          valid[("%s:%s:%d"):format(file.path, side, lnum)] = true
        end
      end
    end
  end

  local kept, dropped = {}, {}
  for _, c in ipairs(comments) do
    local ok = true
    if c.origin == "diff" then
      for lnum = c.start_line, c.end_line do
        if not valid[("%s:%s:%d"):format(c.path, c.side, lnum)] then
          ok = false
          break
        end
      end
    end
    table.insert(ok and kept or dropped, c)
  end
  comments = kept
  return dropped
end

return M
