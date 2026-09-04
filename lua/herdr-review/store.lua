--- Session-scoped comment store, keyed by source position.
--- Survives re-renders and diff refreshes: reconciliation happens by
--- (path, side, start_line, end_line), never by buffer line.
local M = {}

---@class HerdrReview.Comment
---@field path string
---@field side HerdrReview.Side
---@field start_line integer
---@field end_line integer
---@field body string
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
function M.remove(path, side, start_line, end_line) end

---@param path string|nil filter
---@return HerdrReview.Comment[]
function M.get(path)
  return comments
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
---@param files HerdrReview.File[]
---@return HerdrReview.Comment[] dropped
function M.reconcile(files)
  -- TODO: build a set of valid (path, side, lnum) from `files`, keep comments
  -- whose whole range still resolves, drop the rest.
  return {}
end

return M
