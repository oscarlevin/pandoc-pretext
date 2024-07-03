-- This is a PreTeXt custom writer for pandoc,
-- based loosely on the JATS custom writter: https://github.com/mfenner/pandoc-jats. 
--
-- Invoke with: pandoc -t pretext.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua pretext.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

-- The following breaks older pandoc installs, and it doesn't seem to be necessary for what I want to do.
-- local pipe = pandoc.pipe
-- local stringify = (require "pandoc.utils").stringify
-- local utils = require 'pandoc.utils'

-- The global variable PANDOC_DOCUMENT contains the full AST of
-- the document which is going to be written. It can be used to
-- configure the writer.
-- local meta = PANDOC_DOCUMENT.meta

-- global variable to keep track of indent level:
indents = 1

--We define the section names that correspond to the different levels.
sectionNames = {"section", "subsection", "subsubsection", "paragraphs", "paragraphs", "paragraphs"}
--sectionBuffer will be a stack that hold the current open divisions
sectionBuffer = {}

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)

  -- close any open sections:
  while 1 <= #sectionBuffer do
    body = body .. "\n" .. string.rep("\t",#sectionBuffer) .. "</".. sectionBuffer[1]..">\n"
    table.remove(sectionBuffer,1)
  end
  -- add common start/end tags
  body = '<?xml version="1.0" encoding="UTF-8" ?>\n<!-- Generated by Pandoc using pretext.lua -->\n<pretext>\n<article>\n\n\n'..body..'\n\n\n</article>\n</pretext>'

  return body
end


-- Chose the image format based on the value of the
-- `image_format` meta value.
-- local image_format = meta.image_format
--   and stringify(meta.image_format)
--   or "png"
-- local image_mime_type = ({
--     jpeg = "image/jpeg",
--     jpg = "image/jpeg",
--     gif = "image/gif",
--     png = "image/png",
--     svg = "image/svg+xml",
--   })[image_format]
--   or error("unsupported image format `" .. img_format .. "`")
  
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
      -- elseif x == '"' then
      --   return '&quot;'
      -- elseif x == "'" then
      --   return '&#39;'
      else
        return x
      end
    end)
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      if x == "id" then
        table.insert(attr_table, ' xml:id="' .. escape(y,true)..'"')
      else
        table.insert(attr_table, ' '..x .. '="' .. escape(y,true) .. '"')
      end
    end
  end
  return table.concat(attr_table)
end

-- Blocksep is used to separate block elements.
function Blocksep()
  return "\n\n"
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
  return escape(s)
end

function Space()
  return " "
end

function SoftBreak()
  return " "
end

--No PreTeXt equivalent to linebreak.  Comment inserted for manual post-processing.
function LineBreak()
 return "<!-- linebreak -->"
end

function Emph(s)
  return "<em>" .. s .. "</em>"
end

-- No <bold> tag in PreTeXt, but <term> gives bold look.  Assume bold in source document denotes a term, otherwise author could search for <term> and fix case-by-case. 
function Strong(s)
  return "<term>" .. s .. "</term>"
end

function Subscript(s)
  return "<sub>" .. s .. "</sub>"
end

function Superscript(s)
  return "<sup>" .. s .. "</sup>"
end

-- No <smallcaps> in PreTeXt.  <alert> can be searched for and changed case-by-case.
function SmallCaps(s)
  return '<alert>' .. s .. '<alert>'
end

-- could also be "gone"
function Strikeout(s)
  return '<delete>' .. s .. '</delete>'
end

function Link(s, src, tit, attr)
  if string.sub(src, 1, 1) == "#" then
    return '<xref ref="'..escape(string.sub(src, 2))..'" />'
  else
    return '<url href="' .. escape(src,true) .. '">' .. s .. '</url>'
  end
end

-- Should this be enclosed in something like a stand-alone side-by-side?
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
  return "<fn>" .. s .. "</fn>"
end

function Span(s, attr)
 -- return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
 return s
end

-- RowInline is a way to pass certain html or latex directly to the output if there is no equivalent in the AST.  Seems to only be for \cite, \ref. For now, we just leave it blank, so these elements are just dropped.
function RawInline(format, str)
  -- if format == "html" then
  --   return "<raw-html>"..str.."</raw-html>"
  -- else
  --   return "<raw "..format..">"..str.."</raw>"
  -- end
  return ''
end

-- FIXME: this might still be wrong.  Specifically, not sure what happens when multiple ids are present.
function Cite(s, cs)
  local ids = {}
  for _,cit in ipairs(cs) do
    table.insert(ids, cit.citationId)
  end
  return "<xref ref=\"" .. table.concat(ids, ",") ..
    "\">" .. s .. "</xref>"
end

function Plain(s)
  return s
end

function Para(s)
  -- here and below: tabs and tabsp(lus) are strings that add enough tab characters to make the output indented nicely.  Since "indents" changes each time these functions are called, these local variables need to be redefined each time.
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
  return tabs.."<p>\n" .. tabsp .. s .. "\n".. tabs.."</p>"
end


function BlockQuote(s)
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
  return tabs.."<blockquote>\n" ..tabsp.. s .. "\n"..tabs.."</blockquote>"
end

-- No <hrule> in PreTeXt.  Leave comment to be searched for.
function HorizontalRule()
--  return "<hr/>"
  return "<!-- Horizontal Rule Not Implimented -->"
end

-- Not sure what this does, so leaving as divs for now, until I see it show up.
function LineBlock(ls)
  return '<div style="white-space: pre-line;">' .. table.concat(ls, '\n') ..
         '</div>'
end

function CodeBlock(s, attr)
  local tabs = string.rep("\t", indents)
  -- -- If code block has class 'dot', pipe the contents through dot
  -- -- and base64, and include the base64-encoded png as a data: URL.
  -- if attr.class and string.match(' ' .. attr.class .. ' ',' dot ') then
  --   local img = pipe("base64", {}, pipe("dot", {"-T" .. image_format}, s))
  --   return '<img src="data:' .. image_mime_type .. ';base64,' .. img .. '"/>'
  -- -- otherwise treat as code (one could pipe through a highlighter)
  -- else
    return tabs.."<pre>" .. escape(s) ..
           "</pre>"
  -- end
end

function BulletList(items)
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, tabsp.."<li>\n"..tabsp .. item .. "\n"..tabsp.."</li>\n")
  end
  return tabs.."<p><ul>\n" .. table.concat(buffer, "\n") .. "\n"..tabs.."</ul></p>"
end

function OrderedList(items)
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, tabsp.."<li>\n" .. tabsp  .. item .. "\n".. tabsp.."</li>\n")
  end
  return tabs.."<p><ol>\n"..table.concat(buffer, "\n").."\n"..tabs.."</ol></p>"
end

function DefinitionList(items)
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
  local tabspp = string.rep("\t", indents+2)
  local buffer = {}
  for _,item in pairs(items) do
    local k, v = next(item)
    table.insert(buffer, tabsp.."<dt>" .. k .. "</dt>\n"..tabspp.."<dd>" ..
                   table.concat(v, "</dd>\n<dd>") .. "</dd>")
  end
  return tabs.."<dl>\n" .. table.concat(buffer, "\n") .. "\n"..tabs.."</dl>"
end

-- PreTeXt does not have anything like this, but leaving it in to avoid errors.  Author can search and address case-by-case.
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
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
   return tabs..'<figure>\n\t<image source="' .. escape(src,true) ..
      '"/>\n' ..
      tabsp..'<caption>' .. caption .. '</caption>\n</figure>'
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local tabs = string.rep("\t", indents)
  local tabsp = string.rep("\t", indents+1)
  local tabspp = string.rep("\t", indents+2)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add(tabs.."<table>")
  -- if caption ~= "" then -- tabules need captions always
    add(tabsp.."<title>" .. caption .. "</title>")
  -- end
  if widths and widths[1] ~= 0 then
    for _, w in pairs(widths) do
      add('<col width="' .. string.format("%.0f%%", w * 100) .. '" />')
    end
  end
  add(tabsp..'<tabular>')
  local header_row = {}
  local empty_header = true
  for i, h in pairs(headers) do
    local align = html_align(aligns[i])
    table.insert(header_row, tabspp..'<cell halign="' .. align .. '">' .. h .. '</cell>')
    empty_header = empty_header and h == ""
  end
  if empty_header then
    head = ""
  else
    add(tabsp..'<row header="yes">')
    for _,h in pairs(header_row) do
      add(h)
    end
    add(tabsp..'</row>')
  end
  local class = "even"
  for _, row in pairs(rows) do
    class = (class == "even" and "odd") or "even"
    add(tabsp..'<row class="' .. class .. '">')
    for i,c in pairs(row) do
      add(tabspp..'<cell halign="' .. html_align(aligns[i]) .. '">' .. c .. '</cell>')
    end
    add(tabsp..'</row>')
  end
  add(tabsp..'</tabular>\n'..tabs..'</table>')
  return table.concat(buffer,'\n')
end

function RawBlock(format, str)
  return "<cd>\n" .. str .. "\n</cd>"
end

-- We use "sectionBuffer" to keep track of open division names, and close them when headers of not-higher levels are reached.  
-- Note this puts the close division tags after <divs>, if those were implimented.
-- lev is an integer, the header level.
function Header(lev, s, attr)
  -- buffer holds closing tags.
  local buffer = ""
  -- if the current level is less than the current number of nestings, close it up.
  while lev <= #sectionBuffer do
    buffer = buffer .. string.rep("\t",#sectionBuffer) .. "</".. sectionBuffer[1]..">\n"
    table.remove(sectionBuffer,1)
  end
  -- add the current division to the stack.
  table.insert(sectionBuffer,1,sectionNames[lev])
  -- Find numbers of tabs:
  indents = #sectionBuffer + 1
  local tabs = string.rep("\t", indents-1)
  local tabsp = string.rep("\t", indents)
  -- return closing division tags, starting division tag and title:
  return buffer .. "\n" .. tabs .. "<"..sectionNames[lev]..attributes(attr)..">\n" .. tabsp.."<title>"..s.."</title>"
end

-- Divs only seem to show up with specific markdown (or maybe converting from HTML).  The issue is that opening div's show up before new headers, so the close division tags and open div tags are in the wrong order.  Eventually, this could be switched in post processing (Doc function).
function Div(s, attr)
  -- return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
  return '<!-- div attr='..attributes(attr).. '-->\n'..s..'<!--</div attr='.. attributes(attr)..'>-->'
end


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

