local store = require("herdr-review.store")

local function c(path, line, body)
  return { path = path, side = "new", start_line = line, end_line = line, body = body }
end

test("add then count", function()
  store.clear()
  store.add(c("a.lua", 1, "one"))
  store.add(c("b.lua", 2, "two"))
  eq(store.count(), 2)
end)

test("same anchor replaces instead of duplicating", function()
  store.clear()
  store.add(c("a.lua", 1, "first"))
  store.add(c("a.lua", 1, "second"))
  eq(store.count(), 1)
  eq(store.ordered()[1].body, "second")
end)

test("ordered sorts by path then line", function()
  store.clear()
  store.add(c("b.lua", 1, "x"))
  store.add(c("a.lua", 9, "y"))
  store.add(c("a.lua", 2, "z"))
  local got = vim.tbl_map(function(x)
    return x.path .. ":" .. x.start_line
  end, store.ordered())
  eq(got, { "a.lua:2", "a.lua:9", "b.lua:1" })
end)

test("clear empties the store", function()
  store.clear()
  store.add(c("a.lua", 1, "x"))
  store.clear()
  eq(store.count(), 0)
end)
