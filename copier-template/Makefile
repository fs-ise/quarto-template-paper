QUARTO ?= quarto
SOURCE ?= paper.qmd

.PHONY: working preprint

working:
	@$(QUARTO) render $(SOURCE) --to pdf \
		--profile working \
		--metadata-file metadata/working_paper.yaml

preprint:
	@$(QUARTO) render $(SOURCE) --to pdf \
		--profile preprint \
		--metadata-file metadata/preprint.yaml
