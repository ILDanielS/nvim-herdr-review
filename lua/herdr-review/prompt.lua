--- Render the comment set into agent-directed text.
local M = {}

---@param c HerdrReview.Comment
---@return string
function M.render_comment(c)
  local range = (c.start_line == c.end_line) and tostring(c.start_line)
    or (c.start_line .. "-" .. c.end_line)
  local parts = { ("### %s:%s (%s side)"):format(c.path, range, c.side) }
  if c.context and #c.context > 0 then
    table.insert(parts, "```diff\n" .. table.concat(c.context, "\n") .. "\n```")
  end
  table.insert(parts, c.body)
  return table.concat(parts, "\n\n")
end

---@param comments HerdrReview.Comment[]
---@param meta { base: string|nil, sha: string|nil }|nil
---@return string
function M.render(comments, meta)
  local out = {
    "Code review feedback on your changes.",
    "Address each comment below. Locations are given as path:line against the current working tree.",
  }
  if meta and meta.base then
    table.insert(out, ("Reviewed against base `%s`."):format(meta.base))
  end
  table.insert(out, "")
  for _, c in ipairs(comments) do
    table.insert(out, M.render_comment(c))
    table.insert(out, "")
  end
  return table.concat(out, "\n")
end

return M
