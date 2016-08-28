#!/bin/sh

cat en.mw.help | ./mirrorMediawikiPages.pl --sourceHost=mediawiki.org --sourcePath=w --destinationHost=en.africapack.kiwix.org --destinationPath=w --destinationUsername=admin --destinationPassword=adminadmin --readFromStdin --ignoreEmbeddedInPagesCheck --ignoreImageDependences  --ignoreTemplateDependences

# Clean Mediawiki entries
for ENTRY in `cat en.mw.help | grep "^Help:"`
do
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable="<[/]*translate>" --variable=" " --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable="<languages[ ]*/>" --variable=" " --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable="<!--T:[\d]+-->" --variable=" " --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='{{ll\|([^}|]+)(|[^}]*)}}' --variable='"[[".$1."]]"' --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='{{TNT\|[^}]+}}' --variable=' ' --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='<tvar\|[^>]+>(Special:MyLanguage\/|)([^>]+)</>' --variable='$2' --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='\[\[(C|c)ategory:[^]]+\]\]' --variable=' ' --username=admin --password=adminadmin

    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='\n[ ]+' --variable="\n" --username=admin --password=adminadmin
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='\n+' --variable="\n" --username=admin --password=adminadmin
done

# Re-insert categories in encyclopedic articles
for ENTRY in `cat en.mirror | grep -v ":"`
do
    ./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="$ENTRY" --action=replace --variable='^<!--2BREINSERTED(.*)-->$' --variable='$1' --username=admin --password=adminadmin
done

# Blank pages
./modifyMediawikiEntry.pl --host=en.africapack.kiwix.org --path=w --entry="Template:Coord" --action=empty --username=admin --password=adminadmin
