local diff = require("herdr-review.diff")

local sample = table.concat({
  "diff --git a/lua/a.lua b/lua/a.lua",
  "index 1111111..2222222 100644",
  "--- a/lua/a.lua",
  "+++ b/lua/a.lua",
  "@@ -1,3 +1,4 @@",
  " local a = 1",
  "-local b = 2",
  "+local b = 3",
  "+local c = 4",
  " local d = 5",
  "diff --git a/gone.txt b/gone.txt",
  "deleted file mode 100644",
  "--- a/gone.txt",
  "+++ /dev/null",
  "@@ -1 +0,0 @@",
  "-bye",
  "",
}, "\n")

test("parse_hunk_header with and without counts", function()
  eq({ diff.parse_hunk_header("@@ -12,7 +14,9 @@ fn foo()") }, { 12, 7, 14, 9 })
  eq({ diff.parse_hunk_header("@@ -1 +0,0 @@") }, { 1, 1, 0, 0 })
end)

test("parse splits files and keeps paths", function()
  local files = diff.parse(sample)
  eq(#files, 2)
  eq(files[1].path, "lua/a.lua")
  eq(files[1].status, "modified")
  eq(files[2].path, "gone.txt")
  eq(files[2].status, "deleted")
end)

test("parse tracks old/new line numbers across a hunk", function()
  local lines = diff.parse(sample)[1].hunks[1].lines
  eq(#lines, 5)
  eq({ lines[1].kind, lines[1].old_lnum, lines[1].new_lnum }, { "context", 1, 1 })
  eq({ lines[2].kind, lines[2].old_lnum }, { "del", 2 })
  eq({ lines[3].kind, lines[3].new_lnum }, { "add", 2 })
  eq({ lines[4].kind, lines[4].new_lnum }, { "add", 3 })
  eq({ lines[5].kind, lines[5].old_lnum, lines[5].new_lnum }, { "context", 3, 4 })
end)

test("deletion-only file anchors to the old side", function()
  local line = diff.parse(sample)[2].hunks[1].lines[1]
  eq({ diff.anchor_of(line) }, { "old", 1 })
end)

test("empty diff parses to no files", function()
  eq(diff.parse(""), {})
end)
