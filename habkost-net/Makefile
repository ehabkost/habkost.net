all: images

images: qemuopts-example.mmd.png

%.mmd.png: _includes/%.mmd
	npx mmdc -p puppeteer-config.json -i $< -o $@

_includes/%.mmd.svg: _includes/%.mmd
	npx mmdc -p puppeteer-config.json -i $< -o $@

.PHONY: all images
