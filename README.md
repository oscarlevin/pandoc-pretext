# Pandoc to PreTeXt

A first stab at creating a Lua writer to convert anything [Pandoc]{https://pandoc.org/} reads to PreTeXt.  The writer will be based loosely on [pandoc-jats]{https://github.com/mfenner/pandoc-jats}.

The goal is primarily to streamline the conversion of latex (or even MS Word) files into PreTeXt.  If successful though, this might make for a reasonable workflow for PreTeXt newcomers: write in Pandoc's markdown, or whatever they are used to, then convert to PreTeXt to include in a book.

The conversion works fairly well for simple documents (expository text with math, but without example/theorem/project blocks).  Main division (sections), tables, images (but not tikz), and code all work.  See limitations section below.

## Installation
If you don't have it already, download and install [Pandoc]{https://pandoc.org/}.  Then just download the file `pretext.lua` and put it in a convenient location. 

Pandoc includes a lua interpreter, so lua need not be installed separately. You might need to update to a more recent version of Pandoc if you get issues, although pains have been taken to get this to work with earlier versions where possible.

## Usage
To convert the markdown file `manual.md` into the PreTeXt file `manual.ptx`, use the following command:

```
pandoc examples/manual.md -t pretext.lua -o manual.ptx
```

Of course you can (might need to) specify a path to the `pretext.lua` file, depending on where it is located.

## Limitations

Currently, there are the following known issues with the output:

1. Sections work as expected, but the `<introduction>` is missing around blocks where it should be present.
1. No support for theorems/definitions/examples/etc.  This might be impossible, although there is a amsthm "filter" available.  I don't think that reads anything by custom YAML that an author would specifically put in a markdown file though.
1. Text that Pandoc reads as "strong" is converted to `<term>`s, which gives the same look but could be semantically incorrect.  For now, we assume that source document has bold text only for terms, in which case this is teh correct conversion.  Otherwise, the author will need to search for these and fix on a case-by-case basis.
1. A number of things you can do in markdown (line breaks, horizontal rules, divs, etc) have no comparable feature in PreTeXt.  These are converted to comments for manual post-processing.
1. Images work if they call an external file.  tikz might be possible by passing raw text, but this is not implemented currently.
1. Citations have not been implented (todo)

Please report any issues.

## Future work

Some of the limitations above could be addressed if there was a need.

Currently, the output is raw PreTeXt, intended for copying into a larger PreTeXt document.  Perhaps with templates, or with secondary lua files, specific sorts of documents (e.g., worksheets, exercise sets) could be implimented.

Need to test this now, but how good is pandoc and converting PreTeXt generated LaTeX?  Perhaps a simplified xsl sheet could produce nicer LaTeX for pandoc, which could then be converted to other formats (like for slides).  

Another option: convince the pandoc folks to add PreTeXt as a reader.  This is not strictly necessary, but it would allow new users of PreTeXt to see the results of their work without as many compilation steps (Atom, for instance, has a pandoc extension that can convert easily).
