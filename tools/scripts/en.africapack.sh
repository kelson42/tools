#!/bin/bash

# Meta pages
echo "Template:WikiFundi_credit_attribution" > en.mirror &&
echo "Wikipedia:NPOV" >> en.mirror &&
echo "Wikipedia:Core_content_policies" >> en.mirror &&
echo "Wikipedia:No_original_research" >> en.mirror &&
echo "Wikipedia:Verifiability" >> en.mirror &&
echo "Wikipedia:Words_to_watch" >> en.mirror &&
echo "Wikipedia:Five_pillars" >> en.mirror &&
echo "Wikipedia:What_Wikipedia_is_not" >> en.mirror &&
echo "Wikipedia:Manual_of_Style" >> en.mirror &&

# Encyclopedic pages
echo "Sinenjongo_High_School" >> en.mirror &&
echo "Saint_Fatima_School" >> en.mirror &&
echo "Boa_Amponsem_Senior_High_School" >> en.mirror &&
echo "Gayaza_High_School" >> en.mirror &&
echo "Namwianga_Mission" >> en.mirror &&
echo "American_Cooperative_School_of_Tunis" >> en.mirror &&
echo "Kapsabet_High_School" >> en.mirror &&
echo "Showcase" >> en.mirror &&
echo "Eusèbe_Jaojoby" >> en.mirror &&
echo "Cameroon" >> en.mirror &&
echo "Pluto" >> en.mirror &&
echo "List_World_Heritage" >> en.mirror &&
echo "Ambohimanga" >> en.mirror &&

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
echo "Help:Contents" > en.mw.help
echo "Help:Navigation" >> en.mw.help
echo "Help:Searching" >> en.mw.help
echo "Help:Tracking_changes" >> en.mw.help
echo "Help:Watchlist" >> en.mw.help
echo "Help:Editing_pages" >> en.mw.help
echo "Help:Starting_a_new_page" >> en.mw.help
echo "Help:Formatting" >> en.mw.help
echo "Help:Links" >> en.mw.help
echo "Help:User_page" >> en.mw.help
echo "Help:Talk_pages" >> en.mw.help
echo "Help:Signatures" >> en.mw.help
echo "Help:VisualEditor/User_guide" >> en.mw.help
echo "Help:Images" >> en.mw.help
echo "Help:Lists" >> en.mw.help
echo "Help:Tables" >> en.mw.help
echo "Help:Categories" >> en.mw.help
echo "Help:Subpages" >> en.mw.help
echo "Help:Managing_files" >> en.mw.help
echo "Help:Moving_a_page" >> en.mw.help
echo "Help:Redirects" >> en.mw.help
echo "Help:Protected_pages" >> en.mw.help
echo "Help:Templates" >> en.mw.help
echo "Help:Magic_words" >> en.mw.help
echo "Help:Namespaces" >> en.mw.help
echo "Help:Cite" >> en.mw.help
echo "Help:Special_pages" >> en.mw.help
echo "Help:External_searches" >> en.mw.help
echo "Help:Bots" >> en.mw.help
echo "Help:Notifications" >> en.mw.help
echo "Help:Flow" >> en.mw.help
echo "Help:Preferences" >> en.mw.help
echo "Help:Skins" >> en.mw.help
echo "Help:Sysops_and_permissions" >> en.mw.help
echo "Help:Protecting_and_unprotecting_pages" >> en.mw.help
echo "Help:Sysop_deleting_and_undeleting" >> en.mw.help
echo "Help:Patrolled_edits" >> en.mw.help
echo "Help:Blocking_users" >> en.mw.help
echo "Help:Range_blocks" >> en.mw.help
echo "Help:Assigning_permissions" >> en.mw.help
echo "Help:Diff" >> en.mw.help
echo "Help:Merge_history" >> en.mw.help
echo "Help:New_images" >> en.mw.help
echo "Help:New_pages" >> en.mw.help
echo "Help:Random_page" >> en.mw.help
echo "Help:Recent_changes" >> en.mw.help
echo "Help:Undelete" >> en.mw.help
echo "Help:Copying_a_page" >> en.mw.help
echo "Template:MW_version" >> en.mw.help

cat en.mw.help | ./listDependences.pl --host=mediawiki.org --path=w --readFromStdin --type=all | sort -u > en.mw.tmp &&
cat en.mw.tmp >> en.mw.help

