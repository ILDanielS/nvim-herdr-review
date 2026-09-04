local prompt = require("herdr-review.prompt")

test("single line renders bare line number", function()
  local s = prompt.render_comment({
    path = "lua/x.lua", side = "new", start_line = 4, end_line = 4, body = "fix",
  })
  truthy(s:find("lua/x.lua:4", 1, true), "missing path:line, got:\n" .. s)
end)

test("multi line renders a range", function()
  local s = prompt.render_comment({
    path = "x.lua", side = "old", start_line = 4, end_line = 7, body = "fix",
  })
  truthy(s:find("x.lua:4-7", 1, true), "missing range, got:\n" .. s)
  truthy(s:find("old side", 1, true))
end)

test("context is fenced as diff", function()
  local s = prompt.render_comment({
    path = "x.lua", side = "new", start_line = 1, end_line = 1, body = "b",
    context = { "+local a = 1" },
  })
  truthy(s:find("```diff", 1, true), "missing diff fence, got:\n" .. s)
end)

test("render includes base branch when given", function()
  local s = prompt.render({}, { base = "main" })
  truthy(s:find("base `main`", 1, true), s)
end)
