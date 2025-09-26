local sql_statements = {
  "CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);",
  "CREATE UNIQUE INDEX IF NOT EXISTS anchor ON searchIndex (name, type, path);",
}

local metadata = {
  database_file = "./docSet.dsidx",
  menu_description = nil,
}


local function percent_encode(str)
  return str:gsub("([^%w])", function(c) return string.format("%%%02X", string.byte(c)) end)
end

local function Header(elem)
  if elem.attributes.type == nil then return nil end

  local type = elem.attributes.type
  local heading = pandoc.utils.stringify(elem)
  local display_name = elem.attributes.display_name or heading
  local file_path = metadata.outputfile or PANDOC_STATE.output_file

  -- Insert <a name="//apple_ref/cpp/Entry Type/Entry Name" class="dashAnchor"></a>
  local id = string.format("//apple_ref/cpp/%s/%s", type, percent_encode(display_name))
  elem.content:insert(1, pandoc.Link({}, "", "", { class = "dashAnchor", name = id }))

  local sql = string.format(
    "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES ('%s', '%s', '%s');",
    heading:gsub("'", "''"),
    type,
    table.concat({
      string.format("<dash_entry_name=%s>", display_name),
      string.format("<dash_entry_originalName=%s>", heading),
      string.format("<dash_entry_menuDescription=%s>", metadata.menu_description or heading:gsub("^(.*)%..+$", "%1")),
      string.format("./%s#%s", file_path, id),
    }):gsub("'", "''")
  )
  table.insert(sql_statements, sql)

  return elem
end


return {
  Meta = function(meta)
    for key, value in pairs(meta) do
      metadata[key] = value
    end
  end,

  Pandoc = function(doc)
    doc = doc:walk { Header = Header }

    pandoc.pipe("sqlite3", {metadata.database_file}, table.concat(sql_statements, "\n"))

    return doc
  end,
}
