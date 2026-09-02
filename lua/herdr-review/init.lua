--- Public API. Commands and keymaps live in plugin/herdr-review.lua and only
--- call into here, so nothing internal is part of the user contract.
local config = require("herdr-review.config")
local M = {}

---@param opts HerdrReview.Config|nil
function M.setup(opts)
  config.setup(opts)
end

local function notify(msg, level)
  vim.notify("[herdr-review] " .. msg, level or vim.log.levels.INFO)
end

M._notify = notify

---Compute the diff against the merge-base and open the review buffer.
function M.open()
  local git = require("herdr-review.git")
  local diff = require("herdr-review.diff")
  local ui = require("herdr-review.ui")

  local res, err = git.working_tree_diff({ base_branch = config.get().base_branch })
  if not res then
    return notify(err or "could not compute diff", vim.log.levels.ERROR)
  end
  ui.open(diff.parse(res.diff))
end

---Re-run the diff, re-render, and reconcile stored comments.
function M.refresh()
  local git = require("herdr-review.git")
  local diff = require("herdr-review.diff")
  local store = require("herdr-review.store")
  local ui = require("herdr-review.ui")

  local res, err = git.working_tree_diff({ base_branch = config.get().base_branch })
  if not res then
    return notify(err or "could not compute diff", vim.log.levels.ERROR)
  end
  local files = diff.parse(res.diff)
  local dropped = store.reconcile(files)
  ui.open(files)
  ui.mark_comments(store.ordered())
  if #dropped > 0 then
    notify(("%d comment(s) dropped: anchors no longer in the diff"):format(#dropped), vim.log.levels.WARN)
  end
end

---Attach a comment to the current visual selection (or current line).
---@param first integer|nil 1-indexed buffer line
---@param last integer|nil
function M.comment(first, last)
  local store = require("herdr-review.store")
  local ui = require("herdr-review.ui")

  local view = ui.current()
  if not view then
    return notify("no review buffer open", vim.log.levels.ERROR)
  end
  first = first or vim.api.nvim_win_get_cursor(0)[1]
  last = last or first

  local anchor, err = ui.selection_to_anchor(view.buf, first, last)
  if not anchor then
    return notify(err or "selection covers no diff lines", vim.log.levels.ERROR)
  end
  ui.input_comment(function(body)
    if not body or body == "" then
      return
    end
    store.add(vim.tbl_extend("force", anchor, { body = body }))
    ui.mark_comments(store.ordered())
  end)
end

---Serialize every comment and deliver it to a live Herdr agent.
---@param target string|nil pane/agent id; nil = prompt for one
function M.submit(target)
  local store = require("herdr-review.store")
  local prompt = require("herdr-review.prompt")
  local herdr = require("herdr-review.herdr")

  local comments = store.ordered()
  if #comments == 0 then
    return notify("no comments to submit")
  end
  if not herdr.available() then
    return notify("`" .. config.get().herdr_cmd .. "` not found on PATH", vim.log.levels.ERROR)
  end

  local text = prompt.render(comments, nil)
  local function deliver(id)
    herdr.send(id, text, function(ok, err)
      if not ok then
        return notify(err or "send failed", vim.log.levels.ERROR)
      end
      notify(("sent %d comment(s) to %s"):format(#comments, id))
      store.clear()
    end)
  end

  if target then
    return deliver(target)
  end
  herdr.list_targets(function(panes, err)
    if not panes then
      return notify(err or "no Herdr targets found", vim.log.levels.ERROR)
    end
    vim.ui.select(panes, {
      prompt = "Send review to:",
      format_item = function(p)
        return p.title and (p.id .. "  " .. p.title) or p.id
      end,
    }, function(choice)
      if choice then
        deliver(choice.id)
      end
    end)
  end)
end

---Print the prompt that would be sent, without sending it.
function M.preview()
  local store = require("herdr-review.store")
  local prompt = require("herdr-review.prompt")
  local text = prompt.render(store.ordered(), nil)
  vim.api.nvim_echo({ { text } }, false, {})
end

function M.clear()
  require("herdr-review.store").clear()
  require("herdr-review.ui").mark_comments({})
  notify("comments cleared")
end

return M
