local function unescape(s)
  local result = s:gsub("\\(.)", {
    a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v",
    ["\\"] = "\\", ['"'] = '"', ["'"] = "'"
  })
  return result
end


str = lpeg.P{ '"' * lpeg.C(('\\"' + (1 - lpeg.S('"')))^0) * '"' } / unescape
number = (lpeg.R("09")^1 * (lpeg.P(".") * lpeg.R("09")^1)^-1) / tonumber
boolean = lpeg.P("true") * lpeg.Cc(true) + lpeg.P("false") * lpeg.Cc(false)
null = lpeg.P("null") * lpeg.Cc(nil)
primitive = str + number + boolean + null

json = lpeg.P {
  "object",
  key = str,
  value = lpeg.V("object"),
  pair = lpeg.V("key") * ':' * lpeg.V("value") * lpeg.P(',')^-1,
  dictionary = '{' * lpeg.Ct("") * (lpeg.V("pair") % rawset)^0 * '}',

  element = lpeg.V("object") * lpeg.P(",")^-1,
  array = '[' * lpeg.Ct(lpeg.V("element")^0) * ']',

  object = primitive + lpeg.V("array") + lpeg.V("dictionary"),
}


function Reader(input, reader_options)
  local body = json:match(tostring(input))

  local document = pandoc.List()

  for name, data in pairs(body) do
    local header_id
    local type = data.type

    if data.type == nil then
      -- Function
      type = string.format("%s :: %s -> ??", name, table.concat(data.args, " -> "))
      header_id = string.format("function-builtins.%s", name)
    else
      header_id = string.format("constant-builtins.%s", name)
    end

    document:insert(pandoc.Header(2, "builtins."..name, { id = header_id }))

    local description = pandoc.read(data.doc, "markdown").blocks
    document:extend(pandoc.utils.make_sections(false, 3, description))

    document:insert(pandoc.Header(3, "Type"))
    document:insert(pandoc.CodeBlock(type))
  end

  return pandoc.Pandoc(document, { title = "builtins" })
end
