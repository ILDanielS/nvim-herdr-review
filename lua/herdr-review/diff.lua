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

---Strip git's `a/` / `b/` prefix from a `---`/`+++` path.
---@param p string
---@return string
local function strip_prefix(p)
  return (p:gsub("^[ab]/", ""))
end

---@param text string raw `git diff` output
---@return HerdrReview.File[]
function M.parse(text)
  local files = {}
  local file, hunk = nil, nil
  local old_lnum, new_lnum = 0, 0
  local rem_old, rem_new = 0, 0

  for _, l in ipairs(vim.split(text or "", "\n", { plain = true })) do
    if l:sub(1, 10) == "diff --git" then
      -- Provisional paths; the ---/+++ lines below override them and handle
      -- filenames the greedy match here would split wrongly.
      local a, b = l:match("^diff %-%-git a/(.+) b/(.+)$")
      file = { path = b or a, old_path = a, status = "modified", hunks = {} }
      table.insert(files, file)
      hunk = nil
    elseif file and l:sub(1, 13) == "new file mode" then
      file.status = "added"
    elseif file and l:sub(1, 17) == "deleted file mode" then
      file.status = "deleted"
    elseif file and l:sub(1, 12) == "rename from " then
      file.old_path, file.status = l:sub(13), "renamed"
    elseif file and l:sub(1, 10) == "rename to " then
      file.path, file.status = l:sub(11), "renamed"
    elseif file and l:sub(1, 4) == "--- " then
      local p = l:sub(5)
      if p ~= "/dev/null" then
        file.old_path = strip_prefix(p)
      end
    elseif file and l:sub(1, 4) == "+++ " then
      local p = l:sub(5)
      if p ~= "/dev/null" then
        file.path = strip_prefix(p)
      elseif file.old_path then
        -- Pure deletion: the file only exists on the old side.
        file.path = file.old_path
      end
    elseif file and l:sub(1, 2) == "@@" then
      local os_, oc, ns_, nc = M.parse_hunk_header(l)
      hunk = {
        header = l,
        old_start = os_,
        old_count = oc,
        new_start = ns_,
        new_count = nc,
        lines = {},
      }
      table.insert(file.hunks, hunk)
      old_lnum, new_lnum = os_, ns_
      rem_old, rem_new = oc, nc
    elseif hunk then
      local c = l:sub(1, 1)
      if c == "\\" then -- "\ No newline at end of file"
        goto continue
      elseif c == "+" then
        table.insert(hunk.lines, { kind = "add", text = l:sub(2), new_lnum = new_lnum })
        new_lnum, rem_new = new_lnum + 1, rem_new - 1
      elseif c == "-" then
        table.insert(hunk.lines, { kind = "del", text = l:sub(2), old_lnum = old_lnum })
        old_lnum, rem_old = old_lnum + 1, rem_old - 1
      elseif c == " " or l == "" then
        -- Some producers emit a bare empty line for an empty context line.
        table.insert(hunk.lines, {
          kind = "context",
          text = l:sub(2),
          old_lnum = old_lnum,
          new_lnum = new_lnum,
        })
        old_lnum, new_lnum = old_lnum + 1, new_lnum + 1
        rem_old, rem_new = rem_old - 1, rem_new - 1
      else
        hunk = nil
      end
      if hunk and rem_old <= 0 and rem_new <= 0 then
        hunk = nil
      end
    end
    ::continue::
  end

  return files
end

---@param header string e.g. "@@ -12,7 +12,9 @@ fn foo()"
---@return integer old_start, integer old_count, integer new_start, integer new_count
function M.parse_hunk_header(header)
  local os_, oc, ns_, nc = header:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
  if not os_ then
    return 0, 0, 0, 0
  end
  -- A missing count means exactly one line.
  return tonumber(os_), tonumber(oc) or 1, tonumber(ns_), tonumber(nc) or 1
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
