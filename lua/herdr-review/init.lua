--- Public API. Commands and keymaps live in plugin/herdr-review.lua and only
--- call into here, so nothing internal is part of the user contract.
local config = require("herdr-review.config")
local M = {}

---@param opts HerdrReview.Config|nil
function M.setup(opts)
  local o = config.setup(opts)
  local lhs = o.keymaps.comment_global
  if lhs and lhs ~= false then
    -- Opt-in: commenting from any file buffer needs a global map, and the
    -- review buffer's `c` would shadow `change` everywhere else.
    vim.keymap.set({ "n", "x" }, lhs, ":HerdrReviewComment<CR>", {
      silent = true,
      desc = "Comment on selection (herdr-review)",
    })
  end
  require("herdr-review.ui").ensure_repaint()
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
  M._meta = { base = res.base, sha = res.sha, root = res.root }
  ui.open(diff.parse(res.diff))
  ui.ensure_repaint()
  ui.mark_comments(require("herdr-review.store").ordered())
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
  M._meta = { base = res.base, sha = res.sha, root = res.root }
  local files = diff.parse(res.diff)
  local dropped = store.reconcile(files)
  ui.open(files)
  ui.mark_comments(store.ordered())
  if #dropped > 0 then
    notify(("%d comment(s) dropped: anchors no longer in the diff"):format(#dropped), vim.log.levels.WARN)
  end
end

---Attach a comment to the current visual selection (or current line).
---Works in the review buffer (anchored through the diff map) and in any
---ordinary file buffer inside the repo (anchored directly to the new side).
---@param first integer|nil 1-indexed buffer line
---@param last integer|nil
function M.comment(first, last)
  local store = require("herdr-review.store")
  local ui = require("herdr-review.ui")

  local buf = vim.api.nvim_get_current_buf()
  first = first or vim.api.nvim_win_get_cursor(0)[1]
  last = last or first

  local anchor, err
  if ui.is_review_buf(buf) then
    anchor, err = ui.selection_to_anchor(buf, first, last)
  else
    anchor, err = require("herdr-review.source").anchor_of_buf(buf, first, last)
  end
  if not anchor then
    return notify(err or "selection covers no diff lines", vim.log.levels.ERROR)
  end

  ui.ensure_repaint()
  ui.input_comment(function(body)
    if not body or body == "" then
      return
    end
    store.add(vim.tbl_extend("force", anchor, { body = body }))
    if ui.is_review_buf(buf) then
      ui.mark_comments(store.ordered())
    else
      ui.mark_file_buf(buf, store.get(anchor.path))
    end
    notify(("comment on %s:%d (%d total)"):format(anchor.path, anchor.start_line, store.count()))
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
  local ok, why = herdr.available()
  if not ok then
    return notify(why or "herdr unavailable", vim.log.levels.ERROR)
  end

  local text = prompt.render(comments, M._meta)
  local function deliver(id)
    herdr.send(id, text, function(ok, err)
      if not ok then
        return notify(err or "send failed", vim.log.levels.ERROR)
      end
      notify(("sent %d comment(s) to %s"):format(#comments, id))
      store.clear()
      -- The comments left with the prompt, so the marks that advertise them as
      -- pending have to go too -- in file buffers as well as the review buffer.
      require("herdr-review.ui").clear_marks()
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
  local text = prompt.render(store.ordered(), M._meta)
  vim.api.nvim_echo({ { text } }, false, {})
end

function M.clear()
  require("herdr-review.store").clear()
  require("herdr-review.ui").clear_marks()
  notify("comments cleared")
end

return M
