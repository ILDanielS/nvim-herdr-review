-- Bare test runner: no plugin deps. `make test` or
-- nvim --headless --clean -u tests/minit.lua
vim.opt.runtimepath:append(vim.uv.cwd())
-- Specs load real repo files as buffers; a stale or live swap file must not
-- turn the suite into an interactive E325 prompt.
vim.opt.swapfile = false
vim.opt.shortmess:append("A")

local pass, fail = 0, 0
local failures = {}

---@param name string
---@param fn fun()
function _G.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    table.insert(failures, ("  %s\n    %s"):format(name, err))
  end
end

function _G.eq(got, want, msg)
  local a, b = vim.inspect(got), vim.inspect(want)
  if a ~= b then
    error((msg and msg .. ": " or "") .. ("expected %s, got %s"):format(b, a), 2)
  end
end

function _G.truthy(v, msg)
  if not v then
    error(msg or "expected truthy value", 2)
  end
end

for _, file in ipairs(vim.fn.glob("tests/*_spec.lua", false, true)) do
  dofile(file)
end

print(("\n%d passed, %d failed"):format(pass, fail))
if fail > 0 then
  print(table.concat(failures, "\n"))
end
vim.cmd(fail > 0 and "cq" or "qa!")
