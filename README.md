# Pandoc to PreTeXt

A custom [Pandoc](https://pandoc.org/) writer that converts anything Pandoc can read (Markdown, LaTeX, MS Word, ...) into [PreTeXt](https://pretextbook.org).

The goal is primarily to streamline the conversion of LaTeX (or even MS Word) files into PreTeXt.  It also makes a reasonable workflow for PreTeXt newcomers: write in Pandoc's markdown, or whatever you are used to, then convert to PreTeXt to include in a book.

The writer uses Pandoc's ["new style" custom writer API](https://pandoc.org/custom-writers.html) and the document-layout engine, so output is properly indented, divisions nest correctly, and the result validates against the PreTeXt RELAX-NG schema for typical documents.

## Requirements

[Pandoc](https://pandoc.org/) **3.0 or later** (the writer checks and will tell you if your version is too old).  Pandoc ships with its own Lua interpreter, so Lua does not need to be installed separately.

## Usage

Download `pretext.lua`, `pretext-environments.lua`, and `pretext-latex-reader.lua` and put them together in a convenient location (all three; `pretext.lua` and `pretext-latex-reader.lua` both load `pretext-environments.lua` from beside themselves).  (Tip: if you place them in the `custom` subdirectory of your pandoc user data directory — see `pandoc --version` for the path — then `pandoc -t pretext.lua` works from any directory.)  To convert `manual.md` into the PreTeXt file `manual.ptx`:

```
pandoc manual.md -t pretext.lua -o manual.ptx
```

By default the output is a *fragment* of PreTeXt — a sequence of sections and paragraphs suitable for pasting into a larger PreTeXt document.  Add `-s`/`--standalone` to wrap the output in a complete `<pretext><article>` document (with `<title>` taken from the document metadata):

```
pandoc manual.md -t pretext.lua -s -o manual.ptx
```

**When converting from LaTeX**, use the companion reader `pretext-latex-reader.lua` instead of `-f latex`:

```
pandoc notes.tex -f pretext-latex-reader.lua -t pretext.lua -s -o notes.ptx
```

It pre-declares `\newtheorem` for every environment name `pretext-environments.lua` knows about, so `\begin{theorem}[Lagrange]\label{thm-x}` gets full treatment — numbering context, the bracketed name captured as `<title>`, and the label attached as `xml:id` — even when your document relies on a document class or style file to declare these environments rather than declaring them itself. (A real `\newtheorem` later in your document overrides the pre-declared default, so this never fights a document that already declares its own.) It also enables the `raw_tex` extension, so LaTeX pandoc doesn't otherwise understand (e.g. `tikzpicture`) survives as raw blocks for `pretext.lua` to turn into `<latex-image>`, instead of being silently dropped — pre-declaring every environment name also means an environment `raw_tex` doesn't recognize is far less likely to be swallowed whole into an inert raw block instead of becoming a proper `<theorem>`/`<definition>`/etc.

## What is supported

* **Divisions.** Headers become properly nested `<section>`, `<subsection>`, `<subsubsection>`, and `<paragraphs>`.  Content that precedes a division's first subdivision is wrapped in `<introduction>` (and trailing content in `<conclusion>`).  Documents that skip header levels still produce a valid strict hierarchy, since division names come from nesting depth.
* **Theorems and friends.** Fenced divs (`::: {.theorem #thm-x title="Main Result"}`) and amsthm environments read from LaTeX become the corresponding PreTeXt blocks: `<theorem>`, `<lemma>`, `<definition>` (with `<statement>`), `<example>`, `<remark>`, `<proof>`, and many more.  The run-in "**Theorem 1 (Name).**" header that Pandoc's LaTeX reader produces is stripped, with the parenthetical name recovered as the block's `<title>`; the QED tombstone at the end of proofs is removed.  `\label`s are recovered as `xml:id` regardless of where Pandoc places them.  See the `environments` table at the top of `pretext.lua` to add your own `\newtheorem` shorthands.

  Use `pretext-latex-reader.lua` (see Usage above) for full title/label recovery regardless of whether your document declares these environments itself.  If you convert with plain `-f latex` instead, declare every environment you use with `\newtheorem` yourself — without one, Pandoc's LaTeX reader has no numbering context for that environment: it silently drops any bracketed name (`\begin{theorem}[Lagrange]` loses "Lagrange" entirely, with nothing left in the document for any tool to recover), though the `\label` is still recovered as `xml:id` either way.
* **Math.** Inline math becomes `<m>`; display math becomes `<md>`, except that a wrapping `align`/`gather`/`aligned`/... environment is unwrapped into `<md>` with one `<mrow>` per line.
* **Tables.** Full support for the Pandoc table model: `<tabular>` with header rows, per-column alignment and widths via `<col>`, and `colspan`.  A captioned table becomes `<table><title>...<tabular>`.
* **Figures and images.** Captioned images become `<figure><caption>...<image>`; alt text is preserved as `<shortdescription>`.  Paragraphs containing only images become block-level `<image>` elements (PreTeXt has no inline images).
* **Code.** Fenced code blocks with a language become `<program language="..."><code>`; plain code blocks become `<pre>`.  Inline code becomes `<c>`.
* **Lists.** `<ul>`, `<ol>` (with `marker` derived from the list style, e.g. `(a)`), and definition lists as PreTeXt `<dl>` with `<li><title>`.  Lists are wrapped in `<p>` as PreTeXt requires.
* **Everything inline.** `<em>`, `<term>` (see below), `<alert>`, `<delete>`, `<q>`/`<sq>`, `<fn>` footnotes, `<url>`, and `<xref>` for internal links.  Sub/superscripts (which PreTeXt lacks) become math when the content is simple text.

Raw `pretext`/`xml` blocks and inlines pass through verbatim, so you can embed literal PreTeXt in a markdown source:

````markdown
```{=pretext}
<sage><input>factor(2026)</input></sage>
```
````

## Conversion choices you may want to adjust

The top of `pretext.lua` has a short configuration section:

* **Bold text becomes `<term>`.**  Both `<term>` and `<alert>` render bold; we assume bold in the source marks terminology.  Set `strong_element = 'alert'` if that assumption is wrong for your documents.
* **The `environments` table**, in `pretext-environments.lua`, maps div classes (and amsthm environment names) to PreTeXt blocks.  Add entries for your own theorem shorthands (`thm`, `lem`, `cor`, ... are included) — both `pretext.lua` and `pretext-latex-reader.lua` pick up the change automatically.
* `division_names` controls which divisions header levels map to.

## Limitations

1. Citations become bare `<xref>` elements pointing at the citation keys; you must create `<biblio>` entries with matching `xml:id`s yourself.
1. Features with no PreTeXt equivalent (line breaks, horizontal rules, unrecognized divs, non-PreTeXt raw blocks) are preserved as searchable XML comments (`<!-- linebreak -->`, `<!-- div ... -->`, etc.) for manual post-processing.
1. An image appearing inline mid-sentence is emitted where it stands, which is not valid PreTeXt; move it or delete it by hand (a paragraph containing only images is handled automatically).
1. Multi-paragraph footnotes are flattened to a single `<fn>`.

Validating the output against the [PreTeXt schema](https://pretextbook.org/doc/guide/html/schema.html) will point out anything that needs manual attention, e.g.:

```
jing pretext.rng manual.ptx
```

Please report any issues.

## Future work

Perhaps with templates, or with secondary lua files, specific sorts of documents (e.g., worksheets, exercise sets) could be implemented.

Another option: convince the pandoc folks to add PreTeXt as an official output format (and eventually a reader).  This writer serves as the working prototype for that conversation.
