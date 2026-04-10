# Paper template

## Build

```sh
mkdir my-paper
cd my-paper
quarto use template fs-ise/paper-template

make working
make preprint
```

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
