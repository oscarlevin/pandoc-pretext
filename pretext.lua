-- This is a sample custom writer for pandoc.  It produces output
-- that is very similar to that of pandoc's HTML writer.
-- There is one new feature: code blocks marked with class 'dot'
-- are piped through graphviz and images are included in the HTML
-- output using 'data:' URLs. The image format can be controlled
-- via the `image_format` metadata field.
--
-- Invoke with: pandoc -t pretext.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua pretext.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

local pipe = pandoc.pipe
local stringify = (require "pandoc.utils").stringify
local utils = require 'pandoc.utils'

-- Table to store sections:
local sections = {}

-- The global variable PANDOC_DOCUMENT contains the full AST of
-- the document which is going to be written. It can be used to
-- configure the writer.
local meta = PANDOC_DOCUMENT.meta
-- local blocks = PANDOC_DOCUMENT.blocks
-- local h = utils.hierarchicalize(blocks)
-- dumpit(h[1].contents[2].contents)
-- print(hierarchy[2].level)
-- dumpit(hierarchy[2].attr)
-- dumpit(hierarchy[1].contents[1].contents)
-- print(table.concat(hierarchy[1].numbering, '.'))
-- dumpit(block)

-- local h = pandoc.utils.hierarchicalize(pandoc.Pandoc)

-- dumpit(h[1].contents)

-- function Pandoc(doc)
--   local elements = pandoc.utils.hierarchicalize(doc.blocks)
--   print("it's working")
--   for _,e in ipairs(elements) do
--     print(e,t)
--   end
-- end


-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
  -- add <h0> at end of document for loop purposes.
  body = body .. '<h0>'
  --Loop over every possible header and wrap content with sections
  local sectionNames = {"section", "subsection", "subsubsection", "paragraphs", "paragraphs", "paragraphs"}
  for i=6, 1, -1 do
    local tag, closetag = "<h"..i..">", "</h"..i..">"
    while string.find(body, tag) ~= nil do
      for before, title, content, stop, after in string.gmatch(body, '(.-)'..tag..'(.-)'..closetag..'(.-)(<h%d>)(.*)') do
        body = before .. "<"..sectionNames[i]..">\n\t<title>" .. title .. "</title>" .. content .. "</"..sectionNames[i]..">\n" .. stop .. after
      end
    end
  end
  -- remove temporary ending <h0>
  body = string.sub(body,0,-5)

  return body
end


-- -- A function to add sections to a table, for insertion into body in last step (above)
-- function sectionBuilder(lev, s, title)
--   if lev == 1 then
--     secString = "<section>\n\t<title>" .. title .. "</title>\n" .. s .. "\n</section>"
--   elseif lev == 2 then
--     secString = "<subsection>\n\t<title>" .. title .. "</title>\n\n" .. s .. "\n</subsection>"
--   elseif lev == 3 then
--     secString = "<subsubsection>\n\t<title>" .. title .. "</title>\n\n" .. s .. "\n</subsubsection>"
--   else
--     secString = "<paragraphs>\n\t<title>" .. title .. "</title>\n\n" .. s .. "\n</paragraphs>"
--   end
--   table.insert(sections, secString)
-- end


-- We temporarily add <sec lev=> </sec> here, which will be cleaned up later
-- lev is an integer, the header level.
function Header(lev, s, attr)
  -- return '</sec><sec lev="' .. lev .. '" title="' .. s .. '">'
  -- if lev == 1 then
  --   return "<section" .. attributes(attr) .. ">\n\t<title>" .. s .. "</title>"
  -- else
  --   return "<subsection" .. attributes(attr) .. ">\n\t<title>" .. s .. "</title>"
  -- end
 -- return "<h" .. lev .. attributes(attr) ..  ">" .. s .. "</h" .. lev .. ">"
 return "<h" .. lev .. ">" .. s .. "</h" .. lev .. ">"
 -- return "<title>" .. s .. "</title>"
end


-- Chose the image format based on the value of the
-- `image_format` meta value.
local image_format = meta.image_format
  and stringify(meta.image_format)
  or "png"
local image_mime_type = ({
    jpeg = "image/jpeg",
    jpg = "image/jpeg",
    gif = "image/gif",
    png = "image/png",
    svg = "image/svg+xml",
  })[image_format]
  or error("unsupported image format `" .. img_format .. "`")
  

-- Character escaping
-- (might want to remove the quotes, double check pretext)
local function escape(s, in_attribute)
  return s:gsub("[<>&\"']",
    function(x)
      if x == '<' then
        return '&lt;'
      elseif x == '>' then
        return '&gt;'
      elseif x == '&' then
        return '&amp;'
      elseif x == '"' then
        return '&quot;'
      elseif x == "'" then
        return '&#39;'
      else
        return x
      end
    end)
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  -- dumpit(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      table.insert(attr_table, ' xml:' .. x .. '="' .. escape(y,true) .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
  return "\n\n\t"
end



-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

-- function Sec(level, numbering, attr, label, contents)
--   print(s)
--   print(level)
--   print(attr)
--   print(contents)
--   return "<sect>" .. s .. "</sect>"
-- end

function Str(s)
  return escape(s)
end

function Space()
  return " "
end

function SoftBreak()
  return " "
end

-- function LineBreak()
--  return "<br/>"
-- end

function Emph(s)
  return "<em>" .. s .. "</em>"
end

-- Not sure what to do here.  Term will probably have to be manually addressed.
function Strong(s)
  return "<alert>" .. s .. "</alert>"
end

function Subscript(s)
  return "<sub>" .. s .. "</sub>"
end

function Superscript(s)
  return "<sup>" .. s .. "</sup>"
end

-- Not sure if this is right.
function SmallCaps(s)
  return '<alert>' .. s .. '<alert>'
end

-- could also be "gone"
function Strikeout(s)
  return '<delete>' .. s .. '</delete>'
end

function Link(s, src, tit, attr)
  return '<url href="' .. escape(src,true) .. '">' .. s .. '</url>'
end

function Image(s, src, tit, attr)
  return "<image source='" .. escape(src,true) .. "'/>"
end

function Code(s, attr)
  return "<c" .. attributes(attr) .. ">" .. escape(s) .. "</c>"
end

function InlineMath(s)
  return "<m>" .. escape(s) .. "</m>"
end

function DisplayMath(s)
  return "<me>" .. escape(s) .. "</me>"
end

function SingleQuoted(s)
  return "<sq>" .. s .. "</sq>"
end

function DoubleQuoted(s)
  return "<q>" .. s .. "</q>"
end

function Note(s)
  local num = #notes + 1
  -- insert the back reference right before the final closing tag.
  s = string.gsub(s,
          '(.*)</', '%1 <a href="#fnref' .. num ..  '">&#8617;</a></')
  -- add a list item with the note to the note table.
  table.insert(notes, '<li xml:id="fn' .. num .. '">' .. s .. '</li>')
  -- return the footnote reference, linked to the note.
  return '<a xml:id="fnref' .. num .. '" href="#fn' .. num ..
            '"><sup>' .. num .. '</sup></a>'
end

function Span(s, attr)
  return s
--  return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
end

function RawInline(format, str)
  if format == "html" then
    return str
  else
    return ''
  end
end

function Cite(s, cs)
  local ids = {}
  for _,cit in ipairs(cs) do
    table.insert(ids, cit.citationId)
  end
  return "<span class=\"cite\" data-citation-ids=\"" .. table.concat(ids, ",") ..
    "\">" .. s .. "</span>"
end

function Plain(s)
  return s
end

function Para(s)
  return "<p>\n\t\t" .. s .. "\n\t</p>"
end


function BlockQuote(s)
  return "<blockquote>\n\t\t" .. s .. "\n\t</blockquote>"
end

-- Remove:
function HorizontalRule()
--  return "<hr/>"
  return "\n\n"
end

function LineBlock(ls)
  return '<div style="white-space: pre-line;">' .. table.concat(ls, '\n') ..
         '</div>'
end

function CodeBlock(s, attr)
  -- If code block has class 'dot', pipe the contents through dot
  -- and base64, and include the base64-encoded png as a data: URL.
  if attr.class and string.match(' ' .. attr.class .. ' ',' dot ') then
    local img = pipe("base64", {}, pipe("dot", {"-T" .. image_format}, s))
    return '<img src="data:' .. image_mime_type .. ';base64,' .. img .. '"/>'
  -- otherwise treat as code (one could pipe through a highlighter)
  else
    return "<pre>" .. escape(s) ..
           "</pre>"
  end
end

function BulletList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, "<li>" .. item .. "</li>")
  end
  return "<ul>\n\t\t" .. table.concat(buffer, "\n\t") .. "\n\t</ul>"
end

function OrderedList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, "<li>" .. item .. "</li>")
  end
  return "<ol>\n\t\t" .. table.concat(buffer, "\n") .. "\n\t</ol>"
end

function DefinitionList(items)
  local buffer = {}
  for _,item in pairs(items) do
    local k, v = next(item)
    table.insert(buffer, "<dt>" .. k .. "</dt>\n<dd>" ..
                   table.concat(v, "</dd>\n<dd>") .. "</dd>")
  end
  return "<dl>\n\t\t" .. table.concat(buffer, "\n") .. "\n\t</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

function CaptionedImage(src, tit, caption, attr)
   return '<figure>\n<image source="' .. escape(src,true) ..
      '"/>\n' ..
      '<caption>' .. caption .. '</caption>\n</figure>'
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add("<table>")
  if caption ~= "" then
    add("<caption>" .. caption .. "</caption>")
  end
  if widths and widths[1] ~= 0 then
    for _, w in pairs(widths) do
      add('<col width="' .. string.format("%.0f%%", w * 100) .. '" />')
    end
  end
  local header_row = {}
  local empty_header = true
  for i, h in pairs(headers) do
    local align = html_align(aligns[i])
    table.insert(header_row,'<th align="' .. align .. '">' .. h .. '</th>')
    empty_header = empty_header and h == ""
  end
  if empty_header then
    head = ""
  else
    add('<tr class="header">')
    for _,h in pairs(header_row) do
      add(h)
    end
    add('</tr>')
  end
  local class = "even"
  for _, row in pairs(rows) do
    class = (class == "even" and "odd") or "even"
    add('<tr class="' .. class .. '">')
    for i,c in pairs(row) do
      add('<td align="' .. html_align(aligns[i]) .. '">' .. c .. '</td>')
    end
    add('</tr>')
  end
  add('</table>')
  return table.concat(buffer,'\n')
end

function RawBlock(format, str)
  return "<cd>\n\t\t" .. str .. "\n\t</cd>"
end

function Div(s, attr)
  return s .. "\n"
--  return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
end

-- -- Doesn't work:
-- function Sections(lev, num, attr, label, s)
--   return "<section test " .. lev .. num .. attributes(attr) .. label .. ">" .. s .. "</section test>" 
-- end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return "" end
  end
setmetatable(_G, meta)

