--- Anchors produced from an ordinary file buffer, with no diff involved.
--- The review buffer needs `ui`'s line->anchor map to know what a selection
--- points at; a file buffer already *is* the new side, so the mapping is the
--- identity and only path normalisation and context capture are left to do.
local git = require("herdr-review.git")
local M = {}

M.context_padding = 3

---Repo-relative path for a buffer, so anchors key identically whether they
---were made here or in the review buffer.
---@param buf integer
---@return string|nil path, string|nil err
function M.buf_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then
    return nil, "not a file buffer"
  end
  local abs = vim.uv.fs_realpath(name) or name
  local root, err = git.repo_root(vim.fs.dirname(abs))
  if not root then
    return nil, err
  end
  local rel = vim.fs.relpath(vim.fs.normalize(root), vim.fs.normalize(abs))
  if not rel then
    return nil, "file is outside the repository: " .. abs
  end
  return rel
end

---Translate a selection in a file buffer into a source anchor.
---@param buf integer
---@param first integer 1-indexed buffer line
---@param last integer
---@return { path: string, side: HerdrReview.Side, start_line: integer, end_line: integer, context: string[], origin: string }|nil, string|nil err
function M.anchor_of_buf(buf, first, last)
  if vim.bo[buf].modified then
    -- Line numbers here would not match what the agent reads from disk.
    return nil, "buffer has unsaved changes; write it first"
  end
  local path, err = M.buf_path(buf)
  if not path then
    return nil, err
  end

  first, last = math.min(first, last), math.max(first, last)
  local total = vim.api.nvim_buf_line_count(buf)
  first, last = math.max(1, first), math.min(total, last)

  local from = math.max(1, first - M.context_padding)
  local to = math.min(total, last + M.context_padding)
  local context = {}
  for i, text in ipairs(vim.api.nvim_buf_get_lines(buf, from - 1, to, false)) do
    local lnum = from + i - 1
    -- Mark the selected region so the agent can see what the comment is on.
    table.insert(context, ("%s %d\t%s"):format((lnum >= first and lnum <= last) and ">" or " ", lnum, text))
  end

  return {
    path = path,
    side = "new",
    start_line = first,
    end_line = last,
    context = context,
    origin = "file",
  }
end

return M
