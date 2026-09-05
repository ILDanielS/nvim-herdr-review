--- The only module that shells out to `herdr`. Everything above it deals in
--- plain tables, so the review flow stays testable without a live session.
local config = require("herdr-review.config")
local M = {}

--- How long a single `herdr` invocation may take before we give up. Prompts are
--- sent without `--wait`, so the CLI returns as soon as the keys are written.
local TIMEOUT_MS = 15000

---Herdr only talks to the session that owns this process; controlling the
---focused session from outside it is not supported.
---@return boolean ok, string|nil err
function M.available()
  if vim.env.HERDR_ENV ~= "1" then
    return false, "not running inside a Herdr pane (HERDR_ENV is not 1)"
  end
  local cmd = config.get().herdr_cmd
  if vim.fn.executable(cmd) ~= 1 then
    return false, ("`%s` not found on PATH"):format(cmd)
  end
  return true
end

---Server errors arrive as JSON on stderr; syntax errors as plain text.
---@param res vim.SystemCompleted
---@return string
local function error_message(res)
  local ok, obj = pcall(vim.json.decode, res.stderr or "")
  if ok and type(obj) == "table" and type(obj.error) == "table" then
    local err = obj.error
    if err.code and err.message then
      return ("%s: %s"):format(err.code, err.message)
    end
    return err.message or err.code or "unknown herdr error"
  end
  local out = vim.trim((res.stderr ~= "" and res.stderr or res.stdout) or "")
  return out ~= "" and out or ("herdr exited with code " .. tostring(res.code))
end

---Run `herdr` with args, async.
---@param args string[]
---@param on_done fun(ok: boolean, out: string)
local function run(args, on_done)
  local cmd = vim.list_extend({ config.get().herdr_cmd }, args)
  vim.system(cmd, { text = true, timeout = TIMEOUT_MS }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        on_done(true, vim.trim(res.stdout or ""))
      else
        on_done(false, error_message(res))
      end
    end)
  end)
end

M._run = run

---@class HerdrReview.Pane
---@field id string pane id, the stable target for `herdr agent`
---@field title string|nil human label shown in the picker

---Turn `herdr agent list` output into picker entries.
---@param stdout string
---@return HerdrReview.Pane[]|nil, string|nil
local function parse_targets(stdout)
  local ok, obj = pcall(vim.json.decode, stdout)
  if not ok or type(obj) ~= "table" or type(obj.result) ~= "table" then
    return nil, "could not parse `herdr agent list` output"
  end
  local targets = {}
  for _, agent in ipairs(obj.result.agents or {}) do
    if agent.pane_id then
      -- Pane ids are unique and always present; a live agent name is not, and
      -- it moves with the pane occupant.
      local label = { agent.name or agent.agent }
      if agent.terminal_title_stripped and agent.terminal_title_stripped ~= "" then
        table.insert(label, agent.terminal_title_stripped)
      end
      if agent.agent_status then
        table.insert(label, "[" .. agent.agent_status .. "]")
      end
      table.insert(targets, {
        id = agent.pane_id,
        title = table.concat(label, "  "),
      })
    end
  end
  table.sort(targets, function(a, b)
    return a.id < b.id
  end)
  return targets
end

M._parse_targets = parse_targets

---List agents that can receive a prompt.
---@param on_done fun(panes: HerdrReview.Pane[]|nil, err: string|nil)
function M.list_targets(on_done)
  run({ "agent", "list" }, function(ok, out)
    if not ok then
      return on_done(nil, out)
    end
    local targets, err = parse_targets(out)
    if not targets then
      return on_done(nil, err)
    end
    if #targets == 0 then
      return on_done(nil, "no live Herdr agents to send to")
    end
    on_done(targets)
  end)
end

---Deliver prompt text to a live agent.
---@param target string pane id or unique agent name
---@param text string
---@param on_done fun(ok: boolean, err: string|nil)
function M.send(target, text, on_done)
  if text == "" then
    return on_done(false, "nothing to send")
  end
  -- No `--wait`: the review is fire-and-forget, and blocking the editor on the
  -- agent's turn would freeze the UI. A blocked agent still fails loudly here,
  -- because `agent prompt` refuses to type into an approval dialog.
  run({ "agent", "prompt", target, text }, function(ok, out)
    on_done(ok, ok and nil or out)
  end)
end

return M
