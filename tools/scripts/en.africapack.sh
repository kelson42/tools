#!/bin/bash

# Custom pages
echo "Template:WikiFundi_credit_attribution" > en.mirror &&
echo "Wikipedia:NPOV" >> en.mirror &&
echo "Wikipedia:Core_content_policies" >> en.mirror &&
echo "Wikipedia:No_original_research" >> en.mirror &&
echo "Wikipedia:Verifiability" >> en.mirror &&
echo "Wikipedia:Words_to_watch" >> en.mirror &&
echo "Wikipedia:Five_pillars" >> en.mirror &&
echo "Wikipedia:What_Wikipedia_is_not" >> en.mirror &&
echo "Wikipedia:Manual_of_Style_(check_last)" >> en.mirror &&

# School pages
echo "Sinenjongo_High_School" >> en.mirror &&
echo "Saint_Fatima_School" >> en.mirror &&
echo "Boa_Amponsem_Senior_High_School" >> en.mirror &&
echo "Gayaza_High_School" >> en.mirror &&
echo "Namwianga_Mission" >> en.mirror &&
echo "American_Cooperative_School_of_Tunis" >> en.mirror &&
echo "Kapsabet_High_School" >> en.mirror &&

# Add a few other pages
echo "MediaWiki:Common.js" >> en.mirror &&
echo "MediaWiki:Common.css" >> en.mirror &&
echo "MediaWiki:Vector.js" >> en.mirror &&
echo "MediaWiki:Vector.css" >> en.mirror &&

# Project pages
./listCategoryEntries.pl --host=en.wikipedia.org --path=w --category=WikiProject_Wikipack_Africa_Content --explorationDepth=1 --namespace=4 >> en.mirror &&

# Featured articles & featured lists pages
./listCategoryEntries.pl --host=en.wikipedia.org --path=w --category=Featured_articles --category=Featured_lists --explorationDepth=1 --namespace=0 > en.featured &&

# Get en.featured dependences
cat en.featured | ./listDependences.pl --host=en.wikipedia.org --path=w --readFromStdin --type=template | sort -u > en.featured.deps &&

# Get en.mirror dependencies
cat en.mirror en.featured.deps | ./listDependences.pl --host=en.wikipedia.org --path=w --readFromStdin --type=all | sort -u > en.tmp &&
cat en.tmp en.featured.deps | sort -u >> en.mirror

# Mediawiki help
./listCategoryEntries.pl --host=mediawiki.org --path=w --category=Help --explorationDepth=1 --namespace=12 > mw.help &&
cat mw.help | ./listDependences.pl --host=mediawiki.org --path=w --readFromStdin --type=all | sort -u > mw.tmp &&
cat mw.tmp >> mw.help