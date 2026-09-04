--- The only module that shells out to `herdr`. Everything above it deals in
--- plain tables, so the review flow stays testable without a live session.
local config = require("herdr-review.config")
local M = {}

---@return boolean
function M.available()
  return vim.fn.executable(config.get().herdr_cmd) == 1
end

---Run `herdr` with args, async.
---@param args string[]
---@param on_done fun(ok: boolean, out: string)
local function run(args, on_done)
  vim.system({ config.get().herdr_cmd, unpack(args) }, { text = true }, function(res)
    vim.schedule(function()
      on_done(res.code == 0, vim.trim((res.code == 0 and res.stdout or res.stderr) or ""))
    end)
  end)
end

M._run = run

---@class HerdrReview.Pane
---@field id string
---@field title string|nil

---List panes/agents that can receive a prompt.
---@param on_done fun(panes: HerdrReview.Pane[]|nil, err: string|nil)
function M.list_targets(on_done)
  -- TODO: herdr <list command> --json, decode with vim.json.decode
  on_done(nil, "not implemented")
end

---Deliver prompt text to a live agent.
---@param target string pane/agent id
---@param text string
---@param on_done fun(ok: boolean, err: string|nil)
function M.send(target, text, on_done)
  -- TODO: herdr <send command> <target> <text>
  on_done(false, "not implemented")
end

return M
