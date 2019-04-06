# Pandoc to PreTeXt

A first stab at creating a Lua writer to convert anything pandoc reads to PreTeXt.

The goal is primarily to streamline the conversion of latex (or even word) files into PreTeXt.  If successful though, this might make for a reasonable workflow for PreTeXt newbies: write in pandoc's markdown or whatever they are used to, then convert to PreTeXt to include in a book.

I expect a fair amount of post-precessing necessary, but we will see.

## Another eventual goal

Need to test this now, but how good is pandoc and converting PreTeXt generated LaTeX?  Perhaps a simplified xsl sheet could produce nicer LaTeX for pandoc, which could then be converted to other formats (like for slides).  

Another option: convince the pandoc folks to add PreTeXt as a reader.  This is not strictly necessary, but it would allow new users of PreTeXt to see the results of their work without as many compilation steps (Atom, for instance, has a pandoc extension that can convert easily).
