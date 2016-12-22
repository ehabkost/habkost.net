all: images

images: qemuopts-example.mmd.png

%.mmd.png: _includes/%.mmd
	mermaid -p $<

_includes/%.mmd.svg: _includes/%.mmd
	mermaid -s -o _includes $<

.PHONY: all images
