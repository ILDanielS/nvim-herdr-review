--- Unified-diff parser: text -> files -> hunks -> lines.
--- The line-level back-pointers produced here are the plugin's core data structure;
--- comments anchor to (path, side, lnum), never to buffer positions.
local M = {}

---@alias HerdrReview.Side "old"|"new"

---@class HerdrReview.DiffLine
---@field kind "context"|"add"|"del"
---@field text string      Content without the leading +/-/space.
---@field old_lnum integer|nil
---@field new_lnum integer|nil

---@class HerdrReview.Hunk
---@field header string    The raw @@ line.
---@field old_start integer
---@field old_count integer
---@field new_start integer
---@field new_count integer
---@field lines HerdrReview.DiffLine[]

---@class HerdrReview.File
---@field path string      New path (old path for pure deletions).
---@field old_path string|nil
---@field status "added"|"deleted"|"modified"|"renamed"
---@field hunks HerdrReview.Hunk[]

---@param text string raw `git diff` output
---@return HerdrReview.File[]
function M.parse(text)
  -- TODO: walk lines; `diff --git` starts a file, `@@` starts a hunk,
  -- track old/new line counters across +/-/space lines.
  return {}
end

---@param header string e.g. "@@ -12,7 +12,9 @@ fn foo()"
---@return integer old_start, integer old_count, integer new_start, integer new_count
function M.parse_hunk_header(header)
  -- TODO
  return 0, 0, 0, 0
end

---Pick the anchor a comment should use for a diff line: additions and context
---anchor to the new side, deletions to the old side.
---@param line HerdrReview.DiffLine
---@return HerdrReview.Side side, integer lnum
function M.anchor_of(line)
  if line.kind == "del" then
    return "old", line.old_lnum
  end
  return "new", line.new_lnum
end

return M
