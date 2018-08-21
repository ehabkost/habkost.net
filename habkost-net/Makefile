all: images

images: qemuopts-example.mmd.png

%.mmd.png: _includes/%.mmd
	npx mmdc -i $< -o $@

_includes/%.mmd.svg: _includes/%.mmd
	npx mmdc -i $< -o $@

.PHONY: all images
