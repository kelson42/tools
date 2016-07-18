#!/bin/bash

# Get features articles & list
./listCategoryEntries.pl --host=en.wikipedia.org --path=w --category=Featured_articles --category=Featured_lists --explorationDepth=1  --namespace=0 > en.featured &&

# Get text dependencies
cat en.featured | ./listDependences.pl --host=en.wikipedia.org --path=w --readFromStdin --type=template | sort -u > en.featured+deps &&

# Exclude articles (mirror only the dependencies)
./compareLists.pl --file1=en.featured+deps --file2=en.featured --mode=only1 > en.featured.template.deps &&

# Get all dependencies (image included)
cat en.featured.template.deps | ./listDependences.pl --host=en.wikipedia.org --path=w --readFromStdin --type=all | sort -u > en.featured.all.deps &&

# Add a few other articles
echo "MediaWiki:Common.js" >> en.featured.all.deps &&
echo "MediaWiki:Common.css" >> en.featured.all.deps &&
echo "MediaWiki:Vector.js" >> en.featured.all.deps &&
echo "MediaWiki:Vector.css" >> en.featured.all.deps

# Remove main