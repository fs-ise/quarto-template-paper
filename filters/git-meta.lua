-- filters/git-meta.lua
--
-- What this filter does
-- 1) Reads Git metadata (short hash, branch, committer name, commit date)
-- 2) Stores it under doc.meta.git.{hash,branch,name,date,header}
-- 3) For PDF:
--    - Injects a LaTeX header macro \FSHeaderText via header-includes
--      (so your tex/inhouse.tex can remain pure LaTeX and just print \FSHeaderText)
-- 4) For DOCX (and optionally HTML):
--    - Inserts a "Version:" paragraph at the top of the document body
--
-- Requirements:
-- - `git` available during render
-- - repository contains .git (otherwise values are empty)
--
-- Optional overrides via environment variables:
--   QUARTO_GIT_HASH, QUARTO_GIT_BRANCH, QUARTO_GIT_NAME, QUARTO_GIT_DATE

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

local function get_git_meta()
  local meta = { hash="", branch="", name="", date="" }

  -- Allow CI/manual overrides
  meta.hash   = getenv("QUARTO_GIT_HASH")
  meta.branch = getenv("QUARTO_GIT_BRANCH")
  meta.name   = getenv("QUARTO_GIT_NAME")
  meta.date   = getenv("QUARTO_GIT_DATE")

  local all_set = (meta.hash ~= "" and meta.branch ~= "" and meta.name ~= "" and meta.date ~= "")
  if all_set then
    return meta
  end

  if not in_git_repo() then
    -- keep any env-provided fields; others remain empty
    return meta
  end

  if meta.hash == "" then
    meta.hash = run("git rev-parse --short HEAD")
  end

  if meta.branch == "" then
    meta.branch = run("git rev-parse --abbrev-ref HEAD")
    if meta.branch == "HEAD" then
      local ref = run("git name-rev --name-only HEAD")
      meta.branch = (ref ~= "" and ref or "detached")
    end
  end

  if meta.name == "" then
    meta.name = run("git log -1 --format=%cn")
  end

  if meta.date == "" then
    meta.date = run("git log -1 --format=%cd --date=short")
  end

  return meta
end

local function meta_get_string(meta, key1, key2)
  -- Reads doc.meta[key1][key2] as a string, safely.
  if not meta or not meta[key1] then return "" end
  local v = meta[key1]
  if key2 ~= nil then
    if not v[key2] then return "" end
    return trim(pandoc.utils.stringify(v[key2]))
  end
  return trim(pandoc.utils.stringify(v))
end

local function latex_escape(s)
  -- Minimal escaping for LaTeX header text (avoid breaking compilation)
  s = s or ""
  s = s:gsub("\\", "\\textbackslash{}")
  s = s:gsub("%%", "\\%%")
  s = s:gsub("&", "\\&")
  s = s:gsub("#", "\\#")
  s = s:gsub("_", "\\_")
  s = s:gsub("{", "\\{")
  s = s:gsub("}", "\\}")
  s = s:gsub("%^", "\\textasciicircum{}")
  s = s:gsub("~", "\\textasciitilde{}")
  return s
end

local function build_git_header(g)
  -- Human-readable tuple like: (2026-01-04, Name, branch, ab12cd3)
  local parts = {}
  if g.date   and g.date   ~= "" then table.insert(parts, g.date) end
  if g.name   and g.name   ~= "" then table.insert(parts, g.name) end
  if g.branch and g.branch ~= "" then table.insert(parts, g.branch) end
  if g.hash   and g.hash   ~= "" then table.insert(parts, g.hash) end

  if #parts == 0 then
    return ""
  end
  return "(" .. table.concat(parts, ", ") .. ")"
end

local function ensure_meta_list(x)
  if x == nil then return pandoc.MetaList({}) end
  -- Pandoc may give MetaBlocks/MetaInlines; we only use MetaList here.
  if x.t == "MetaList" then return x end
  return pandoc.MetaList({ x })
end

function Pandoc(doc)
  local g = get_git_meta()
  local git_header = build_git_header(g)

  -- Store nested metadata
  doc.meta.git = doc.meta.git or {}
  doc.meta.git.hash   = pandoc.MetaString(g.hash or "")
  doc.meta.git.branch = pandoc.MetaString(g.branch or "")
  doc.meta.git.name   = pandoc.MetaString(g.name or "")
  doc.meta.git.date   = pandoc.MetaString(g.date or "")
  doc.meta.git.header = pandoc.MetaString(git_header)

  -- Read project.* fields (optional, from your YAML)
  local abbrev     = meta_get_string(doc.meta, "project", "abbreviation")
  local manus_repo = meta_get_string(doc.meta, "project", "manuscriptrepository")
  local data_repo  = meta_get_string(doc.meta, "project", "datarepository")

  -- Build a plain-text version line (for Word / HTML)
  local version_line = ""
  if abbrev ~= "" then
    version_line = "@" .. abbrev
  end
  if git_header ~= "" then
    if version_line ~= "" then version_line = version_line .. " " end
    version_line = version_line .. git_header
  end
  if manus_repo ~= "" then
    if version_line ~= "" then version_line = version_line .. " — " end
    version_line = version_line .. "Manuscript repo: " .. manus_repo
  end
  if data_repo ~= "" then
    if version_line ~= "" then version_line = version_line .. " — " end
    version_line = version_line .. "Data repo: " .. data_repo
  end
  doc.meta.version_line = pandoc.MetaString(version_line)

  -- -------------
  -- PDF: inject LaTeX macro \FSHeaderText (consumed by tex/inhouse.tex)
  -- -------------
  if FORMAT:match("latex") then
    -- Compose LaTeX header text (link git tuple to manuscript repo if present)
    local header_tex = ""

    if abbrev ~= "" then
      header_tex = header_tex .. "@" .. latex_escape(abbrev) .. " "
    end

    if manus_repo ~= "" and git_header ~= "" then
      header_tex = header_tex
        .. "\\href{" .. manus_repo .. "}{\\underline{" .. latex_escape(git_header) .. "}}"
    elseif git_header ~= "" then
      header_tex = header_tex .. latex_escape(git_header)
    end

    if data_repo ~= "" then
      if header_tex ~= "" then header_tex = header_tex .. ", " end
      header_tex = header_tex
        .. "\\href{" .. data_repo .. "}{\\underline{data repository}}"
    end

    local inject = "\\renewcommand{\\FSHeaderText}{" .. header_tex .. "}"

    -- Ensure header-includes is a list and append a raw LaTeX block
    doc.meta["header-includes"] = ensure_meta_list(doc.meta["header-includes"])
    table.insert(
      doc.meta["header-includes"],
      pandoc.MetaBlocks({ pandoc.RawBlock("latex", inject) })
    )
  end

  -- -------------
  -- DOCX: insert a "Version:" paragraph at the top
  -- -------------
  if FORMAT:match("docx") then
    if version_line ~= "" then
      local para = pandoc.Para({
        pandoc.Str("Version:"),
        pandoc.Space(),
        pandoc.Str(version_line)
      })
      -- Optional: add a blank line after it
      local blank = pandoc.Para({ pandoc.Str("") })
      doc.blocks:insert(1, blank)
      doc.blocks:insert(1, para)
    end
  end

  -- Optional: also include it in HTML (uncomment if you want)
  -- if FORMAT:match("html") then
  --   if version_line ~= "" then
  --     local para = pandoc.Para({
  --       pandoc.Emph({ pandoc.Str("Version:"), pandoc.Space(), pandoc.Str(version_line) })
  --     })
  --     doc.blocks:insert(1, para)
  --   end
  -- end

  return doc
end
