#!/bin/bash -e
make
JEKYLL_ENV=production bundle exec jekyll build
rsync -zva --delete-after _site/ ehabkost1@george-read.dreamhost.com:habkost.net/
