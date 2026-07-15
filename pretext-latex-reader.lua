-- A custom pandoc reader for LaTeX documents headed to the pretext.lua
-- writer.  Pair it with pretext.lua like so:
--
--   pandoc -f pretext-latex-reader.lua -t pretext.lua paper.tex -o paper.ptx
--
-- Why this exists: pandoc's LaTeX reader only gives an amsthm-style
-- environment full theorem treatment (numbering context, bracketed-name
-- capture, and attaching \label as the block's own identifier) when the
-- environment was declared with \newtheorem somewhere pandoc can see it.
-- Many real documents rely on a document class or separate style file for
-- that declaration, so pandoc never sees it and drops the bracketed name
-- entirely (nothing in the AST records it -- pretext.lua cannot recover
-- what pandoc never captured) and turns the label into an orphaned span.
--
-- This reader pre-declares \newtheorem for every environment name in
-- pretext-environments.lua before handing the text to pandoc's own LaTeX
-- reader, so that treatment applies whether or not the source document
-- declares them itself.  A real \newtheorem later in the same document
-- simply overrides the pre-declared default, so this never fights a
-- document that already declares its own environments (including
-- differently-numbered ones, e.g. "\newtheorem{theorem}{Theorem}[section]").
--
-- Also enables the `raw_tex` extension, so LaTeX pandoc doesn't otherwise
-- understand (e.g. tikzpicture) survives as raw blocks for pretext.lua to
-- turn into <latex-image>, instead of being silently dropped.

PANDOC_VERSION:must_be_at_least '3.0'

local script_dir = PANDOC_SCRIPT_FILE:match('(.*[/\\])') or './'
local environments = dofile(script_dir .. 'pretext-environments.lua')

-- "proof" comes from amsthm itself, not a \newtheorem declaration, and
-- pandoc already recognizes \begin{proof} (with its QED tombstone) with no
-- help; pre-declaring it as a generic theorem changes nothing but also
-- buys nothing, so it's left out.
local skip = { proof = true }

local function titlecase (s)
  return s:sub(1, 1):upper() .. s:sub(2)
end

local preamble = {}
for name in pairs(environments) do
  if not skip[name] then
    table.insert(preamble, '\\newtheorem{' .. name .. '}{' .. titlecase(name) .. '}\n')
  end
end
preamble = table.concat(preamble)

function Reader (input, opts)
  local text = {}
  for _, source in ipairs(input) do
    table.insert(text, source.text)
  end
  return pandoc.read(preamble .. table.concat(text, '\n'), 'latex+raw_tex', opts)
end
