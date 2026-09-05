local herdr = require("herdr-review.herdr")

local function list_json(agents)
  return vim.json.encode({ id = "cli:agent:list", result = { agents = agents, type = "agent_list" } })
end

test("parses agent list into pane-id targets", function()
  local got = herdr._parse_targets(list_json({
    {
      agent = "claude",
      agent_status = "idle",
      pane_id = "w4:p1",
      terminal_title_stripped = "first",
    },
  }))
  eq(#got, 1)
  eq(got[1].id, "w4:p1")
  eq(got[1].title, "claude  first  [idle]")
end)

test("prefers a live agent name over the kind", function()
  local got = herdr._parse_targets(list_json({
    { agent = "codex", name = "reviewer", agent_status = "working", pane_id = "w1:p2" },
  }))
  eq(got[1].title, "reviewer  [working]")
end)

test("sorts targets by pane id", function()
  local got = herdr._parse_targets(list_json({
    { agent = "claude", pane_id = "w2:p1" },
    { agent = "claude", pane_id = "w1:p3" },
  }))
  eq({ got[1].id, got[2].id }, { "w1:p3", "w2:p1" })
end)

test("no agents parses to an empty target list", function()
  eq(herdr._parse_targets(list_json({})), {})
end)

test("non-JSON output is an error, not a crash", function()
  local got, err = herdr._parse_targets("herdr: command not found")
  eq(got, nil)
  truthy(err)
end)

test("send refuses empty text without shelling out", function()
  local ok, err
  herdr.send("w1:p1", "", function(o, e)
    ok, err = o, e
  end)
  eq(ok, false)
  truthy(err)
end)

test("available reports why it is unavailable outside a Herdr pane", function()
  local saved = vim.env.HERDR_ENV
  vim.env.HERDR_ENV = nil
  local ok, err = herdr.available()
  vim.env.HERDR_ENV = saved
  eq(ok, false)
  truthy(err and err:find("HERDR_ENV"))
end)

test("a successful submit clears both the store and the marks", function()
  local store = require("herdr-review.store")
  local ui = require("herdr-review.ui")
  local api = require("herdr-review")

  local saved = package.loaded["herdr-review.herdr"]
  local sent
  package.loaded["herdr-review.herdr"] = {
    available = function()
      return true
    end,
    send = function(_, text, on_done)
      sent = text
      on_done(true)
    end,
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two" })
  store.clear()
  store.add({ path = "a.lua", side = "new", start_line = 1, end_line = 1, body = "fix" })
  ui.mark_file_buf(buf, store.ordered())
  truthy(#vim.api.nvim_buf_get_extmarks(buf, ui.ns, 0, -1, {}) > 0, "expected a mark to paint")

  api.submit("w1:p1")

  package.loaded["herdr-review.herdr"] = saved
  truthy(sent and sent:find("fix"), "expected the comment body in the prompt")
  eq(store.count(), 0)
  eq(vim.api.nvim_buf_get_extmarks(buf, ui.ns, 0, -1, {}), {})
  vim.api.nvim_buf_delete(buf, { force = true })
end)
