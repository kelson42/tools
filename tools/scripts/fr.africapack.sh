#!/bin/bash

# Add Custom pages
echo "Wikipédia:Neutralité_de_point_de_vue" > fr.mirror &&
echo "Wikipédia:Principes_fondateurs" >> fr.mirror &&
echo "Wikipédia:Travaux_inédits" >> fr.mirror &&
echo "Wikipédia:Vérifiabilité" >> fr.mirror &&
echo "Wikipédia:Termes_à_utiliser_avec_précaution" >> fr.mirror &&
echo "Wikipédia:Ce_que_Wikipédia_n'est_pas" >> fr.mirror &&
echo "Wikipédia:Style_encyclopédique" >> fr.mirror &&

# Add a few other pages
echo "MediaWiki:Common.js" >> fr.mirror &&
echo "MediaWiki:Common.css" >> fr.mirror &&
echo "MediaWiki:Vector.js" >> fr.mirror &&
echo "MediaWiki:Vector.css" >> fr.mirror &&

# Add custom templates
Template:Infobox_Subdivision_administrative >> fr.mirror &&
Template:Infobox_Commune >> fr.mirror &&
Template:Infobox_Commune_d'Algérie >> fr.mirror &&
Template:Modèle:Infobox_Daïra_d'Algérie >> fr.mirror &&
Template:Infobox_Wilaya_d'Algérie >> fr.mirror &&
Template:Infobox_Province_d'Angola >> fr.mirror &&
Template:Infobox_Ville_du_Botswana >> fr.mirror &&
Template:Infobox_District_du_Botswana >> fr.mirror &&
Template:Infobox_Commune_du_Cameroun >> fr.mirror &&
Template:Infobox_Région_du_Cameroun >> fr.mirror &&
Tempalte:Infobox_Commune_de_la_République_du_Congo >> fr.mirror &&
Template:Infobox_Commune_de_la_République_démocratique_du_Congo >> fr.mirror &&
Template:Infobox_Collectivité_de_la_République_démocratique_du_Congo >> fr.mirror &&
Template:Infobox_Territoire_de_la_République_démocratique_du_Congo >> fr.mirror &&
Template:Infobox_Ville_de_la_République_démocratique_du_Congo >> fr.mirror &&
Template:Infobox_District_de_la_République_démocratique_du_Congo >> fr.mirror &&
Template:Infobox_Province_de_la_République_démocratique_du_Congo >> fr.mirror &&
Template:Infobox_Commune_de_Côte_d'Ivoire >> fr.mirror &&
Template:Infobox_Ville_d'Éthiopie >> fr.mirror &&
Template:Infobox_Ville_du_Gabon >> fr.mirror &&
Template:Infobox_Département_du_Gabon >> fr.mirror &&
Template:Infobox_Province_du_Gabon >> fr.mirror &&
Template:Infobox_District_du_Kenya >> fr.mirror &&
Template:Infobox_Subdivision_du_Kenya >> fr.mirror &&
Template:Infobox_Commune_du_Mali >> fr.mirror &&
Template:Infobox_Ville_du_Maroc >> fr.mirror &&
Template:Infobox_Province_du_Maroc >> fr.mirror &&
Template:Infobox_Commune_de_Mauritanie >> fr.mirror &&
Template:Infobox_Commune_du_Nigeria >> fr.mirror &&
Template:Infobox_État_du_Nigeria >> fr.mirror &&
Template:Infobox_Commune_d'Ouganda >> fr.mirror &&
Template:Infobox_Ville_du_Rwanda >> fr.mirror &&
Template:Infobox_Ville_du_Sénégal >> fr.mirror &&
Template:Infobox_Département_du_Sénégal >> fr.mirror &&
Template:Infobox_Région_du_Sénégal >> fr.mirror &&
Template:Infobox_Commune_de_Somalie >> fr.mirror &&
Template:Infobox_Ville_du_Togo >> fr.mirror &&
Template:Infobox_Ville_de_Tunisie >> fr.mirror &&
Template:Infobox_Gouvernorat_tunisien >> fr.mirror &&
Template:Infobox_Province_du_Zimbabwe >> fr.mirror &&

# Project pages
./listCategoryEntries.pl --host=fr.wikipedia.org --path=w --category=Projet_Wikipack_Africa_Contenu --explorationDepth=1 --namespace=102 >> fr.mirror &&

# Featured articles & featured lists pages
./listCategoryEntries.pl --host=fr.wikipedia.org --path=w --category="Article_de_qualité" --explorationDepth=1 --namespace=0 > fr.featured &&

# Get fr.featured dependences
cat fr.featured | ./listDependences.pl --host=fr.wikipedia.org --path=w --readFromStdin --type=template | sort -u > fr.featured.deps &&

# Get fr.mirror dependencies
cat fr.mirror fr.featured.deps | ./listDependences.pl --host=fr.wikipedia.org --path=w --readFromStdin --type=all | sort -u > fr.tmp &&
cat fr.tmp fr.featured.deps | sed 's/^Fichier:/File:/g' | sort -u >> fr.mirror

# Mediawiki help
echo "Help:Contents/fr" > fr.mw.help
echo "Help:Navigation/fr" >> fr.mw.help
echo "Help:Searching/fr" >> fr.mw.help
echo "Help:Tracking_changes/fr" >> fr.mw.help
echo "Help:Watchlist/fr" >> fr.mw.help
echo "Help:Editing_pages/fr" >> fr.mw.help
echo "Help:Starting_a_new_page/fr" >> fr.mw.help
echo "Help:Formatting/fr" >> fr.mw.help
echo "Help:Links/fr" >> fr.mw.help
echo "Help:User_page/fr" >> fr.mw.help
echo "Help:Talk_pages/fr" >> fr.mw.help
echo "Help:Signatures/fr" >> fr.mw.help
echo "Help:VisualEditor/User_guide/fr" >> fr.mw.help
echo "Help:Images/fr" >> fr.mw.help
echo "Help:Lists/fr" >> fr.mw.help
echo "Help:Tables/fr" >> fr.mw.help
echo "Help:Categories/fr" >> fr.mw.help
echo "Help:Subpages/fr" >> fr.mw.help
echo "Help:Managing_files/fr" >> fr.mw.help
echo "Help:Moving_a_page/fr" >> fr.mw.help
echo "Help:Redirects/fr" >> fr.mw.help
echo "Help:Protected_pages/fr" >> fr.mw.help
echo "Help:Templates/fr" >> fr.mw.help
echo "Help:Magic_words/fr" >> fr.mw.help
echo "Help:Namespaces/fr" >> fr.mw.help
echo "Help:Cite/fr" >> fr.mw.help
echo "Help:Special_pages/fr" >> fr.mw.help
echo "Help:External_searches/fr" >> fr.mw.help
echo "Help:Bots/fr" >> fr.mw.help
echo "Help:Notifications/fr" >> fr.mw.help
echo "Help:Flow/fr" >> fr.mw.help
echo "Help:Preferences/fr" >> fr.mw.help
echo "Help:Skins/fr" >> fr.mw.help
echo "Help:Sysops_and_permissions/fr" >> fr.mw.help
echo "Help:Protecting_and_unprotecting_pages/fr" >> fr.mw.help
echo "Help:Sysop_deleting_and_undeleting/fr" >> fr.mw.help
echo "Help:Patrolled_edits/fr" >> fr.mw.help
echo "Help:Blocking_users/fr" >> fr.mw.help
echo "Help:Range_blocks/fr" >> fr.mw.help
echo "Help:Assigning_permissions/fr" >> fr.mw.help
echo "Help:Diff/fr" >> fr.mw.help
echo "Help:Merge_history/fr" >> fr.mw.help
echo "Help:New_images/fr" >> fr.mw.help
echo "Help:New_pages/fr" >> fr.mw.help
echo "Help:Random_page/fr" >> fr.mw.help
echo "Help:Recent_changes/fr" >> fr.mw.help
echo "Help:Undelete/fr" >> fr.mw.help
echo "Help:Copying_a_page/fr" >> fr.mw.help
echo "Template:MW_version/fr" >> fr.mw.help

cat fr.mw.help | ./listDependences.pl --host=mediawiki.org --path=w --readFromStdin --type=all | sort -u > fr.mw.tmp &&
cat fr.mw.tmp | sed 's/^Fichier:/File:/g' >> fr.mw.help
