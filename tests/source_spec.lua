local source = require("herdr-review.source")

--- A real file inside this repo, so `git rev-parse` has something to answer.
local function open_repo_file()
  local buf = vim.fn.bufadd(vim.uv.cwd() .. "/lua/herdr-review/config.lua")
  vim.fn.bufload(buf)
  return buf
end

test("buf_path is repo-relative", function()
  eq(source.buf_path(open_repo_file()), "lua/herdr-review/config.lua")
end)

test("scratch buffers are rejected", function()
  local buf = vim.api.nvim_create_buf(false, true)
  local path, err = source.buf_path(buf)
  eq(path, nil)
  truthy(err)
end)

test("anchor_of_buf anchors to the new side with the raw line range", function()
  local a = source.anchor_of_buf(open_repo_file(), 5, 7)
  eq({ a.side, a.start_line, a.end_line, a.origin }, { "new", 5, 7, "file" })
end)

test("anchor context is padded and marks the selection", function()
  local a = source.anchor_of_buf(open_repo_file(), 5, 5)
  eq(#a.context, 1 + 2 * source.context_padding)
  local marked = vim.tbl_filter(function(l)
    return l:sub(1, 1) == ">"
  end, a.context)
  eq(#marked, 1)
  truthy(marked[1]:find("\t", 1, true), "context line should carry a line number")
end)

test("modified buffers are refused: their line numbers are not on disk", function()
  local buf = open_repo_file()
  vim.bo[buf].modified = true
  local a, err = source.anchor_of_buf(buf, 1, 1)
  vim.bo[buf].modified = false
  eq(a, nil)
  truthy(err:find("unsaved", 1, true), err)
end)
