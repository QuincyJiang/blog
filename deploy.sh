#!/bin/bash
git add .
git commit -m "update blog"
git push
echo "-------blog file updated!--------"
hexo g
hexo d
echo "-------blog has been deployed--------"