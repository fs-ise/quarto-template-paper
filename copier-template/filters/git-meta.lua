-- filters/git-meta.lua
-- Derive document-type booleans and inject git metadata when needed.

local function trim(s)
  if s == nil then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function getenv(name)
  return trim(os.getenv(name))
end

local function run(cmd)
  local f = io.popen(cmd .. " 2>/dev/null")
  if not f then return "" end
  local out = f:read("*a")
  f:close()
  return trim(out)
end

local function in_git_repo()
  return run("git rev-parse --is-inside-work-tree") == "true"
end

local function get_meta_string(meta, key)
  if not meta or not meta[key] then return "" end
  return trim(pandoc.utils.stringify(meta[key]))
end

local function ensure_meta_list(x)
  if x == nil then return pandoc.MetaList({}) end
  if x.t == "MetaList" then return x end
  return pandoc.MetaList({ x })
end

local function meta_to_string(x)
  if x == nil then return "" end
  return trim(pandoc.utils.stringify(x))
end

local function normalize_preprint_authors(authors_meta)
  local normalized = {}

  local function append_author(value)
    local v = trim(value or "")
    if v ~= "" then
      table.insert(normalized, pandoc.MetaString(v))
    end
  end

  if authors_meta == nil then
    return pandoc.MetaList(normalized)
  end

  local function extract_author_name(author)
    if author == nil then return "" end

    if author.t == "MetaMap" then
      if author.name ~= nil then
        return extract_author_name(author.name)
      end
      if author.literal ~= nil then
        return trim(meta_to_string(author.literal))
      end
      if author.given ~= nil or author.family ~= nil then
        local given = extract_author_name(author.given)
        local family = extract_author_name(author.family)
        return trim(given .. " " .. family)
      end

      -- Never stringify arbitrary MetaMaps; they may contain rich metadata
      -- like affiliations, roles, booleans, and URLs.
      return ""
    end

    if author.t == "MetaList" then
      local parts = {}
      for _, part in ipairs(author) do
        local name_part = extract_author_name(part)
        if name_part ~= "" then table.insert(parts, name_part) end
      end
      return trim(table.concat(parts, " "))
    end

    -- MetaString / MetaInlines / MetaBlocks fall back to stringify.
    return trim(meta_to_string(author))
  end

  if authors_meta.t == "MetaList" then
    for _, author in ipairs(authors_meta) do
      append_author(extract_author_name(author))
    end
  else
    append_author(extract_author_name(authors_meta))
  end

  return pandoc.MetaList(normalized)
end

local function get_git_meta()
  local git = {
    commit = getenv("QUARTO_GIT_HASH"),
    author = getenv("QUARTO_GIT_NAME"),
    date = getenv("QUARTO_GIT_DATE")
  }

  if in_git_repo() then
    if git.commit == "" then git.commit = run("git log -1 --pretty=format:'%h'") end
    if git.author == "" then git.author = run("git log -1 --pretty=format:'%an'") end
    if git.date == "" then git.date = run("git log -1 --pretty=format:'%ad'") end
  end

  return git
end

function Pandoc(doc)
  local document_type = get_meta_string(doc.meta, "document_type")
  if document_type == "" then
    document_type = "working_paper"
    doc.meta.document_type = pandoc.MetaString(document_type)
  end

  local is_working_paper = document_type == "working_paper"
  local is_preprint = document_type == "preprint"

  doc.meta.is_working_paper = pandoc.MetaBool(is_working_paper)
  doc.meta.is_preprint = pandoc.MetaBool(is_preprint)

  -- Keep backward compatibility for the old header macro, but only for working papers.
  if FORMAT:match("latex") and is_working_paper then
    local git = get_git_meta()
    local header_parts = {}
    if git.date ~= "" then table.insert(header_parts, git.date) end
    if git.author ~= "" then table.insert(header_parts, git.author) end
    if git.commit ~= "" then table.insert(header_parts, git.commit) end

    local header_text = ""
    if #header_parts > 0 then
      header_text = "(" .. table.concat(header_parts, ", ") .. ")"
    end

    doc.meta["header-includes"] = ensure_meta_list(doc.meta["header-includes"])
    table.insert(
      doc.meta["header-includes"],
      pandoc.MetaBlocks({ pandoc.RawBlock("latex", "\\renewcommand{\\FSHeaderText}{" .. header_text .. "}") })
    )
  end

  return doc
end
