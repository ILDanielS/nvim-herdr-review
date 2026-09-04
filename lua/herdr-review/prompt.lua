--- Render the comment set into agent-directed text.
local M = {}

---@param c HerdrReview.Comment
---@return string
function M.render_comment(c)
  local range = (c.start_line == c.end_line) and tostring(c.start_line)
    or (c.start_line .. "-" .. c.end_line)
  local where = (c.origin == "file") and "working tree" or (c.side .. " side")
  local parts = { ("### %s:%s (%s)"):format(c.path, range, where) }
  if c.context and #c.context > 0 then
    -- File-buffer context is numbered source with the selection marked by `>`,
    -- not a diff; fencing it as diff would render `-`/`+` lines as changes.
    local lang = (c.origin == "file") and "text" or "diff"
    table.insert(parts, ("```%s\n%s\n```"):format(lang, table.concat(c.context, "\n")))
  end
  table.insert(parts, c.body)
  return table.concat(parts, "\n\n")
end

---Serialize the comment set. Nothing is added around the comments themselves:
---the agent receives the review and no framing prose.
---@param comments HerdrReview.Comment[]
---@param _meta { base: string|nil, sha: string|nil }|nil unused; kept for callers
---@return string
function M.render(comments, _meta)
  local out = {}
  for _, c in ipairs(comments) do
    table.insert(out, M.render_comment(c))
  end
  return table.concat(out, "\n\n")
end

return M
