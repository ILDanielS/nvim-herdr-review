local ui = require("herdr-review.ui")

local files = {
  {
    path = "a.lua",
    status = "modified",
    hunks = {
      {
        header = "@@ -1,2 +1,3 @@",
        old_start = 1, old_count = 2, new_start = 1, new_count = 3,
        lines = {
          { kind = "context", text = "local a", old_lnum = 1, new_lnum = 1 },
          { kind = "del", text = "local b", old_lnum = 2, new_lnum = nil },
          { kind = "add", text = "local c", old_lnum = nil, new_lnum = 2 },
        },
      },
    },
  },
}

test("render_lines emits header, hunk, sigils", function()
  local lines = ui.render_lines(files)
  eq(lines[1], "── a.lua")
  eq(lines[2], "@@ -1,2 +1,3 @@")
  eq(lines[3], " local a")
  eq(lines[4], "-local b")
  eq(lines[5], "+local c")
end)

test("map anchors deletions to old side, additions to new", function()
  local _, map = ui.render_lines(files)
  eq(map[3], { path = "a.lua", side = "new", lnum = 1 })
  eq(map[4], { path = "a.lua", side = "old", lnum = 2 })
  eq(map[5], { path = "a.lua", side = "new", lnum = 2 })
end)

test("file header lines have no anchor", function()
  local _, map = ui.render_lines(files)
  eq(map[1], nil)
  eq(map[2], nil)
end)

test("selection_to_anchor collapses a range to one source anchor", function()
  local v = ui.open(files)
  local a = ui.selection_to_anchor(v.buf, 3, 3)
  eq({ a.path, a.side, a.start_line, a.end_line, a.origin }, { "a.lua", "new", 1, 1, "diff" })
  ui.close()
end)

test("selection_to_anchor refuses a mixed add/del selection", function()
  local v = ui.open(files)
  local a, err = ui.selection_to_anchor(v.buf, 3, 5)
  eq(a, nil)
  truthy(err:find("side", 1, true), err)
  ui.close()
end)

test("selection_to_anchor rejects header-only selections", function()
  local v = ui.open(files)
  local a, err = ui.selection_to_anchor(v.buf, 1, 2)
  eq(a, nil)
  truthy(err:find("no diff lines", 1, true), err)
  ui.close()
end)

test("mark_comments paints one extmark per resolved comment", function()
  local v = ui.open(files)
  ui.mark_comments({
    { path = "a.lua", side = "new", start_line = 1, end_line = 1, body = "hi" },
    { path = "a.lua", side = "old", start_line = 99, end_line = 99, body = "gone" },
  })
  local marks = vim.api.nvim_buf_get_extmarks(v.buf, ui.ns, 0, -1, {})
  eq(#marks, 1)
  eq(marks[1][2], 2, "should land on buffer line 3 (0-indexed 2)")
  ui.close()
end)

test("clear_marks reaches file buffers, not just the review buffer", function()
  local v = ui.open(files)
  ui.mark_comments({ { path = "a.lua", side = "new", start_line = 1, end_line = 1, body = "hi" } })
  local other = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(other, 0, -1, false, { "x", "y" })
  ui.mark_file_buf(other, { { start_line = 1, end_line = 1, body = "hi" } })

  ui.clear_marks()
  eq(#vim.api.nvim_buf_get_extmarks(v.buf, ui.ns, 0, -1, {}), 0)
  eq(#vim.api.nvim_buf_get_extmarks(other, ui.ns, 0, -1, {}), 0)
  ui.close()
end)
