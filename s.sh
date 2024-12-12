#!/bin/bash

while IFS= read -r LINE; do

# echo "Line=$LINE"

    NAME=`echo "$LINE" | awk -F 'name="' '{printf $2}' | awk -F '\" ' '{printf $1}'`
    FPATH=`echo "$LINE" | awk -F 'path="' '{printf $2}' | awk -F '\" ' '{printf $1}'`
    REVISION=`echo "${LINE}" | awk -F 'revision="' '{printf $2}' | awk -F '\" ' '{printf $1}'`
#   awk -F ' path=|\" ' '{printf $2}' | awk -F ' ' '{printf $1}'
    BRANCH=`echo $REVISION | sed 's|refs/heads/||'`
    # echo "Name=$NAME"
    # echo "Path=$FPATH"
    # echo "BRANCH=$BRANCH"

if [ -z "${FPATH}" ] ; then
    echo ""
else
    echo "cd $FPATH ; git co -b $BRANCH ; git push https://github.com/SoftingAE-VCPI/$NAME $BRANCH ; cd -"
    echo ""
fi

done < f.xml
