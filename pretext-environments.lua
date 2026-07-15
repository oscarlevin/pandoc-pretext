-- Shared table of LaTeX/amsthm environment (and markdown fenced-div class)
-- names recognized as PreTeXt blocks, and which PreTeXt element each maps
-- to.  Loaded by both pretext.lua (to classify a Div's class when writing)
-- and pretext-latex-reader.lua (to pre-declare \newtheorem for each name,
-- so pandoc's LaTeX reader gives every one of them full theorem treatment
-- -- numbering context, bracketed-name capture, and label attachment --
-- even when the source document itself never declares them).
--
-- Extend this table with whatever \newtheorem shorthands your documents
-- use; both scripts pick up the change automatically.
return {
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
