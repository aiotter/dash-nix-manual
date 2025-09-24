local function classes_eq(elem, classes)
  return elem.classes == pandoc.List(classes)
end

function top(elem)
  return elem:walk({
    traverse = "topdown",
    Div = function(elem)
      if elem.classes == pandoc.List({ "navheader" }) then
        return {}, false
      elseif elem.classes == pandoc.List({ "navfooter" }) then
        return {}, false
      elseif elem.classes == pandoc.List({ "book" }) then
        local chapters = book_div(elem).content
        for elem in chapters:iter() do
          elem.classes:insert(1, "book")
        end
        return chapters, false
      end
    end,
  })
end

function book_div(elem)
  return elem:walk({
    traverse = "topdown",
    Div = function(elem)
      if classes_eq(elem, { "titlepage" }) then
        return {}, false
      elseif classes_eq(elem, { "toc" }) then
        return {}, false
      elseif classes_eq(elem, { "list-of-examples" }) then
        return {}, false
      elseif classes_eq(elem, { "chapter" }) or classes_eq(elem, { "part" }) then

        local header = elem:walk({
          traverse = "topdown",
          Div = function(elem)
            if classes_eq(elem, { "titlepage" }) then
              -- flatten div
              return elem:walk({ Div = function(elem) return elem.content end }).content, false
            else
              return {}, false
            end
          end,
        }).content:at(1)

        local others = elem:walk({
          traverse = "topdown",
          Div = function(elem)
            if classes_eq(elem, { "titlepage" }) then
              return {}, false
            else
              return elem, false
            end
          end,
        })

        return {header, others}, false
      end
    end,
  })
end

function Pandoc(document)
  return top(document)
end
