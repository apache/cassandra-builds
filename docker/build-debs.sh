#!/bin/bash -x
set -eu

if [ "$#" -ne 1 ]; then
   echo "build-debs.sh branch"
   exit 1
fi

CASSANDRA_BRANCH=$1

cd $CASSANDRA_DIR
git fetch
git checkout origin/$CASSANDRA_BRANCH
# javadoc target is broken in docker without this mkdir
mkdir -p ./build/javadoc
ant artifacts -Drelease=true
echo "y" | sudo mk-build-deps --install
dpkg-buildpackage -uc -us
cp ../cassandra[-_]* $DEB_DIST_DIR
