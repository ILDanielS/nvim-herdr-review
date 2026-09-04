--- User-facing configuration.
local M = {}

---@class HerdrReview.Config
---@field base_branch string|nil Explicit base branch; nil = auto-detect.
---@field herdr_cmd string Executable used to talk to Herdr.
---@field keymaps table<string, string|false> Buffer-local maps in the review buffer.
local defaults = {
  base_branch = nil,
  herdr_cmd = "herdr",
  keymaps = {
    comment = "c",
    submit = "<leader>rs",
    refresh = "R",
    close = "q",
  },
}

M.options = vim.deepcopy(defaults)

---@param opts HerdrReview.Config|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
