traverse = "topdown"

local function starts_with(str, prefix)
  return str and str:sub(1, #prefix) == prefix
end

function Header(elem)
  if elem.level > 2 then return nil, false end

  if starts_with(elem.identifier, "function-") then
    -- lib.string.escape -> escape
    elem.attributes.display_name = pandoc.utils.stringify(elem):gsub("^.*%.(.+)$", "%1")
    elem.attributes.type = "Function"
  elseif starts_with(elem.identifier, "constant-") then
    elem.attributes.type = "Constant"
  elseif starts_with(elem.identifier, "sec-functions-library-") then
    elem.attributes.type = "Module"
  elseif starts_with(elem.identifier, "sec-") then
    elem.attributes.type = "Section"
  elseif elem.level == 1 then
    elem.attributes.type = "Guide"
  else
    return nil
  end

  return elem
end
