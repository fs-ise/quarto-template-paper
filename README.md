# FS-ISE Paper Template

Create a new paper project with Copier:

```sh
copier copy --trust gh:fs-ise/quarto-template-paper my-paper
cd my-paper
quarto preview paper.qmd
```

Copier asks for the project name, paper title, and author(s). It records these
answers in `.copier-answers.yml`, which enables future template updates.

## Render

Render HTML, PDF, and DOCX using the standard Quarto manuscript project:

```sh
quarto render
```

Render the working-paper and preprint PDF profiles with:

```sh
make working
make preprint
```

Preprint output uses unnumbered sections by default (`number-sections: false`
in `_quarto-preprint.yml`). To enable numbering, set `number-sections: true`
under `format.pdf` in that profile or the document front matter.

## Update a project

In a Copier-generated project, update reusable template files with:

```sh
copier update
```

The project keeps Copier's answers and protects `paper.qmd` and
`references.bib` from being replaced by template updates. Review update diffs
before accepting changes to other files you have customized.

## Project structure

- `paper.qmd` — manuscript and its title/author metadata
- `_quarto.yml` — Quarto manuscript project and output formats
- `_quarto-working.yml`, `_quarto-preprint.yml` — profile settings
- `references.bib`, `csl/` — bibliography and citation style
- `template/`, `tex/`, `filters/` — LaTeX templates, headers, and filters
- `metadata/` — profile-specific render metadata
- `Makefile` — `working` and `preprint` render commands

## Section numbering in preprint

Preprint output uses unnumbered sections by default (`number-sections: false` in `_quarto-preprint.yml`).

To activate section numbering for preprints, set:

```yaml
format:
  pdf:
    number-sections: true
```

You can place this in `_quarto-preprint.yml` or in the preprint document front matter.

See https://github.com/quarto-monash/workingpaper?tab=readme-ov-file
