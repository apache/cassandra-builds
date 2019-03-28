#!/bin/bash -x
set -e

if [ "$#" -ne 1 ]; then
   echo "$0 <branch>"
   exit 1
fi

CASSANDRA_BRANCH=$1

CASSANDRA_MAJOR_VERSION=$(cat $CASSANDRA_DIR/build.xml | grep "<property name=\"base.version"\" | sed -n 's/.*value="\([^"]*\).*/\1/p' | cut -d "." -f 1)

if (( $CASSANDRA_MAJOR_VERSION >= 4 )); then
   export JAVA_HOME=/usr/lib/jvm/java-11
   export JAVA8_HOME=/usr/lib/jvm/java-1.8.0
else
   export JAVA_HOME=/usr/lib/jvm/java-1.8.0
   export JAVA8_HOME=/usr/lib/jvm/java-1.8.0
fi

cd $CASSANDRA_DIR
git fetch
git checkout $CASSANDRA_BRANCH || exit 1

# Used version for build will always depend on the git referenced used for checkout above
# Branches will always be created as snapshots, while tags are releases
tag=`git describe --tags --exact-match` 2> /dev/null || true
branch=`git symbolic-ref -q --short HEAD` 2> /dev/null || true

is_tag=false
is_branch=false
git_version=''

# Parse version from build.xml so we can verify version against release tags and use the build.xml version
# for any branches. Truncate from snapshot suffix if needed.
buildxml_version=`grep 'property\s*name="base.version"' build.xml |sed -ne 's/.*value="\([^"]*\)".*/\1/p'`
regx_snapshot="([0-9.]+)-SNAPSHOT$"
if [[ $buildxml_version =~ $regx_snapshot ]]; then
   buildxml_version=${BASH_REMATCH[1]}
fi

if [ "$tag" ]; then
   is_tag=true
   # Official release
   regx_tag="cassandra-([0-9.]+)$"
   # Tentative release
   regx_tag_tentative="([0-9.]+)-tentative$"
   if [[ $tag =~ $regx_tag ]] || [[ $tag =~ $regx_tag_tentative ]]; then
      git_version=${BASH_REMATCH[1]}
   else
      echo "Error: could not recognize version from tag $tag">&2
      exit 2
   fi
   if [ $buildxml_version != $git_version ]; then
      echo "Error: build.xml version ($buildxml_version) not matching git tag derived version ($git_version)">&2
      exit 4
   fi
   CASSANDRA_VERSION=$git_version
   CASSANDRA_REVISION='1'
elif [ "$branch" ]; then
   # Dev branch
   is_branch=true
   # This could be either trunk or any dev branch, so we won't be able to get the version
   # from the branch name. In this case, fall back to version specified in build.xml.
   CASSANDRA_VERSION="${buildxml_version}"
   dt=`date +"%Y%m%d"`
   ref=`git rev-parse --short HEAD`
   CASSANDRA_REVISION="${dt}git${ref}"
else
   echo "Error: invalid git reference; must either be branch or tag">&2
   exit 1
fi

# javadoc target is broken in docker without this mkdir
mkdir -p ./build/javadoc
# Artifact will only be used internally for build process and won't be found with snapshot suffix
ant artifacts -Drelease=true
cp ./build/apache-cassandra-*-src.tar.gz ${RPM_BUILD_DIR}/SOURCES/
rpmbuild --define="version ${CASSANDRA_VERSION}" --define="revision ${CASSANDRA_REVISION}" -ba ./redhat/cassandra.spec
cp $RPM_BUILD_DIR/SRPMS/*.rpm $RPM_BUILD_DIR/RPMS/noarch/*.rpm $RPM_DIST_DIR
