#!/bin/bash -e
bundle exec jekyll build
rsync -va --delete-after _site/ ehabkost1@george-read.dreamhost.com:habkost.net/
