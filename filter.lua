local database_file = "docSet.dsidx"

local sql_statements = {
  "CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);",
  "CREATE UNIQUE INDEX IF NOT EXISTS anchor ON searchIndex (name, type, path);",
}

local function starts_with(str, prefix)
  return str and str:sub(1, #prefix) == prefix
end

local function percent_encode(str)
  return str:gsub("([^%w])", function(c) string.format("%%%02X", string.byte(c)) end)
end

local function Header(elem)
  if elem.level > 2 then return nil end

  local type
  if starts_with(elem.identifier, "function-") then
    type = "Function"
  elseif starts_with(elem.identifier, "constant-") then
    type = "Constant"
  elseif starts_with(elem.identifier, "sec-") then
    type = "Section"
  else
    return nil
  end

  local heading = pandoc.utils.stringify(elem)
  local display_name = heading:gsub("^.*%.(.+)$", "%1")  -- lib.string.escape -> escape
  local id = string.format("//apple_ref/cpp/%s/%s", type, percent_encode(display_name))

  -- Insert <a name="//apple_ref/cpp/Entry Type/Entry Name" class="dashAnchor"></a>
  elem.content:insert(1, pandoc.Link({}, "", "", { class = "dashAnchor", name = id }))

  local sql = string.format(
    "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('%s', '%s', '%s');",
    heading:gsub("'", "''"),
    type,
    table.concat({
      string.format("<dash_entry_name=%s>", display_name),
      string.format("<dash_entry_originalName=%s>", heading),
      string.format("<dash_entry_menuDescription=%s>", heading:gsub("^(.*)%..+$", "%1")),
      string.format("./%s#%s", PANDOC_STATE.output_file, id),
    }):gsub("'", "''")
  )
  table.insert(sql_statements, sql)

  return elem
end


return {
  Pandoc = function(doc)
    doc = doc:walk { Header = Header }

    pandoc.pipe("sqlite3", {database_file}, table.concat(sql_statements, "\n"))

    return doc
  end,
}
