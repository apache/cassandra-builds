#!/bin/bash -x
set -e

if [ "$#" -ne 1 ]; then
   echo "build-debs.sh <branch> [is_release]"
   exit 1
fi

CASSANDRA_BRANCH=$1
# set to avoid using -SNAPSHOT version prefix
CASSANDRA_IS_RELEASE=$2

cd $CASSANDRA_DIR
git fetch
git checkout $CASSANDRA_BRANCH
# javadoc target is broken in docker without this mkdir
mkdir -p ./build/javadoc
if [ -z $CASSANDRA_IS_RELEASE ]; then
ant artifacts
else
ant artifacts -Drelease=true
fi
echo "y" | sudo mk-build-deps --install
dpkg-buildpackage -uc -us
cp ../cassandra[-_]* $DEB_DIST_DIR
