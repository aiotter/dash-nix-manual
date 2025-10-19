-- Adds anchor tags for Dash docset

local function percent_encode(str)
  return str:gsub("([^%w])", function(c) return string.format("%%%02X", string.byte(c)) end)
end

function Header(elem)
  if elem.attributes.type == nil then return nil end

  local type = elem.attributes.type
  local heading = pandoc.utils.stringify(elem)
  local display_name = elem.attributes.display_name or heading

  -- Insert <a name="//apple_ref/cpp/Entry Type/Entry Name" class="dashAnchor"></a>
  local id = string.format("//apple_ref/cpp/%s/%s", type, percent_encode(display_name))
  elem.content:insert(1, pandoc.Link({}, "", "", { class = "dashAnchor", name = id }))

  return elem
end
