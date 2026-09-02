-- Command registration only; the Lua modules stay lazily loadable.
if vim.g.loaded_herdr_review then
  return
end
vim.g.loaded_herdr_review = true

local function api()
  return require("herdr-review")
end

local cmd = vim.api.nvim_create_user_command

cmd("HerdrReview", function()
  api().open()
end, { desc = "Open the review buffer for the working-tree diff" })

cmd("HerdrReviewRefresh", function()
  api().refresh()
end, { desc = "Recompute the diff and reconcile comments" })

cmd("HerdrReviewComment", function(o)
  api().comment(o.line1, o.line2)
end, { range = true, desc = "Comment on the selected diff region" })

cmd("HerdrReviewSubmit", function(o)
  api().submit(o.args ~= "" and o.args or nil)
end, { nargs = "?", desc = "Send all comments to a Herdr agent" })

cmd("HerdrReviewPreview", function()
  api().preview()
end, { desc = "Show the prompt that would be sent" })

cmd("HerdrReviewClear", function()
  api().clear()
end, { desc = "Discard all comments" })
