#!/bin/bash

BINTRAY_USER="$USER"
BINTRAY_KEY="XXXXXXXX"

#Example:
#./upload_bintray.sh ~/workspace/cassandra-dist-svn/debian

ROOTDIR=`cd -P -- "$(dirname -- "$1")" && printf '%s\n' "$(pwd -P)/$(basename -- "$1")"`
ROOTLEN=$(( ${#ROOTDIR} + 1))

for i in $(find ${ROOTDIR} -type f -printf "%T@ %p\n" | sort -n -r | cut -d' ' -f 2); do
	IFILE=`echo $(basename -- "$i") | cut -c 1`
    if [[ $IFILE != "." ]]; 
    then
    	FDIR=`echo $i | cut -c ${ROOTLEN}-${#i}`
    	echo "Uploading $FDIR"
    	curl -X PUT -T $i -u${BINTRAY_USER}:${BINTRAY_KEY} "https://api.bintray.com/content/apache/cassandra/debian/prod${FDIR}?override=1"
    	sleep 1
    fi
done

