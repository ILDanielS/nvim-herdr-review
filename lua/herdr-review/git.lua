--- Git plumbing: repo root, base branch resolution, merge-base diff.
--- Always diffs against `git merge-base <base> HEAD`, never the base tip.
local M = {}

---Run a git command synchronously in `cwd`.
---@param args string[]
---@param cwd string|nil
---@return boolean ok, string out
local function git(args, cwd)
  local res = vim.system({ "git", unpack(args) }, { cwd = cwd, text = true }):wait()
  local out = (res.code == 0) and res.stdout or res.stderr
  return res.code == 0, vim.trim(out or "")
end

M._git = git

---@param path string|nil defaults to cwd
---@return string|nil root, string|nil err
function M.repo_root(path)
  local ok, out = git({ "rev-parse", "--show-toplevel" }, path or vim.uv.cwd())
  if not ok then
    return nil, "not a git repository: " .. out
  end
  return out
end

---Resolve the branch a review is measured against.
---Order: explicit config -> upstream of HEAD -> origin/HEAD -> main -> master.
---@param root string
---@param configured string|nil
---@return string|nil base, string|nil err
function M.base_branch(root, configured)
  -- TODO: probe candidates with `git rev-parse --verify`.
  return configured, nil
end

---@param root string
---@param base string
---@return string|nil sha, string|nil err
function M.merge_base(root, base)
  -- TODO: git merge-base <base> HEAD
  return nil, "not implemented"
end

---Unified diff of the working tree (incl. untracked?) against `sha`.
---@param root string
---@param sha string
---@return string|nil diff, string|nil err
function M.diff_against(root, sha)
  -- TODO: git diff --no-color --no-ext-diff -U3 <sha> --
  return nil, "not implemented"
end

---Convenience: root + base + merge-base + diff in one call.
---@param opts { base_branch: string|nil, cwd: string|nil }
---@return { root: string, base: string, sha: string, diff: string }|nil, string|nil err
function M.working_tree_diff(opts)
  return nil, "not implemented"
end

return M
