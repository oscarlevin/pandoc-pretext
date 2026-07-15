-- pretext.lua — a custom pandoc writer that produces PreTeXt (https://pretextbook.org)
--
-- Requires pandoc 3.0 or later.
--
-- Invoke with:  pandoc input.md -t pretext.lua -o output.ptx
-- Add -s/--standalone to wrap the output in a complete <pretext><article> document;
-- without it you get a fragment suitable for pasting into a larger PreTeXt project.
--
-- This is a "new style" custom writer: pandoc hands us the document AST and
-- we render it with the pandoc.layout document-layout DSL.
-- See https://pandoc.org/custom-writers.html

PANDOC_VERSION:must_be_at_least '3.0'

local layout = pandoc.layout
local literal, empty, cr, blankline, concat, nest, space, flush =
  layout.literal, layout.empty, layout.cr, layout.blankline,
  layout.concat, layout.nest, layout.space, layout.flush

local stringify = pandoc.utils.stringify

Writer = pandoc.scaffolding.Writer
local inlines = Writer.Inlines
local blocks = Writer.Blocks

------------------------------------------------------------------------------
-- Configuration: edit these mappings to change how elements are translated. --
------------------------------------------------------------------------------

-- Number of spaces each level of XML structure is indented.
local INDENT = 2

-- PreTeXt division corresponding to each header level.  Levels deeper than
-- the list fall back to <paragraphs>, which cannot be subdivided further.
local division_names = { 'section', 'subsection', 'subsubsection' }

-- Element used for pandoc Strong (bold) text.  PreTeXt renders both <term>
-- and <alert> in bold; <term> is semantically a technical term being defined,
-- <alert> is a plain "look at me".  Historically this writer assumed bold
-- text marks terms being defined.
local strong_element = 'term'

-- Element used for SmallCaps text (PreTeXt has no small-caps element).
local smallcaps_element = 'alert'

-- Divs whose class appears here become the corresponding PreTeXt block.
-- Fenced divs in markdown (::: {.theorem #thm-x title="Name"}) and amsthm
-- environments read from LaTeX both arrive as such Divs.  Extend this table
-- with whatever \newtheorem shorthands your documents use.
local environments = {
  -- theorem-like
  theorem = 'theorem', lemma = 'lemma', corollary = 'corollary',
  proposition = 'proposition', claim = 'claim', fact = 'fact',
  identity = 'identity', algorithm = 'algorithm',
  -- axiom-like
  axiom = 'axiom', principle = 'principle', conjecture = 'conjecture',
  heuristic = 'heuristic', hypothesis = 'hypothesis', assumption = 'assumption',
  -- definition-like
  definition = 'definition',
  -- remark-like
  remark = 'remark', convention = 'convention', note = 'note',
  observation = 'observation', warning = 'warning', insight = 'insight',
  -- computation-like
  computation = 'computation', technology = 'technology',
  -- example-like
  example = 'example', question = 'question', problem = 'problem',
  -- project-like and friends
  exercise = 'exercise', activity = 'activity', exploration = 'exploration',
  project = 'project', investigation = 'investigation',
  proof = 'proof', aside = 'aside',
  -- common LaTeX \newtheorem shorthands
  thm = 'theorem', lem = 'lemma', cor = 'corollary', prop = 'proposition',
  defn = 'definition', dfn = 'definition', rem = 'remark',
  exa = 'example', exmp = 'example', obs = 'observation',
  conj = 'conjecture', alg = 'algorithm', hyp = 'hypothesis',
}

-- PreTeXt blocks whose content must be wrapped in <statement>.
local needs_statement = { definition = true }

------------------------------------------------------------------------------
-- XML helpers                                                               --
------------------------------------------------------------------------------

local escapes = { ['<'] = '&lt;', ['>'] = '&gt;', ['&'] = '&amp;' }
local attr_escapes = { ['<'] = '&lt;', ['>'] = '&gt;', ['&'] = '&amp;', ['"'] = '&quot;' }

local function escape (s)
  return (s:gsub('[<>&]', escapes))
end

local function escape_attr (s)
  return (s:gsub('[<>&"]', attr_escapes))
end

-- Pandoc's readers bake "smart typography" (curly quotes, dashes, ellipses,
-- non-breaking spaces from `\ ` etc.) directly into Str text as literal
-- UTF-8 characters rather than separate AST nodes.  Left alone these show
-- up as raw non-ASCII bytes in the output.  PreTeXt has its own semantic
-- elements for the unambiguous ones (nbsp/mdash/ndash/ellipsis); none of
-- their UTF-8 byte sequences contain '<', '>', or '&', so this can safely
-- run after escape().  Quote-mark elements (<lq/>/<rq/>/<lsq/>/<rsq/>) are
-- documented as "a last resort" for stray marks that cross XML boundaries,
-- not a general substitute for typed apostrophes/quotes, so those fold
-- back down to plain ASCII instead.
local typographic_entities = {
  ['\194\160']     = '<nbsp/>',      -- U+00A0 NO-BREAK SPACE
  ['\226\128\147'] = '<ndash/>',     -- U+2013 EN DASH
  ['\226\128\148'] = '<mdash/>',     -- U+2014 EM DASH
  ['\226\128\166'] = '<ellipsis/>',  -- U+2026 HORIZONTAL ELLIPSIS
  ['\226\128\152'] = "'",            -- U+2018 LEFT SINGLE QUOTATION MARK
  ['\226\128\153'] = "'",            -- U+2019 RIGHT SINGLE QUOTATION MARK
  ['\226\128\156'] = '<q>',            -- U+201C LEFT DOUBLE QUOTATION MARK
  ['\226\128\157'] = '</q>',            -- U+201D RIGHT DOUBLE QUOTATION MARK
}

-- Same characters, folded to plain ASCII throughout.  Used in text-only
-- contexts (e.g. <shortdescription>) where no child elements are allowed.
local typographic_ascii = {
  ['\194\160']     = ' ',
  ['\226\128\147'] = '--',
  ['\226\128\148'] = '---',
  ['\226\128\166'] = '...',
  ['\226\128\152'] = "'",
  ['\226\128\153'] = "'",
  ['\226\128\156'] = '"',
  ['\226\128\157'] = '"',
}

local function apply_typography (s, table_)
  for pattern, repl in pairs(table_) do
    s = s:gsub(pattern, repl)
  end
  return s
end

-- attrs is a list of {key, value} pairs; empty/nil values are skipped.
local function attr_string (attrs)
  local parts = {}
  for _, kv in ipairs(attrs or {}) do
    local k, v = kv[1], kv[2]
    if v and v ~= '' then
      table.insert(parts, string.format(' %s="%s"', k, escape_attr(tostring(v))))
    end
  end
  return table.concat(parts)
end

-- <name attrs>content</name> with the tags hugging the content (inline).
local function inline_el (name, content, attrs)
  return concat{ '<' .. name .. attr_string(attrs) .. '>', content, '</' .. name .. '>' }
end

-- <name attrs/> (no content)
local function empty_el (name, attrs)
  return '<' .. name .. attr_string(attrs) .. '/>'
end

-- Tags on their own lines with the content nested between them.
local function block_el (name, content, attrs)
  return concat{
    '<' .. name .. attr_string(attrs) .. '>', cr,
    nest(content, INDENT), cr,
    '</' .. name .. '>'
  }
end

-- {{'xml:id', id}} when the element has an identifier, otherwise {}.
local function id_attr (el)
  local attrs = {}
  if el.identifier and el.identifier ~= '' then
    table.insert(attrs, {'xml:id', el.identifier})
  end
  return attrs
end

-- Render blocks in a context where PreTeXt requires structured content:
-- loose Plain blocks are promoted to real paragraphs.
local function structured_blocks (blks)
  local out = pandoc.Blocks{}
  for _, b in ipairs(blks) do
    if b.t == 'Plain' then
      out:insert(pandoc.Para(b.content))
    else
      out:insert(b)
    end
  end
  return blocks(out, blankline)
end

-- PreTeXt only allows lists inside a <p>, so block-level lists get wrapped.
local function in_p (doc)
  return block_el('p', doc)
end

-- Reduce a Caption (or any Blocks) to inline content for <title>/<caption>.
local function caption_inlines (caption)
  local blks = caption.long
  if blks and #blks > 0 then
    if #blks == 1 and (blks[1].t == 'Para' or blks[1].t == 'Plain') then
      return inlines(blks[1].content)
    end
    return inlines(pandoc.utils.blocks_to_inlines(blks))
  end
  if caption.short and #caption.short > 0 then
    return inlines(caption.short)
  end
  return nil
end

------------------------------------------------------------------------------
-- Inline elements                                                           --
------------------------------------------------------------------------------

Writer.Inline.Str = function (el)
  return apply_typography(escape(el.text), typographic_entities)
end

Writer.Inline.Space = function () return space end
Writer.Inline.SoftBreak = function () return space end

-- PreTeXt has no forced line break; leave a marker for manual fix-up.
Writer.Inline.LineBreak = function ()
  return '<!-- linebreak -->'
end

Writer.Inline.Emph = function (el)
  return inline_el('em', inlines(el.content))
end

Writer.Inline.Underline = function (el)
  -- no underline in PreTeXt; emphasis is the nearest visual match
  return inline_el('em', inlines(el.content))
end

Writer.Inline.Strong = function (el)
  return inline_el(strong_element, inlines(el.content))
end

Writer.Inline.SmallCaps = function (el)
  return inline_el(smallcaps_element, inlines(el.content))
end

Writer.Inline.Strikeout = function (el)
  return inline_el('delete', inlines(el.content))
end

-- PreTeXt has no sub/superscript elements; short plain text becomes math.
local function script (el, op, marker)
  local txt = stringify(el.content)
  if txt:match('^[%w%+%-%./, ]*$') then
    local mtxt = txt:match('^[%d%+%-%./,]+$') and txt or ('\\text{' .. txt .. '}')
    return inline_el('m', escape('{}' .. op .. '{' .. mtxt .. '}'))
  end
  return concat{ '<!-- ' .. marker .. ' -->', inlines(el.content) }
end

Writer.Inline.Superscript = function (el) return script(el, '^', 'superscript') end
Writer.Inline.Subscript = function (el) return script(el, '_', 'subscript') end

Writer.Inline.Code = function (el)
  -- <c> is text-only; also, pandoc's reader inserts U+00A0 after a command
  -- name before a flag (e.g. "pandoc --foo") to avoid an ugly line break,
  -- which would silently break a copy-pasted command if left as a raw NBSP
  local text = apply_typography(escape(el.text), typographic_ascii)
  return inline_el('c', text)
end

Writer.Inline.Quoted = function (el)
  return inline_el(el.quotetype == 'SingleQuote' and 'sq' or 'q', inlines(el.content))
end

-- Display math: unwrap a wrapping align/gather/... environment and emit
-- <md> with one <mrow> per line; otherwise a single <md> with no <mrow>.
local splittable_envs = {
  align = true, aligned = true, gather = true, gathered = true,
  split = true, alignat = true, alignedat = true, eqnarray = true,
  multline = true, flalign = true,
}

local function display_math (text)
  local body = text:match('^%s*(.-)%s*$')
  local env, inner = body:match('^\\begin{(%a+%*?)}(.*)\\end{%1}$')
  if env then
    local base = env:gsub('%*$', '')
    if splittable_envs[base] then
      inner = inner:match('^%s*(.-)%s*$')
      if base == 'alignat' or base == 'alignedat' then
        inner = inner:gsub('^{%s*%d+%s*}%s*', '')
      end
      -- refuse to split if another environment is nested inside
      if not inner:find('\\begin{', 1, true) then
        local rows = {}
        for row in (inner .. '\\\\'):gmatch('(.-)\\\\') do
          row = row:gsub('^%[[^%]]*%]', '')      -- drop \\[2ex] spacing args
          row = row:match('^%s*(.-)%s*$')
          if row ~= '' then table.insert(rows, row) end
        end
        if #rows > 1 then
          local mrows = {}
          for _, r in ipairs(rows) do
            table.insert(mrows, inline_el('mrow', escape(r)))
          end
          return concat{ '<md>', cr, nest(concat(mrows, cr), INDENT), cr, '</md>' }
        elseif #rows == 1 then
          return inline_el('md', escape(rows[1]))
        end
      end
    end
  end
  return inline_el('md', escape(body))
end

Writer.Inline.Math = function (el)
  if el.mathtype == 'InlineMath' then
    return inline_el('m', escape(el.text))
  end
  return display_math(el.text)
end

Writer.Inline.Link = function (el)
  local target = el.target
  if target:sub(1, 1) == '#' then
    -- internal link: cross-reference; PreTeXt generates the link text
    return empty_el('xref', {{'ref', target:sub(2)}})
  end
  local text = stringify(el.content)
  if #el.content == 0 or text == target or text == target:gsub('^mailto:', '') then
    return empty_el('url', {{'href', target}})
  end
  return inline_el('url', inlines(el.content), {{'href', target}})
end

local function image_el (img)
  local attrs = {{'source', img.src}}
  local width = img.attributes and img.attributes.width
  if width and width:match('%%$') then
    table.insert(attrs, {'width', width})
  end
  local alt = stringify(img.caption)
  if alt ~= '' then
    -- <shortdescription> is text-only (no child elements permitted)
    local text = apply_typography(escape(alt), typographic_ascii)
    return block_el('image', inline_el('shortdescription', text), attrs)
  end
  return empty_el('image', attrs)
end

Writer.Inline.Image = function (el)
  return image_el(el)
end

Writer.Inline.Note = function (el)
  -- footnotes hold inline-ish content in PreTeXt; flatten multi-block notes
  if #el.content == 1 and (el.content[1].t == 'Para' or el.content[1].t == 'Plain') then
    return inline_el('fn', inlines(el.content[1].content))
  end
  local ins = pandoc.utils.blocks_to_inlines(el.content, pandoc.Inlines{pandoc.Space()})
  return inline_el('fn', inlines(ins))
end

Writer.Inline.Span = function (el)
  return inlines(el.content)
end

Writer.Inline.Cite = function (el)
  -- point at bibliography entries; create <biblio> items with matching xml:ids
  local refs = {}
  for _, citation in ipairs(el.citations) do
    table.insert(refs, empty_el('xref', {{'ref', citation.id}}))
  end
  return concat(refs, space)
end

Writer.Inline.RawInline = function (el)
  if el.format == 'pretext' or el.format == 'xml' then
    return literal(el.text)
  end
  return empty
end

------------------------------------------------------------------------------
-- Block elements                                                            --
------------------------------------------------------------------------------

Writer.Block.Plain = function (el)
  return inlines(el.content)
end

Writer.Block.Para = function (el)
  -- PreTeXt has no inline images: a paragraph holding only images
  -- becomes free-standing block-level <image>s
  local images = {}
  for _, item in ipairs(el.content) do
    if item.t == 'Image' then
      table.insert(images, item)
    elseif item.t ~= 'Space' and item.t ~= 'SoftBreak' then
      images = nil
      break
    end
  end
  if images and #images > 0 then
    local docs = {}
    for _, img in ipairs(images) do table.insert(docs, image_el(img)) end
    return concat(docs, blankline)
  end
  return block_el('p', inlines(el.content))
end

-- Headers are normally consumed by the division machinery below; one that
-- survives (e.g. inside a block quote) is marked for manual attention.
Writer.Block.Header = function (el)
  local content = pandoc.Inlines(el.content):walk{
    Image = function () return {} end
  }
  return concat{
    '<!-- header (level ' .. el.level .. ') with no PreTeXt division -->', cr,
    block_el('p', inline_el('alert', inlines(content)), id_attr(el))
  }
end

Writer.Block.BlockQuote = function (el)
  return block_el('blockquote', structured_blocks(el.content))
end

Writer.Block.HorizontalRule = function ()
  return '<!-- horizontal rule omitted (no PreTeXt equivalent) -->'
end

Writer.Block.LineBlock = function (el)
  local lines = {}
  for _, line in ipairs(el.content) do
    table.insert(lines, inlines(line))
  end
  return block_el('p', concat(lines, concat{'<!-- linebreak -->', cr}))
end

Writer.Block.CodeBlock = function (el)
  local lang = el.classes[1]
  -- flush: code must not inherit the surrounding XML indentation
  local code = flush(literal(apply_typography(escape(el.text), typographic_ascii)))
  if lang then
    local attrs = id_attr(el)
    table.insert(attrs, {'language', lang})
    return concat{
      '<program' .. attr_string(attrs) .. '>', cr,
      '<code>', cr, code, cr, '</code>', cr,
      '</program>'
    }
  end
  return concat{ '<pre>', cr, code, cr, '</pre>' }
end

Writer.Block.RawBlock = function (el)
  if el.format == 'pretext' or el.format == 'xml' then
    return literal(el.text)
  end
  if (el.format == 'latex' or el.format == 'tex')
      and el.text:find('\\begin{tikzpicture}', 1, true) then
    return block_el('image', concat{
      '<latex-image>', cr, flush(literal(escape(el.text))), cr, '</latex-image>'
    })
  end
  return '<!-- raw ' .. el.format .. ' block omitted -->'
end

-- A list item is either a single line of text or a sequence of blocks.
local function list_item (item)
  if #item == 0 then
    return '<li></li>'
  elseif #item == 1 and item[1].t == 'Plain' then
    return inline_el('li', inlines(item[1].content))
  end
  return block_el('li', structured_blocks(item))
end

Writer.Block.BulletList = function (el)
  local items = {}
  for _, item in ipairs(el.content) do
    table.insert(items, list_item(item))
  end
  return in_p(block_el('ul', concat(items, cr)))
end

-- Translate pandoc list numbering to a PreTeXt marker string like "(a)".
local marker_letters = {
  Decimal = '1', LowerAlpha = 'a', UpperAlpha = 'A',
  LowerRoman = 'i', UpperRoman = 'I',
}

local function ol_marker (el)
  local base = marker_letters[el.style]
  if not base then return nil end
  if el.delimiter == 'OneParen' then return base .. ')' end
  if el.delimiter == 'TwoParens' then return '(' .. base .. ')' end
  return base .. '.'
end

Writer.Block.OrderedList = function (el)
  local items = {}
  for _, item in ipairs(el.content) do
    table.insert(items, list_item(item))
  end
  local attrs = {}
  local marker = ol_marker(el)
  if marker and marker ~= '1.' then
    table.insert(attrs, {'marker', marker})
  end
  return in_p(block_el('ol', concat(items, cr), attrs))
end

Writer.Block.DefinitionList = function (el)
  local items = {}
  for _, item in ipairs(el.content) do
    local term, definitions = item[1], item[2]
    local content = pandoc.Blocks{}
    for _, def in ipairs(definitions) do
      content:extend(def)
    end
    table.insert(items, block_el('li', concat{
      inline_el('title', inlines(term)), cr,
      structured_blocks(content)
    }))
  end
  return in_p(block_el('dl', concat(items, cr)))
end

Writer.Block.Figure = function (el)
  -- a figure holding just an image becomes <figure><caption/><image/></figure>
  local body
  if #el.content == 1 and (el.content[1].t == 'Plain' or el.content[1].t == 'Para')
      and #el.content[1].content == 1 and el.content[1].content[1].t == 'Image' then
    body = image_el(el.content[1].content[1])
  else
    body = structured_blocks(el.content)
  end
  local caption = caption_inlines(el.caption)
  if caption then
    return block_el('figure',
      concat{ inline_el('caption', caption), cr, body },
      id_attr(el))
  end
  return body
end

------------------------------------------------------------------------------
-- Tables                                                                    --
------------------------------------------------------------------------------

local halign_of = {
  AlignLeft = 'left', AlignRight = 'right', AlignCenter = 'center',
}

local function table_cell (cell)
  local attrs = {}
  if halign_of[cell.alignment] then
    table.insert(attrs, {'halign', halign_of[cell.alignment]})
  end
  if cell.col_span and cell.col_span > 1 then
    table.insert(attrs, {'colspan', tostring(cell.col_span)})
  end
  local content = cell.contents
  if #content == 0 then
    return '<cell' .. attr_string(attrs) .. '></cell>'
  elseif #content == 1 and (content[1].t == 'Plain' or content[1].t == 'Para') then
    return inline_el('cell', inlines(content[1].content), attrs)
  end
  return block_el('cell', structured_blocks(content), attrs)
end

local function table_row (row, header)
  local attrs = {}
  if header then table.insert(attrs, {'header', 'yes'}) end
  local cells = {}
  for _, cell in ipairs(row.cells) do
    table.insert(cells, table_cell(cell))
  end
  return block_el('row', concat(cells, cr), attrs)
end

Writer.Block.Table = function (el)
  local parts = {}
  -- column specifications: only emitted when they carry information
  local cols, significant = {}, false
  for _, colspec in ipairs(el.colspecs) do
    local attrs = {}
    if halign_of[colspec[1]] then
      table.insert(attrs, {'halign', halign_of[colspec[1]]})
      significant = true
    end
    if colspec[2] then
      table.insert(attrs, {'width', string.format('%.0f%%', colspec[2] * 100)})
      significant = true
    end
    table.insert(cols, empty_el('col', attrs))
  end
  if significant then
    for _, col in ipairs(cols) do table.insert(parts, col) end
  end
  for _, row in ipairs(el.head.rows) do
    table.insert(parts, table_row(row, true))
  end
  for _, body in ipairs(el.bodies) do
    for _, row in ipairs(body.head) do table.insert(parts, table_row(row, true)) end
    for _, row in ipairs(body.body) do table.insert(parts, table_row(row, false)) end
  end
  for _, row in ipairs(el.foot.rows) do
    table.insert(parts, table_row(row, false))
  end
  local tabular = block_el('tabular', concat(parts, cr))
  local title = caption_inlines(el.caption)
  if title then
    return block_el('table',
      concat{ inline_el('title', title), cr, tabular },
      id_attr(el))
  end
  return tabular
end

------------------------------------------------------------------------------
-- Divisions and PreTeXt blocks (theorem, definition, ...)                   --
------------------------------------------------------------------------------

-- Strip the "Theorem 1 (Name)." / "Proof." run-in header that pandoc's LaTeX
-- reader bakes into the first paragraph of amsthm environments.  Returns the
-- extracted name (Inlines or nil); modifies blks in place.
local function strip_run_in_header (blks)
  if #blks == 0 then return nil end
  local first = blks[1]
  if first.t ~= 'Para' and first.t ~= 'Plain' then return nil end
  local ins = first.content
  if #ins == 0 then return nil end

  local i, stripped = 1, false
  if ins[1].t == 'Strong' and stringify(ins[1]):match('^%u[%a%s]*%s[%d%.]+$') then
    i, stripped = 2, true                            -- "Theorem 1", "Definition 2.3"
  elseif ins[1].t == 'Strong' and stringify(ins[1]):match('^%u%a+%.?$') then
    i, stripped = 2, true                            -- unnumbered: "Theorem."
  elseif ins[1].t == 'Emph' and stringify(ins[1]):match('^Proof%.?$') then
    i, stripped = 2, true
  end
  if not stripped then return nil end

  while ins[i] and ins[i].t == 'Space' do i = i + 1 end

  -- optional "(Name)." parenthetical becomes the block title
  local name = nil
  if ins[i] and ins[i].t == 'Str' and ins[i].text:sub(1, 1) == '(' then
    local collected, j, closed = {}, i, false
    while ins[j] do
      table.insert(collected, ins[j]:clone())
      if ins[j].t == 'Str' and ins[j].text:match('%)%.?,?$') then
        closed = true
        break
      end
      j = j + 1
    end
    if closed then
      collected[1].text = collected[1].text:gsub('^%(', '')
      collected[#collected].text = collected[#collected].text:gsub('%)%.?,?$', '')
      name = pandoc.Inlines(collected)
      i = j + 1
      while ins[i] and ins[i].t == 'Space' do i = i + 1 end
    end
  end

  local rest = pandoc.Inlines{}
  for k = i, #ins do rest:insert(ins[k]) end
  -- amsthm italicizes theorem statements; unwrap a lone Emph
  if #rest == 1 and rest[1].t == 'Emph' then
    rest = rest[1].content
  end
  if #rest == 0 then
    blks:remove(1)
  else
    blks[1] = first.t == 'Para' and pandoc.Para(rest) or pandoc.Plain(rest)
  end
  return name
end

-- Remove the trailing QED tombstone pandoc places at the end of proofs.
local function strip_qed (blks)
  local last = blks[#blks]
  if not last or (last.t ~= 'Para' and last.t ~= 'Plain') then return end
  local ins = last.content
  local final = ins[#ins]
  if final and final.t == 'Str' then
    local cleaned = final.text:gsub('\194\160', ''):gsub('◻', ''):gsub('□', ''):gsub('∎', '')
    if cleaned == '' then
      ins:remove(#ins)
      while #ins > 0 and ins[#ins].t == 'Space' do ins:remove(#ins) end
      if #ins == 0 then blks:remove(#blks) end
    end
  end
end

local function render_environment (name, div)
  local content = pandoc.Blocks{}
  for _, b in ipairs(div.content) do content:insert(b) end

  local extracted = strip_run_in_header(content)
  if name == 'proof' then strip_qed(content) end

  local title = div.attributes.title and escape(div.attributes.title)
    or (extracted and inlines(extracted))

  local inner = structured_blocks(content)
  if needs_statement[name] then
    inner = block_el('statement', inner)
  end
  if title then
    inner = concat{ inline_el('title', title), blankline, inner }
  end
  return block_el(name, inner, id_attr(div))
end

-- Is this a Div created by pandoc.structure.make_sections?
local function is_section_div (b)
  return b.t == 'Div' and b.classes:includes('section')
    and b.content[1] and b.content[1].t == 'Header'
end

-- Recursively dissolve section Divs into their contents, used where PreTeXt
-- forbids (further) subdivision.  The orphaned Headers render as marked
-- paragraphs via Writer.Block.Header; the Div's xml:id moves to the Header
-- so cross-references to it keep working.
local function unwrap_sections (blks)
  local out = pandoc.Blocks{}
  for _, b in ipairs(blks) do
    if is_section_div(b) then
      local inner = pandoc.Blocks{}
      for _, cb in ipairs(b.content) do inner:insert(cb) end
      if b.identifier ~= '' and inner[1].identifier == '' then
        inner[1] = pandoc.Header(inner[1].level, inner[1].content,
                                 pandoc.Attr(b.identifier))
      end
      out:extend(unwrap_sections(inner))
    else
      out:insert(b)
    end
  end
  return out
end

local render_division -- forward declaration; mutually recursive

-- Render the children of a division (or of the whole article, depth 0).
-- PreTeXt allows either plain content or subdivisions, so content that
-- precedes/follows subdivisions moves into <introduction>/<conclusion>.
-- Returns a list of layout Docs.
local function division_pieces (children, depth)
  local body, subdivs, trailing = pandoc.Blocks{}, {}, pandoc.Blocks{}
  for _, b in ipairs(children) do
    if is_section_div(b) then
      table.insert(subdivs, b)
    elseif #subdivs == 0 then
      body:insert(b)
    else
      trailing:insert(b)
    end
  end

  local pieces = {}
  if #subdivs == 0 then
    if #body > 0 then
      table.insert(pieces, structured_blocks(body))
    end
  else
    if #body > 0 then
      table.insert(pieces, block_el('introduction', structured_blocks(body)))
    end
    for _, sd in ipairs(subdivs) do
      table.insert(pieces, render_division(sd, depth + 1))
    end
    if #trailing > 0 then
      table.insert(pieces, block_el('conclusion', structured_blocks(trailing)))
    end
  end
  return pieces
end

-- Render a section Div as a PreTeXt division.  The division name comes
-- from the nesting depth, not the original header level, so documents
-- that skip levels still produce a valid strict hierarchy.
render_division = function (div, depth)
  local header = div.content[1]
  local name = division_names[depth] or 'paragraphs'

  local children = pandoc.Blocks{}
  for i = 2, #div.content do children:insert(div.content[i]) end

  -- <title> cannot hold images or footnotes; move that content into the body
  local title_ins = pandoc.Inlines{}
  local moved = pandoc.Blocks{}
  for _, item in ipairs(header.content) do
    if item.t == 'Image' then
      moved:insert(pandoc.Plain{item})
    elseif item.t == 'Note' then
      moved:extend(item.content)
    else
      title_ins:insert(item)
    end
  end
  for i = #moved, 1, -1 do children:insert(1, moved[i]) end
  while #title_ins > 0 and title_ins[#title_ins].t == 'Space' do
    title_ins:remove(#title_ins)
  end
  while #title_ins > 0 and title_ins[1].t == 'Space' do
    title_ins:remove(1)
  end

  local pieces
  if name == 'paragraphs' then
    local flat = unwrap_sections(children)
    pieces = #flat > 0 and { structured_blocks(flat) } or {}
  else
    pieces = division_pieces(children, depth)
  end
  table.insert(pieces, 1, inline_el('title', inlines(title_ins)))
  if #pieces == 1 then
    table.insert(pieces, concat{ '<!-- empty division -->', cr, '<p/>' })
  end
  return block_el(name, concat(pieces, blankline), id_attr(div))
end

Writer.Block.Div = function (div)
  if is_section_div(div) then
    -- Divisions are rendered through Writer.Pandoc's recursion; a section
    -- Div reaching this point sits in a non-division context (inside a
    -- plain Div, list, blockquote, ...) where PreTeXt allows no division,
    -- so it is flattened instead.
    return structured_blocks(unwrap_sections(pandoc.Blocks{div}))
  end
  for _, class in ipairs(div.classes) do
    if environments[class] then
      return render_environment(environments[class], div)
    end
  end
  -- unknown div: keep the content, note the wrapper for manual attention
  local label = table.concat(div.classes, ' ')
  if div.identifier ~= '' then label = '#' .. div.identifier .. ' ' .. label end
  return concat{
    '<!-- div ' .. escape(label) .. ' -->', blankline,
    structured_blocks(div.content), blankline,
    '<!-- end div ' .. escape(label) .. ' -->'
  }
end

------------------------------------------------------------------------------
-- Document                                                                  --
------------------------------------------------------------------------------

Writer.Pandoc = function (doc)
  local sectioned = pandoc.structure.make_sections(doc.blocks)
  -- the article body follows the same content model as a division:
  -- loose blocks before the first section move into <introduction>
  local pieces = division_pieces(pandoc.Blocks(sectioned), 0)
  return concat(pieces, blankline)
end

-- Default template, used with -s/--standalone.
function Template ()
  return [[<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated by pandoc using the pretext.lua custom writer -->
<pretext>
  <article xml:id="pandoc-article">
    <title>$if(title)$$title$$endif$</title>
$body$
  </article>
</pretext>
]]
end
