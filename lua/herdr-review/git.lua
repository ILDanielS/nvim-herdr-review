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

---Same, but preserves the output verbatim. Diff payloads must not be trimmed:
---a trailing context line can legitimately end in whitespace.
---@param args string[]
---@param cwd string|nil
---@return boolean ok, string out
local function git_raw(args, cwd)
  local res = vim.system({ "git", unpack(args) }, { cwd = cwd, text = true }):wait()
  if res.code ~= 0 then
    return false, vim.trim(res.stderr or "")
  end
  return true, res.stdout or ""
end

---@param path string|nil defaults to cwd
---@return string|nil root, string|nil err
function M.repo_root(path)
  local ok, out = git({ "rev-parse", "--show-toplevel" }, path or vim.uv.cwd())
  if not ok then
    return nil, "not a git repository: " .. out
  end
  return out
end

---@param root string
---@param ref string
---@return boolean
local function has_ref(root, ref)
  return (git({ "rev-parse", "--verify", "--quiet", ref .. "^{commit}" }, root))
end

---Resolve the branch a review is measured against.
---Order: explicit config -> upstream of HEAD -> origin/HEAD -> main -> master.
---@param root string
---@param configured string|nil
---@return string|nil base, string|nil err
function M.base_branch(root, configured)
  if configured and configured ~= "" then
    if not has_ref(root, configured) then
      return nil, "base branch not found: " .. configured
    end
    return configured
  end

  local ok, out = git({ "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}" }, root)
  if ok and out ~= "" then
    return out
  end

  ok, out = git({ "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" }, root)
  if ok and out ~= "" then
    return out
  end

  for _, candidate in ipairs({ "main", "master" }) do
    if has_ref(root, candidate) then
      return candidate
    end
  end
  return nil, "could not resolve a base branch; set `base_branch` in setup()"
end

---@param root string
---@param base string
---@return string|nil sha, string|nil err
function M.merge_base(root, base)
  local ok, out = git({ "merge-base", base, "HEAD" }, root)
  if not ok or out == "" then
    return nil, ("no merge-base between `%s` and HEAD: %s"):format(base, out)
  end
  return out
end

---Unified diff of the working tree against `sha`. Untracked files are not
---included: they have no blob on either side, so they carry no diff anchors.
---@param root string
---@param sha string
---@return string|nil diff, string|nil err
function M.diff_against(root, sha)
  local ok, out = git_raw({ "diff", "--no-color", "--no-ext-diff", "-U3", sha, "--" }, root)
  if not ok then
    return nil, "git diff failed: " .. out
  end
  return out
end

---Convenience: root + base + merge-base + diff in one call.
---@param opts { base_branch: string|nil, cwd: string|nil }
---@return { root: string, base: string, sha: string, diff: string }|nil, string|nil err
function M.working_tree_diff(opts)
  opts = opts or {}
  local root, err = M.repo_root(opts.cwd)
  if not root then
    return nil, err
  end
  local base, berr = M.base_branch(root, opts.base_branch)
  if not base then
    return nil, berr
  end
  local sha, serr = M.merge_base(root, base)
  if not sha then
    return nil, serr
  end
  local diff, derr = M.diff_against(root, sha)
  if not diff then
    return nil, derr
  end
  return { root = root, base = base, sha = sha, diff = diff }
end

return M
