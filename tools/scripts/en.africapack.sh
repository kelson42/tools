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
#./listCategoryEntries.pl --host=en.wikipedia.org --path=w --category=WikiProject_Wikipack_Africa_Content --explorationDepth=1 --namespace=4 >> en.mirror &&

# Featured articles & featured lists pages
#./listCategoryEntries.pl --host=en.wikipedia.org --path=w --category=Featured_articles --category=Featured_lists --explorationDepth=1 --namespace=0 > en.featured &&

# Get en.featured dependences
#cat en.featured | ./listDependences.pl --host=en.wikipedia.org --path=w --readFromStdin --type=template | sort -u > en.featured.deps &&

# Get en.mirror dependencies
#cat en.mirror en.featured.deps | ./listDependences.pl --host=en.wikipedia.org --path=w --readFromStdin --type=all | sort -u > en.tmp &&
#cat en.tmp en.featured.deps | sort -u >> en.mirror

# Mediawiki help
rm mw.help
echo "Help:Contents" >> mw.help
echo "Help:Navigation" >> mw.help
echo "Help:Searching" >> mw.help
echo "Help:Tracking_changes" >> mw.help
echo "Help:Watchlist" >> mw.help
echo "Help:Editing_pages" >> mw.help
echo "Help:Starting_a_new_page" >> mw.help
echo "Help:Formatting" >> mw.help
echo "Help:Links" >> mw.help
echo "Help:User_page" >> mw.help
echo "Help:Talk_pages" >> mw.help
echo "Help:Signatures" >> mw.help
echo "Help:VisualEditor/User_guide" >> mw.help
echo "Help:Images" >> mw.help
echo "Help:Lists" >> mw.help
echo "Help:Tables" >> mw.help
echo "Help:Categories" >> mw.help
echo "Help:Subpages" >> mw.help
echo "Help:Managing_files" >> mw.help
echo "Help:Moving_a_page" >> mw.help
echo "Help:Redirects" >> mw.help
echo "Help:Protected_pages" >> mw.help
echo "Help:Templates" >> mw.help
echo "Help:Magic_words" >> mw.help
echo "Help:Namespaces" >> mw.help
echo "Help:Cite" >> mw.help
echo "Help:Special_pages" >> mw.help
echo "Help:External_searches" >> mw.help
echo "Help:Bots" >> mw.help
echo "Help:Notifications" >> mw.help
echo "Help:Flow" >> mw.help
echo "Help:Preferences" >> mw.help
echo "Help:Skins" >> mw.help
echo "Help:Sysops_and_permissions" >> mw.help
echo "Help:Protecting_and_unprotecting_pages" >> mw.help
echo "Help:Sysop_deleting_and_undeleting" >> mw.help
echo "Help:Patrolled_edits" >> mw.help
echo "Help:Blocking_users" >> mw.help
echo "Help:Range_blocks" >> mw.help
echo "Help:Assigning_permissions" >> mw.help

cat mw.help | ./listDependences.pl --host=mediawiki.org --path=w --readFromStdin --type=all | sort -u > mw.tmp &&
cat mw.tmp >> mw.help

