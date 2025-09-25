FORMAT = "chunkedhtml"

function list_header_ids(blocks)
  local ids = {}
  blocks:walk({
    Header = function(elem)
      if elem.attributes.id then
        table.insert(ids, elem.attributes.id)
      end
    end,
  })
  return ids
end

function ByteStringWriter(doc, opts)
  doc = doc:walk({
    Header = function(elem)
      -- elem.identifier will be deleted by unknown reason while split_into_chunks;
      -- so we'll save it on elem.attributes.id for later use
      elem.attributes.id = elem.identifier
      return elem
    end
  })

  local chunked = pandoc.structure.split_into_chunks(doc, {
    path_template = opts.chunk_template,
    number_sections = true,
    base_heading_level = 1
  })

  local id_to_path = {}
  for chunk_number, chunk in pairs(chunked.chunks) do
    for _, id in pairs(list_header_ids(chunk.contents)) do
      id_to_path[id] = chunk.path
    end
  end

  local entries = {}
  for _, chunk in pairs(chunked.chunks) do
    -- Fix link (index.html#id -> generated_chunk.html#id)
    chunk.contents = chunk.contents:walk({
      Link = function(elem)
        local prefix = "index.html#"
        if elem.target:sub(1, #prefix) == prefix then
          local id = elem.target:sub(#prefix + 1)
          elem.target = (id_to_path[id] or "") .. elem.target:sub(#prefix)
        end
        return elem
      end
    })

    local template = pandoc.template.compile(pandoc.template.default("chunkedhtml"))

    local meta = chunked.meta
    meta.title = pandoc.utils.stringify(chunk.heading)

    local doc = pandoc.Pandoc(chunk.contents, meta)
    local text = pandoc.write(doc, "html", { template = template })
    local entry = pandoc.zip.Entry(chunk.path, text)
    table.insert(entries, entry)
  end

  local archive = pandoc.zip.Archive(entries)
  return archive:bytestring()
end

Template = pandoc.template.default("chunkedhtml")
