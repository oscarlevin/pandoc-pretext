# Pandoc to PreTeXt

A first stab at creating a Lua writer to convert anything [Pandoc]{https://pandoc.org/} reads to PreTeXt.  The writer will be based loosely on [pandoc-jats]{https://github.com/mfenner/pandoc-jats}.

The goal is primarily to streamline the conversion of latex (or even MS Word) files into PreTeXt.  If successful though, this might make for a reasonable workflow for PreTeXt newcomers: write in Pandoc's markdown, or whatever they are used to, then convert to PreTeXt to include in a book.

I expect a fair amount of post-processing necessary, but we will see.

## Installation
If you don't have it already, download and install [Pandoc]{https://pandoc.org/}.  Then just download the file `pretext.lua` and put it in a convenient location. 

Pandoc includes a lua interpreter, so lua need not be installed separately. You might need at least Pandoc version 1.13, released August 2014 (this release adds `--template` support for custom writers, which might be added soon).

## Usage
To convert the markdown file `manual.md` into the PreTeXt file `manual.ptx`, use the following command:

```
pandoc examples/manual.md -t pretext.lua -o manual.ptx
```

Of course you can (might need to) specify a path to the `pretext.lua` file, depending on where it is located.

## Issues

Currently, there are the following known issues with the output:

1. Sections work as expected, but the `<introduction>` is missing around blocks where it should be present.
2. No support for theorems/definitions/etc.  This might be impossible, although there is a amsthm "filter" available.  I don't think that reads anything by custom YAML that an author would specifically put in a markdown file though.
3. Not sure what to do with citations.
4. Others?

Please report any issues.

## Future work

Need to test this now, but how good is pandoc and converting PreTeXt generated LaTeX?  Perhaps a simplified xsl sheet could produce nicer LaTeX for pandoc, which could then be converted to other formats (like for slides).  

Another option: convince the pandoc folks to add PreTeXt as a reader.  This is not strictly necessary, but it would allow new users of PreTeXt to see the results of their work without as many compilation steps (Atom, for instance, has a pandoc extension that can convert easily).
