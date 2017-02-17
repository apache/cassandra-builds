#!/bin/bash -x
set -eu

if [ "$#" -ne 2 ]; then
   echo "build-rpms.sh branch version"
   exit 1
fi

CASSANDRA_BRANCH=$1
CASSANDRA_VERSION=$2

cd $CASSANDRA_DIR
git fetch
git checkout origin/$CASSANDRA_BRANCH
# javadoc target is broken in docker without this mkdir
mkdir -p ./build/javadoc
ant artifacts -Drelease=true
cp ./build/apache-cassandra-*-src.tar.gz ${RPM_BUILD_DIR}/SOURCES/
rpmbuild --define="version ${CASSANDRA_VERSION}" -ba ./redhat/cassandra.spec
cp $RPM_BUILD_DIR/SRPMS/*.rpm $RPM_BUILD_DIR/RPMS/noarch/*.rpm $RPM_DIST_DIR
