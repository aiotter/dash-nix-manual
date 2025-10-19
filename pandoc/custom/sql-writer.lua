-- Custom writer to create SQL statements from docset HTML

local prefix = {
  "CREATE TABLE IF NOT EXISTS searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT);",
  "CREATE UNIQUE INDEX IF NOT EXISTS anchor ON searchIndex (name, type, path);",
  "",  -- blank line
}

local function percent_encode(str)
  return str:gsub("([^%w])", function(c) return string.format("%%%02X", string.byte(c)) end)
end

function Writer(doc, opts)
  local output = prefix

  local metadata = {
    path = PANDOC_STATE.input_files:at(1),
    menu_description = nil,
  }

  for key, value in pairs(doc.meta) do
    metadata[key] = value
  end

  doc.blocks:walk({
    Header = function(elem)
      if elem.attributes.type == nil then return nil end

      local type = elem.attributes.type
      local heading = pandoc.utils.stringify(elem)
      local display_name = elem.attributes.display_name or heading
      local menu_description = metadata.menu_description or heading:gsub("^(.*)%..+$", "%1")

      local sql = string.format(
        "INSERT INTO searchIndex(name, type, path) VALUES ('%s', '%s', '%s');",
        heading:gsub("'", "''"),
        type,
        table.concat({
          string.format("<dash_entry_name=%s>", percent_encode(display_name)),
          string.format("<dash_entry_originalName=%s>", percent_encode(heading)),
          string.format("<dash_entry_menuDescription=%s>", percent_encode(menu_description)),
          string.format("./%s#%s", metadata.path, elem.identifier),
        }):gsub("'", "''")
      )

      table.insert(output, sql)
    end
  })

  return table.concat(output, "\n")
end
