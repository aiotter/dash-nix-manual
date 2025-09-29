Template = pandoc.template.get("nixpkgs.html")
template = pandoc.template.compile(Template)

function ByteStringWriter(doc, opts)
  local main_pred = function(elem) return elem.classes == pandoc.List({ "book" }) end
  local main = doc.blocks:find_if(main_pred, 1)
  
  local top_page = pandoc.Blocks({table.unpack(main.content, 1, 3)}, doc.metadata)
  local pages = {top_page, table.unpack(main.content, 4)}

  local id_to_path = {}
  for i, page in pairs(pages) do
    local filename
    local meta = doc.meta
    if i == 1 then
      meta.outputfile = "index.html"
    else
      meta.outputfile = string.format("%d.html", i)
    end

    page:walk({
      Header = function(elem)
        id_to_path[elem.identifier] = meta.outputfile
      end,
    })

    page = pandoc.Div(page, { class = "book" })
    pages[i] = pandoc.Pandoc(page, meta)
  end

  local entries = {}
  for i, page in pairs(pages) do
    local filename = page.meta.outputfile

    page = page:walk({
      Link = function(elem)
        -- fix links between generated pages
        local prefix = "index.html#"
        if elem.target:sub(1, #prefix) == prefix then
          local id = elem.target:sub(#prefix + 1)
          elem.target = (id_to_path[id] or "") .. elem.target:sub(#prefix)
        end
        return elem
      end,

      RawBlock = function(elem)
        -- open every <details> tag
        elem.text = elem.text:gsub("^<details", "<details open", 1)
        return elem
      end,
    })

    if doc.meta.outputdir then
      page.meta.outputfile = pandoc.path.join({doc.meta.outputdir, filename})
    end

    -- apply filter if meta.filter is given
    local filters = page.meta.filter or {}
    if type(filters) == "string" then
      filters = {filters}
    end
    for _, filter in pairs(filters) do
      local filter_path
      if os.execute(string.format("test -f '%s'", filter)) then
        filter_path = filter
      else
        filter_path = pandoc.path.join({PANDOC_STATE.user_data_dir, "filters", filter})
      end

      page = pandoc.utils.run_lua_filter(page, filter_path)
    end

    local text = pandoc.write(page, "html", { template = template })
    local entry = pandoc.zip.Entry(filename, text)
    table.insert(entries, entry)
  end

  local archive = pandoc.zip.Archive(entries)
  return archive:bytestring()
end

